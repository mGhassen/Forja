function extract(ctx) {
  var url = String((ctx && ctx.url) || '');
  if (!url) return Promise.resolve([]);
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  return ctx
    .fetch(url, {
      headers: {
        'User-Agent': ua,
        Referer: url,
        Accept: 'text/html,application/json',
      },
    })
    .then(function (r) {
      return r.text();
    })
    .then(function (html) {
      if (/just a moment|cf-challenge/i.test(html)) return [];
      var m3u = (html.match(/https?:\/\/[^"'\s]+\.m3u8[^"'\s]*/) || [])[0];
      var mp4 = (html.match(/https?:\/\/[^"'\s]+\.mp4[^"'\s]*/) || [])[0];
      var u = m3u || mp4;
      if (!u) return [];
      return [
        {
          url: u,
          name: 'hanime',
          headers: { 'User-Agent': ua, Referer: url },
        },
      ];
    })
    .catch(function () {
      return [];
    });
}
