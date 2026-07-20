package com.forja.app

import android.media.MediaCodecList
import android.os.Build

object PlaybackCapabilities {
    fun probe(): Map<String, Any> {
        val codecs = MediaCodecList(MediaCodecList.REGULAR_CODECS)
        var hevc = false
        var av1 = false
        var vp9 = false
        var hdr10 = false
        var dolbyVision = false
        var maxHeight = 1080

        for (info in codecs.codecInfos) {
            if (!info.isEncoder) {
                for (type in info.supportedTypes) {
                    val lower = type.lowercase()
                    when {
                        lower.contains("hevc") || lower.contains("h265") -> hevc = true
                        lower.contains("av01") || lower.contains("av1") -> av1 = true
                        lower.contains("vp9") -> vp9 = true
                        lower.contains("dolby-vision") || lower.contains("dvhe") -> dolbyVision = true
                        lower.contains("hdr10") || lower.contains("hlg") -> hdr10 = true
                    }
                }
            }
        }

        if (hevc || av1) maxHeight = 2160
        val isTv = false // caller may override via platform profile

        return mapOf(
            "max_height" to maxHeight,
            "hevc" to hevc,
            "av1" to av1,
            "vp9" to vp9,
            "hdr10" to hdr10,
            "dolby_vision" to dolbyVision,
            "is_low_power" to (Build.VERSION.SDK_INT < 26),
            "software_decode_allowed" to !isTv,
            "user_max_height" to 0,
        )
    }
}
