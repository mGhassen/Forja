package com.forjahq.app

import android.util.Log
import okhttp3.Dns
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.net.Inet4Address
import java.net.InetAddress
import java.net.UnknownHostException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/**
 * System DNS and Cloudflare DoH (`1.1.1.1`) in parallel.
 *
 * Same rules as Dart [PackHttp]: first non-empty answer wins, IPv4 preferred,
 * results cached 60s. After one system-DNS timeout, further probes skip
 * system DNS until a later lookup succeeds.
 * The DoH client connects to `1.1.1.1` by address so a broken system resolver
 * cannot recurse into itself.
 */
object ForjaDohDns : Dns {
    private const val TAG = "ForjaExo"
    private const val SYSTEM_TIMEOUT_MS = 5_000L
    private const val DOH_TIMEOUT_MS = 8_000L
    private const val CACHE_MS = 60_000L

    private val pool = Executors.newCachedThreadPool()
    private val cache = ConcurrentHashMap<String, Cached>()
    private val inflight = ConcurrentHashMap<String, Future<List<InetAddress>>>()

    @Volatile
    private var skipSystem = false

    private val oneOneOneOne: InetAddress =
        InetAddress.getByAddress(byteArrayOf(1, 1, 1, 1))

    private val dohClient: OkHttpClient = OkHttpClient.Builder()
        .dns(object : Dns {
            override fun lookup(hostname: String): List<InetAddress> {
                if (hostname == "1.1.1.1") return listOf(oneOneOneOne)
                throw UnknownHostException(hostname)
            }
        })
        .connectTimeout(DOH_TIMEOUT_MS, TimeUnit.MILLISECONDS)
        .readTimeout(DOH_TIMEOUT_MS, TimeUnit.MILLISECONDS)
        .build()

    override fun lookup(hostname: String): List<InetAddress> {
        val host = hostname.trim().trimEnd('.')
        if (host.isEmpty()) throw UnknownHostException(hostname)
        literal(host)?.let { return listOf(it) }

        val key = host.lowercase()
        readCache(key)?.let { return it }

        val started = pool.submit<List<InetAddress>> { resolve(key, host) }
        val joined = inflight.putIfAbsent(key, started) ?: started
        if (joined !== started) started.cancel(true)
        return try {
            joined.get(DOH_TIMEOUT_MS + 1_000L, TimeUnit.MILLISECONDS)
        } catch (e: TimeoutException) {
            throw UnknownHostException(host).apply { initCause(e) }
        } finally {
            if (joined === started) inflight.remove(key, started)
        }
    }

    private fun resolve(key: String, host: String): List<InetAddress> {
        readCache(key)?.let { return it }
        val addrs = if (systemSkipped()) {
            doh(host).ifEmpty { throw UnknownHostException(host) }
        } else {
            race(host)
        }
        if (addrs.isEmpty()) throw UnknownHostException(host)
        val preferred = preferV4(addrs)
        cache[key] = Cached(preferred, System.currentTimeMillis() + CACHE_MS)
        return preferred
    }

    private fun race(host: String): List<InetAddress> {
        val started = System.currentTimeMillis()
        val sys = pool.submit<List<InetAddress>?> { system(host) }
        val via = pool.submit<List<InetAddress>> { doh(host) }
        val deadline = started + DOH_TIMEOUT_MS
        var notedTimeout = false
        while (System.currentTimeMillis() < deadline) {
            val elapsed = System.currentTimeMillis() - started
            if (!notedTimeout && !sys.isDone && elapsed >= SYSTEM_TIMEOUT_MS) {
                noteSystemTimeout(host, "timeout ${SYSTEM_TIMEOUT_MS}ms")
                notedTimeout = true
            }
            if (sys.isDone) {
                val systemAddrs = runCatching { sys.get() }.getOrNull()
                if (!systemAddrs.isNullOrEmpty()) {
                    via.cancel(true)
                    return systemAddrs
                }
            }
            if (via.isDone) {
                val dohAddrs = runCatching { via.get() }.getOrNull().orEmpty()
                // DoH answered first. Use it so a hung getaddrinfo does not block
                // the open. A later system success still clears the skip flag.
                if (dohAddrs.isNotEmpty()) return dohAddrs
                if (sys.isDone) return emptyList()
            }
            Thread.sleep(20)
        }
        if (!sys.isDone) noteSystemTimeout(host, "deadline")
        return runCatching { via.get(200, TimeUnit.MILLISECONDS) }.getOrNull().orEmpty()
    }

    private fun system(host: String): List<InetAddress>? {
        return try {
            val addrs = InetAddress.getAllByName(host).toList()
            if (addrs.isNotEmpty()) noteSystemOk()
            addrs
        } catch (e: UnknownHostException) {
            Log.i(TAG, "system DNS failed ($host): ${e.message}")
            null
        }
    }

    private fun doh(host: String): List<InetAddress> {
        val a = query(host, "A")
        if (a.isNotEmpty()) {
            Log.i(TAG, "DoH resolved $host → ${a.joinToString { it.hostAddress ?: "" }}")
            return a
        }
        val aaaa = query(host, "AAAA")
        if (aaaa.isNotEmpty()) {
            Log.i(TAG, "DoH resolved $host → ${aaaa.joinToString { it.hostAddress ?: "" }}")
        }
        return aaaa
    }

    private fun query(name: String, type: String): List<InetAddress> {
        val url = "https://1.1.1.1/dns-query?name=${encode(name)}&type=$type"
        val request = Request.Builder()
            .url(url)
            .header("Accept", "application/dns-json")
            .build()
        return try {
            dohClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return emptyList()
                parseAnswers(response.body?.string().orEmpty(), type)
            }
        } catch (e: Exception) {
            Log.i(TAG, "DoH $type failed ($name): $e")
            emptyList()
        }
    }

    private fun systemSkipped(): Boolean = skipSystem

    private fun noteSystemOk() {
        skipSystem = false
    }

    private fun noteSystemTimeout(host: String, error: String) {
        val already = skipSystem
        skipSystem = true
        if (already) return
        Log.i(
            TAG,
            "system DNS timed out ($host): $error — using DoH, " +
                "skipping system DNS for this session",
        )
    }

    private fun readCache(key: String): List<InetAddress>? {
        val hit = cache[key] ?: return null
        if (System.currentTimeMillis() >= hit.untilMs) {
            cache.remove(key, hit)
            return null
        }
        return hit.addrs
    }

    private fun preferV4(addrs: List<InetAddress>): List<InetAddress> {
        val v4 = addrs.filterIsInstance<Inet4Address>()
        return if (v4.isNotEmpty()) v4 else addrs
    }

    private fun literal(host: String): InetAddress? {
        val parts = host.split('.')
        if (parts.size == 4 && parts.all { (it.toIntOrNull() ?: -1) in 0..255 }) {
            return InetAddress.getByAddress(
                host,
                byteArrayOf(
                    parts[0].toInt().toByte(),
                    parts[1].toInt().toByte(),
                    parts[2].toInt().toByte(),
                    parts[3].toInt().toByte(),
                ),
            )
        }
        return null
    }

    private fun encode(name: String): String =
        java.net.URLEncoder.encode(name, Charsets.UTF_8.name())

    private data class Cached(val addrs: List<InetAddress>, val untilMs: Long)

    internal fun parseAnswers(body: String, type: String): List<InetAddress> {
        if (body.isEmpty()) return emptyList()
        val root = try {
            JSONObject(body)
        } catch (_: Exception) {
            return emptyList()
        }
        if (root.optInt("Status", 0) != 0) return emptyList()
        val answers = root.optJSONArray("Answer") ?: return emptyList()
        val want = if (type == "AAAA") 28 else 1
        val out = ArrayList<InetAddress>()
        for (i in 0 until answers.length()) {
            val row = answers.optJSONObject(i) ?: continue
            if (row.optInt("type") != want) continue
            val data = row.optString("data")
            val addr = if (want == 1) literal(data) else ipv6(data)
            if (addr != null) out.add(addr)
        }
        return out
    }

    private fun ipv6(data: String): InetAddress? {
        if (!data.contains(':')) return null
        return try {
            val parsed = InetAddress.getByName(data)
            if (parsed.address.size == 16) parsed else null
        } catch (_: Exception) {
            null
        }
    }
}

/** Shared player client. DNS is [ForjaDohDns]; DoH bootstrap does not use it. */
object ForjaPlaybackHttp {
    val client: OkHttpClient = OkHttpClient.Builder()
        .dns(ForjaDohDns)
        .connectTimeout(8, TimeUnit.SECONDS)
        .readTimeout(8, TimeUnit.SECONDS)
        .build()
}
