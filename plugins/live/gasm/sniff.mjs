import { readFileSync } from 'node:fs';
import { Window } from 'happy-dom';

const input = JSON.parse(readFileSync(0, 'utf8'));
const embedUrl = String(input.embedUrl || '').trim();
const referer = String(input.referer || embedUrl).trim();
const ua =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

if (!embedUrl) {
  process.stdout.write(JSON.stringify({ ok: false, error: 'empty embedUrl' }));
  process.exit(1);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function pickM3u8(item) {
  if (!item) return '';
  const file = String(item.file || '');
  if (/\.m3u8/i.test(file)) return file;
  const sources = item.sources;
  if (!Array.isArray(sources)) return '';
  for (const s of sources) {
    const u = String(s && s.file || '');
    if (/\.m3u8/i.test(u)) return u;
  }
  return '';
}

async function sniff() {
  const pageRes = await fetch(embedUrl, {
    headers: { 'User-Agent': ua, Referer: referer, Accept: 'text/html,*/*' },
  });
  if (!pageRes.ok) throw new Error(`embed HTTP ${pageRes.status}`);
  const html = await pageRes.text();

  const window = new Window({
    url: embedUrl,
    settings: {
      disableJavaScriptFileLoading: false,
      disableJavaScriptEvaluation: false,
      fetch: {
        disableSameOriginPolicy: true,
      },
    },
  });

  window.fetch = fetch.bind(globalThis);
  const doc = window.document;
  doc.open();
  doc.write(html);
  doc.close();

  for (let i = 0; i < 60; i++) {
    await sleep(500);
    try {
      if (typeof window.jwplayer !== 'function') continue;
      const player = window.jwplayer();
      if (!player || typeof player.getPlaylistItem !== 'function') continue;
      const url = pickM3u8(player.getPlaylistItem());
      if (url) return url;
    } catch (_) {}
  }
  throw new Error('jwplayer m3u8 not found');
}

sniff()
  .then((url) => {
    process.stdout.write(JSON.stringify({ ok: true, url }));
  })
  .catch((err) => {
    process.stdout.write(
      JSON.stringify({
        ok: false,
        error: String(err?.message || err),
      }),
    );
    process.exit(1);
  });
