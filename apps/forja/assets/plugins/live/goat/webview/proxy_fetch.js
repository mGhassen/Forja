/**
 * CDN fetch bridge for LiveEmbedWebViewProxy on the GOAT headless WebView.
 * Same contract as the embed iframe spy (__forjaProxyFetch → liveProxyFetchResult).
 */
(function () {
  if (window.__forjaProxyFetchInstalled) return;
  window.__forjaProxyFetchInstalled = true;

  function reply(d, status, body, ct) {
    try {
      if (
        window.flutter_inappwebview &&
        typeof window.flutter_inappwebview.callHandler === 'function'
      ) {
        window.flutter_inappwebview.callHandler(
          'liveProxyFetchResult',
          d.id,
          status,
          body,
          ct,
        );
        return;
      }
    } catch (_) {}
    try {
      window.parent.postMessage(
        {
          __forjaProxyFetchResult: true,
          id: d.id,
          status: status,
          body: body,
          ct: ct,
        },
        '*',
      );
    } catch (_) {}
  }

  function readBlob(r, blob) {
    return new Promise(function (resolve) {
      var reader = new FileReader();
      reader.onloadend = function () {
        var dataUrl = String(reader.result || '');
        var b64 = '';
        var idx = dataUrl.indexOf(',');
        if (idx >= 0) b64 = dataUrl.substring(idx + 1);
        resolve({
          status: r.status,
          body: b64,
          ct: (r.headers && r.headers.get('content-type')) || blob.type || '',
        });
      };
      reader.onerror = function () {
        resolve({ status: 0, body: '', ct: '' });
      };
      reader.readAsDataURL(blob);
    });
  }

  function tryFetch(url, creds) {
    return fetch(url, {
      credentials: creds,
      cache: 'no-store',
      mode: 'cors',
    }).then(function (r) {
      return r.blob().then(function (blob) {
        return readBlob(r, blob);
      });
    });
  }

  window.addEventListener('message', function (e) {
    try {
      var d = e && e.data;
      if (!d || !d.__forjaProxyFetch || !d.id || !d.url) return;
      tryFetch(d.url, 'omit')
        .then(function (res) {
          if (res && res.status > 0 && res.body) {
            reply(d, res.status, res.body, res.ct);
            return;
          }
          return tryFetch(d.url, 'include').then(function (res2) {
            reply(
              d,
              (res2 && res2.status) || 0,
              (res2 && res2.body) || '',
              (res2 && res2.ct) || '',
            );
          });
        })
        .catch(function () {
          tryFetch(d.url, 'include')
            .then(function (res2) {
              reply(
                d,
                (res2 && res2.status) || 0,
                (res2 && res2.body) || '',
                (res2 && res2.ct) || '',
              );
            })
            .catch(function () {
              reply(d, 0, '', '');
            });
        });
    } catch (_) {}
  });
})();
