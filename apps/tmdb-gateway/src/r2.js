/**
 * Cloudflare R2 for TMDB image blobs — bucket `forja-tmdb`.
 * On Workers: prefer `TMDB_R2` binding. On Node: S3 API credentials.
 */

import {
  S3Client,
  GetObjectCommand,
  HeadObjectCommand,
  PutObjectCommand,
  DeleteObjectCommand,
  DeleteObjectsCommand,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { envGet, getR2Binding } from "./runtime-env.js";

/** @type {S3Client | null} */
let client = null;

export function r2Config() {
  const accessKeyId = envGet("R2_ACCESS_KEY_ID");
  const secretAccessKey = envGet("R2_SECRET_ACCESS_KEY");
  const accountId = envGet("R2_ACCOUNT_ID");
  const bucket = envGet("R2_TMDB_BUCKET");
  const endpoint = (
    envGet("R2_ENDPOINT") ||
    (accountId ? `https://${accountId}.r2.cloudflarestorage.com` : "")
  ).replace(/\/$/, "");
  if (!accessKeyId || !secretAccessKey || !bucket || !endpoint) return null;
  return { accessKeyId, secretAccessKey, bucket, endpoint };
}

export function r2Configured() {
  return Boolean(getR2Binding()) || Boolean(r2Config());
}

function getClient() {
  const cfg = r2Config();
  if (!cfg) return null;
  if (!client) {
    client = new S3Client({
      region: "auto",
      endpoint: cfg.endpoint,
      credentials: {
        accessKeyId: cfg.accessKeyId,
        secretAccessKey: cfg.secretAccessKey,
      },
      forcePathStyle: false,
    });
  }
  return client;
}

/** @internal test helper */
export function resetR2Client() {
  client = null;
}

/**
 * Public CDN base for stable image URLs (required on Workers for 302 without AWS SDK sign).
 * e.g. https://pub-….r2.dev or https://tmdb-img.forjahq.xyz
 */
export function r2PublicBase() {
  return envGet("R2_TMDB_PUBLIC_BASE").replace(/\/$/, "");
}

/**
 * Redirect URL for an object — public base if set, else Node presigned GET.
 * @param {string} key
 * @param {number} [expiresInSeconds]
 * @returns {Promise<string | null>}
 */
export async function r2RedirectUrl(key, expiresInSeconds = 7 * 24 * 60 * 60) {
  const k = String(key || "").replace(/^\/+/, "");
  if (!k) return null;
  const pub = r2PublicBase();
  if (pub) return `${pub}/${k}`;

  // Workers binding without public base cannot cheaply presign — caller must set R2_TMDB_PUBLIC_BASE.
  if (getR2Binding() && !r2Config()) return null;

  const cfg = r2Config();
  const s3 = getClient();
  if (!cfg || !s3) return null;
  const ttl = Math.max(60, Math.min(Math.floor(expiresInSeconds), 7 * 24 * 60 * 60));
  try {
    return await getSignedUrl(
      s3,
      new GetObjectCommand({ Bucket: cfg.bucket, Key: k }),
      { expiresIn: ttl },
    );
  } catch (err) {
    console.warn("[tmdb-r2] sign failed", err?.name || err);
    return null;
  }
}

/**
 * @param {string} key
 * @returns {Promise<boolean>}
 */
export async function r2HeadObject(key) {
  const binding = getR2Binding();
  if (binding) {
    try {
      const obj = await binding.head(key);
      return Boolean(obj);
    } catch {
      return false;
    }
  }

  const cfg = r2Config();
  const s3 = getClient();
  if (!cfg || !s3 || !key) return false;
  try {
    await s3.send(new HeadObjectCommand({ Bucket: cfg.bucket, Key: key }));
    return true;
  } catch (err) {
    const status = err?.$metadata?.httpStatusCode;
    const name = err?.name || "";
    if (status === 404 || name === "NotFound" || name === "NoSuchKey") {
      return false;
    }
    console.warn("[tmdb-r2] head failed", name || err);
    return false;
  }
}

/**
 * @param {string} key object key e.g. t/p/w500/abc.jpg
 * @returns {Promise<{ body: Buffer | Uint8Array, contentType: string } | null>}
 */
export async function r2GetObject(key) {
  const binding = getR2Binding();
  if (binding) {
    try {
      const obj = await binding.get(key);
      if (!obj) return null;
      const body = new Uint8Array(await obj.arrayBuffer());
      return {
        body,
        contentType: String(
          obj.httpMetadata?.contentType || "application/octet-stream",
        ),
      };
    } catch (err) {
      console.warn("[tmdb-r2] binding get failed", err?.message || err);
      return null;
    }
  }

  const cfg = r2Config();
  const s3 = getClient();
  if (!cfg || !s3) return null;
  try {
    const out = await s3.send(
      new GetObjectCommand({ Bucket: cfg.bucket, Key: key }),
    );
    if (!out.Body) return null;
    const body = Buffer.from(await out.Body.transformToByteArray());
    return {
      body,
      contentType: String(out.ContentType || "application/octet-stream"),
    };
  } catch (err) {
    const status = err?.$metadata?.httpStatusCode;
    const name = err?.name || "";
    if (status === 404 || name === "NoSuchKey" || name === "NotFound") {
      return null;
    }
    console.warn("[tmdb-r2] get failed", name || err);
    return null;
  }
}

/**
 * @param {string} key
 * @param {Buffer|Uint8Array} body
 * @param {string} contentType
 */
export async function r2PutObject(key, body, contentType) {
  const binding = getR2Binding();
  if (binding) {
    try {
      await binding.put(key, body, {
        httpMetadata: { contentType: contentType || "application/octet-stream" },
      });
      return true;
    } catch (err) {
      console.warn("[tmdb-r2] binding put failed", err?.message || err);
      return false;
    }
  }

  const cfg = r2Config();
  const s3 = getClient();
  if (!cfg || !s3) return false;
  try {
    await s3.send(
      new PutObjectCommand({
        Bucket: cfg.bucket,
        Key: key,
        Body: body,
        ContentType: contentType || "application/octet-stream",
      }),
    );
    return true;
  } catch (err) {
    console.warn("[tmdb-r2] put failed", err?.name || err);
    return false;
  }
}

/**
 * @param {string} key
 */
export async function r2DeleteObject(key) {
  const binding = getR2Binding();
  if (binding) {
    try {
      await binding.delete(key);
    } catch (err) {
      console.warn("[tmdb-r2] binding delete failed", err?.message || err);
    }
    return;
  }

  const cfg = r2Config();
  const s3 = getClient();
  if (!cfg || !s3 || !key) return;
  try {
    await s3.send(
      new DeleteObjectCommand({ Bucket: cfg.bucket, Key: key }),
    );
  } catch (err) {
    console.warn("[tmdb-r2] delete failed", err?.name || err);
  }
}

/**
 * @param {string[]} keys
 */
export async function r2DeleteObjects(keys) {
  const unique = [...new Set(keys.filter(Boolean))];
  if (!unique.length) return;

  const binding = getR2Binding();
  if (binding) {
    try {
      await binding.delete(unique);
    } catch (err) {
      console.warn("[tmdb-r2] binding delete multi failed", err?.message || err);
      for (const key of unique) {
        await r2DeleteObject(key);
      }
    }
    return;
  }

  const cfg = r2Config();
  const s3 = getClient();
  if (!cfg || !s3) return;
  const chunkSize = 1000;
  for (let i = 0; i < unique.length; i += chunkSize) {
    const chunk = unique.slice(i, i + chunkSize);
    try {
      await s3.send(
        new DeleteObjectsCommand({
          Bucket: cfg.bucket,
          Delete: {
            Objects: chunk.map((Key) => ({ Key })),
            Quiet: true,
          },
        }),
      );
    } catch (err) {
      console.warn("[tmdb-r2] deleteObjects failed", err?.name || err);
      for (const key of chunk) {
        await r2DeleteObject(key);
      }
    }
  }
}
