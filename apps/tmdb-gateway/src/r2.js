/**
 * Cloudflare R2 (S3 API) for TMDB image blobs — bucket `forja-tmdb`.
 */

import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
  DeleteObjectCommand,
  DeleteObjectsCommand,
} from "@aws-sdk/client-s3";

/** @type {S3Client | null} */
let client = null;

export function r2Config() {
  const accessKeyId = (process.env.R2_ACCESS_KEY_ID || "").trim();
  const secretAccessKey = (process.env.R2_SECRET_ACCESS_KEY || "").trim();
  const accountId = (process.env.R2_ACCOUNT_ID || "").trim();
  const bucket = (process.env.R2_TMDB_BUCKET || "").trim();
  const endpoint = (
    process.env.R2_ENDPOINT ||
    (accountId ? `https://${accountId}.r2.cloudflarestorage.com` : "")
  )
    .trim()
    .replace(/\/$/, "");
  if (!accessKeyId || !secretAccessKey || !bucket || !endpoint) return null;
  return { accessKeyId, secretAccessKey, bucket, endpoint };
}

export function r2Configured() {
  return Boolean(r2Config());
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
 * @param {string} key object key e.g. t/p/w500/abc.jpg
 * @returns {Promise<{ body: Buffer, contentType: string } | null>}
 */
export async function r2GetObject(key) {
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
  const cfg = r2Config();
  const s3 = getClient();
  if (!cfg || !s3 || !keys.length) return;
  const unique = [...new Set(keys.filter(Boolean))];
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
