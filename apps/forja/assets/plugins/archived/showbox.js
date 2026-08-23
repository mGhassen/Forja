function extract(ctx) {
  var cfg = ctx.config || {};
  var apiBase = cfg.apiBase || 'https://id-mapping-api-showbox-proxy.hf.space/api/media';
  var tmdbKey = cfg.tmdbKey || '439c478a771f35c05022f9feabcca01c';
  var uiToken = String(cfg.uiToken || '').trim();
  var ossGroup = cfg.ossGroup ? String(cfg.ossGroup) : '';
  var ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  var isTv = ctx.type !== 'movie';

  if (!uiToken) return Promise.resolve([]);

  function normalizeToken(raw) {
    if (!raw) return '';
    if (raw.startsWith('ui=')) return raw.substring(3);
    if (!raw.startsWith('eyJ')) return raw;
    try {
      var parsed = JSON.parse(atob(raw));
      if (parsed && parsed.encrypt_data && ctx.crypto && ctx.crypto.TripleDES) {
        var key = ctx.crypto.enc.Utf8.parse('123d6cedf626dy54233aa1w6');
        var iv = ctx.crypto.enc.Utf8.parse('wEiphTn!');
        var decrypted = ctx.crypto.TripleDES.decrypt(parsed.encrypt_data, key, {
          iv: iv, mode: ctx.crypto.mode.CBC, padding: ctx.crypto.pad.Pkcs7,
        });
        var text = decrypted.toString(ctx.crypto.enc.Utf8);
        var obj = JSON.parse(text);
        if (obj && obj.uid) return String(obj.uid);
      }
    } catch (e) {}
    return raw;
  }

  uiToken = normalizeToken(uiToken);

  function qualityFromName(q) {
    if (!q) return 'Unknown';
    var u = String(q).toUpperCase();
    if (u === 'ORG' || u === 'ORIGINAL') return 'Original';
    if (u === '4K' || u === '2160P') return '4K';
    if (u === '1440P' || u === '2K') return '1440p';
    if (u === '1080P' || u === 'FHD') return '1080p';
    if (u === '720P' || u === 'HD') return '720p';
    if (u === '480P' || u === 'SD') return '480p';
    var m = String(q).match(/(\d{3,4})[pP]?/);
    if (m) {
      var r = parseInt(m[1], 10);
      if (r >= 2160) return '4K';
      if (r >= 1440) return '1440p';
      if (r >= 1080) return '1080p';
      if (r >= 720) return '720p';
      if (r >= 480) return '480p';
    }
    return 'Unknown';
  }

  function processResponse(data, mediaInfo, season, episode) {
    var streams = [];
    if (!data || !data.success || !Array.isArray(data.versions)) return streams;
    var streamTitle = mediaInfo.title || 'Unknown';
    if (mediaInfo.year) streamTitle += ' (' + mediaInfo.year + ')';
    if (isTv && season && episode) {
      streamTitle = (mediaInfo.title || 'Unknown') + ' S' + String(season).padStart(2, '0') +
        'E' + String(episode).padStart(2, '0');
    }
    data.versions.forEach(function (version, vi) {
      (version.links || []).forEach(function (link) {
        if (!link.url) return;
        var q = qualityFromName(link.quality || 'Unknown');
        var name = 'ShowBox' + (data.versions.length > 1 ? ' V' + (vi + 1) : '') + ' ' + q;
        streams.push({ name: name, url: link.url, quality: q, size: link.size || version.size });
      });
    });
    return streams;
  }

  function extractFebBox(showboxId, season, episode) {
    var boxType = isTv ? 2 : 1;
    var shareUrl = 'https://www.febbox.com/mbp/to_share_page?box_type=' + boxType + '&mid=' + showboxId + '&json=1';
    return ctx.fetch(shareUrl).then(function (r) { return r.json(); }).then(function (shareRes) {
      if (!shareRes || shareRes.code !== 1 || !shareRes.data) return [];
      var shareLink = shareRes.data.share_link || shareRes.data.shareLink;
      if (!shareLink) return [];
      var shareKey = shareLink.split('/').pop();
      return ctx.fetch('https://www.febbox.com/file/file_share_list?share_key=' + shareKey, {
        headers: { 'Accept-Language': 'en' },
      }).then(function (r) { return r.json(); }).then(function (listRes) {
        if (!listRes || listRes.code !== 1 || !listRes.data || !listRes.data.file_list) return [];
        var fids = [];
        if (!isTv) fids = listRes.data.file_list;
        else {
          var seasonFolder = listRes.data.file_list.find(function (f) {
            return f.file_name && f.file_name.toLowerCase() === 'season ' + season;
          });
          if (!seasonFolder) return [];
          return ctx.fetch('https://www.febbox.com/file/file_share_list?share_key=' + shareKey +
            '&parent_id=' + seasonFolder.fid + '&page=1', { headers: { 'Accept-Language': 'en' } })
            .then(function (r) { return r.json(); }).then(function (seasonRes) {
              if (!seasonRes || seasonRes.code !== 1 || !seasonRes.data) return [];
              var ss = String(season).padStart(2, '0');
              var es = String(episode).padStart(2, '0');
              fids = (seasonRes.data.file_list || []).filter(function (f) {
                var n = (f.file_name || '').toLowerCase();
                return n.indexOf('s' + ss + 'e' + es) >= 0 || n.indexOf('s' + season + 'e' + episode) >= 0;
              });
              return processFebBoxFiles(fids, shareKey);
            });
        }
        return processFebBoxFiles(fids, shareKey);
      });
    }).catch(function () { return []; });

    function processFebBoxFiles(fids, shareKey) {
      var videoHeaders = {
        Accept: '*/*', 'Accept-Language': 'en-US,en;q=0.8', Connection: 'keep-alive',
        Range: 'bytes=0-', Referer: 'https://www.febbox.com/', 'User-Agent': ua,
      };
      var cookie = uiToken.startsWith('ui=') ? uiToken : 'ui=' + uiToken;
      return Promise.all(fids.map(function (file) {
        return ctx.fetch('https://www.febbox.com/console/video_quality_list?fid=' + file.fid + '&share_key=' + shareKey, {
          headers: { Cookie: cookie },
        }).then(function (r) { return r.json(); }).then(function (qualityRes) {
          if (!qualityRes || !qualityRes.html) return [];
          var $ = ctx.html(qualityRes.html);
          var out = [];
          $('div.file_quality').each(function () {
            var el = $(this);
            var streamUrl = el.attr('data-url');
            var qLabel = el.attr('data-quality');
            var sizeText = el.find('.size').text().trim();
            if (streamUrl) {
              out.push({
                name: 'ShowBox FebBox [' + qualityFromName(qLabel) + ']',
                url: streamUrl,
                quality: qualityFromName(qLabel),
                size: sizeText || file.file_size,
                headers: videoHeaders,
              });
            }
          });
          return out;
        }).catch(function () { return []; });
      })).then(function (groups) { return [].concat.apply([], groups); });
    }
  }

  return ctx.fetch(
    'https://api.themoviedb.org/3/' + (isTv ? 'tv' : 'movie') + '/' + encodeURIComponent(String(ctx.tmdbId || '')) +
      '?api_key=' + encodeURIComponent(tmdbKey),
    { headers: { Accept: 'application/json' } },
  ).then(function (r) { return r.json(); }).then(function (mediaInfo) {
    var title = isTv ? mediaInfo.name : mediaInfo.title;
    var date = (isTv ? mediaInfo.first_air_date : mediaInfo.release_date) || '';
    var year = date ? parseInt(date.split('-')[0], 10) : null;
    var info = { title: title, year: year };
    var season = ctx.season || 1;
    var episode = ctx.episode || 1;
    var proxyUrl;
    if (isTv) {
      proxyUrl = ossGroup
        ? apiBase + '/tv/' + ctx.tmdbId + '/oss=' + ossGroup + '/' + season + '/' + episode + '?cookie=' + encodeURIComponent(uiToken)
        : apiBase + '/tv/' + ctx.tmdbId + '/' + season + '/' + episode + '?cookie=' + encodeURIComponent(uiToken);
    } else {
      proxyUrl = apiBase + '/movie/' + ctx.tmdbId + '?cookie=' + encodeURIComponent(uiToken);
    }
    var streams = [];
    return ctx.fetch(proxyUrl, {
      headers: { 'User-Agent': ua, Accept: 'application/json', 'Content-Type': 'application/json' },
    }).then(function (r) { return r.ok ? r.json() : null; }).then(function (data) {
      if (data) {
        streams = processResponse(data, info, season, episode);
        var showboxId = data.id || data.mid || (data.data && (data.data.id || data.data.mid));
        if (showboxId) {
          return extractFebBox(showboxId, season, episode).then(function (direct) {
            return streams.concat(direct);
          });
        }
      }
      return streams;
    }).then(function (all) {
      var order = { Original: 6, '4K': 5, '1440p': 4, '1080p': 3, '720p': 2, '480p': 1, Unknown: -2 };
      return all.sort(function (a, b) { return (order[b.quality] || -2) - (order[a.quality] || -2); });
    });
  }).catch(function () { return []; });
}
