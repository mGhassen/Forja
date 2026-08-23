function extract(ctx) {
  var cfg = ctx.config || {};
  var api = (cfg.api || 'https://api.hlowb.com').replace(/\/$/, '');
  var pkg = cfg.packageName || 'com.external.castle';
  var channel = cfg.channel || 'IndiaA';
  var client = String(cfg.clientType || '1');
  var lang = cfg.lang || 'en-US';
  var ua = 'okhttp/4.9.3';
  var playUa =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var tmdbKey = cfg.tmdbKey || '439c478a771f35c05022f9feabcca01c';
  var isTv = ctx.type !== 'movie';

  function apiHeaders(extra) {
    return Object.assign(
      {
        'User-Agent': ua,
        Accept: 'application/json',
        'Accept-Language': 'en-US,en;q=0.9',
        Connection: 'Keep-Alive',
        Referer: api,
      },
      extra || {},
    );
  }

  function playHeaders() {
    return {
      'User-Agent': playUa,
      Accept:
        'video/webm,video/ogg,video/*;q=0.9,application/ogg;q=0.7,audio/*;q=0.6,*/*;q=0.5',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'identity',
      Connection: 'keep-alive',
      'Sec-Fetch-Dest': 'video',
      'Sec-Fetch-Mode': 'no-cors',
      'Sec-Fetch-Site': 'cross-site',
      DNT: '1',
    };
  }

  function getJson(url, headers) {
    return ctx.fetch(url, { headers: headers || apiHeaders() }).then(function (r) {
      return r.json();
    });
  }

  function postJson(url, body) {
    return ctx
      .fetch(url, {
        method: 'POST',
        headers: apiHeaders({ 'Content-Type': 'application/json' }),
        body: JSON.stringify(body),
      })
      .then(function (r) {
        return r.text();
      });
  }

  function normCipherBody(text) {
    var trimmed = String(text || '').trim();
    if (!trimmed) return '';
    try {
      var json = JSON.parse(trimmed);
      if (json && typeof json.data === 'string') return json.data.trim();
    } catch (e) {}
    return trimmed;
  }

  function decrypt(encryptedB64, securityKeyB64) {
    var suffix = 'T!BgJB';
    var keyMaterial = ctx.crypto.enc.Base64.parse(securityKeyB64).concat(ctx.crypto.enc.Utf8.parse(suffix));
    var finalKey;
    if (keyMaterial.sigBytes < 16) {
      finalKey = keyMaterial.concat(ctx.crypto.lib.WordArray.random(16 - keyMaterial.sigBytes));
      finalKey.sigBytes = 16;
    } else if (keyMaterial.sigBytes > 16) {
      finalKey = ctx.crypto.lib.WordArray.create(keyMaterial.words.slice(0, 4), 16);
    } else {
      finalKey = keyMaterial;
    }
    var iv = finalKey;
    var out = ctx.crypto.AES.decrypt(encryptedB64, finalKey, {
      iv: iv,
      mode: ctx.crypto.mode.CBC,
      padding: ctx.crypto.pad.Pkcs7,
    }).toString(ctx.crypto.enc.Utf8);
    return out ? JSON.parse(out) : null;
  }

  function unwrapData(obj) {
    return (obj && obj.data && typeof obj.data === 'object') ? obj.data : obj || {};
  }

  function getSecurityKey() {
    var url =
      api +
      '/v0.1/system/getSecurityKey/1?channel=' +
      encodeURIComponent(channel) +
      '&clientType=' +
      encodeURIComponent(client) +
      '&lang=' +
      encodeURIComponent(lang);
    return getJson(url).then(function (j) {
      return j && j.data ? j.data : '';
    });
  }

  function fetchDecrypted(url, body) {
    var req = body ? postJson(url, body) : ctx.fetch(url, { headers: apiHeaders() }).then(function (r) { return r.text(); });
    return Promise.all([getSecurityKey(), req]).then(function (pair) {
      if (typeof ctx.log === 'function') ctx.log('Starting local AES-CBC decryption...');
      var out = decrypt(normCipherBody(pair[1]), pair[0]);
      if (typeof ctx.log === 'function') ctx.log('Local decryption successful');
      return out;
    });
  }

  function tmdbInfo() {
    var path = isTv ? 'tv' : 'movie';
    return getJson(
      'https://api.themoviedb.org/3/' +
        path +
        '/' +
        encodeURIComponent(String(ctx.tmdbId || '')) +
        '?api_key=' +
        encodeURIComponent(tmdbKey),
      {
        'User-Agent': playUa,
        Accept: 'application/json',
      },
    ).then(function (d) {
      return {
        title: isTv ? d.name : d.title,
        year: String((isTv ? d.first_air_date : d.release_date) || '').substring(0, 4),
      };
    });
  }

  function searchMovieId(info) {
    var keyword = info.year ? info.title + ' ' + info.year : info.title;
    if (isTv && ctx.season) {
      keyword = info.title + ' Season ' + Number(ctx.season || 1);
    }
    var url =
      api +
      '/film-api/v1.1.0/movie/searchByKeyword?channel=' +
      encodeURIComponent(channel) +
      '&clientType=' +
      encodeURIComponent(client) +
      '&keyword=' +
      encodeURIComponent(keyword) +
      '&lang=' +
      encodeURIComponent(lang) +
      '&mode=1&packageName=' +
      encodeURIComponent(pkg) +
      '&page=1&size=30';
    return fetchDecrypted(url).then(function (j) {
      var rows = unwrapData(j).rows || [];
      if (!rows.length && isTv && ctx.season) {
        // Fall back to bare title if season-qualified search misses.
        var fallback =
          api +
          '/film-api/v1.1.0/movie/searchByKeyword?channel=' +
          encodeURIComponent(channel) +
          '&clientType=' +
          encodeURIComponent(client) +
          '&keyword=' +
          encodeURIComponent(info.year ? info.title + ' ' + info.year : info.title) +
          '&lang=' +
          encodeURIComponent(lang) +
          '&mode=1&packageName=' +
          encodeURIComponent(pkg) +
          '&page=1&size=30';
        return fetchDecrypted(fallback).then(function (j2) {
          return pickSearchRow(unwrapData(j2).rows || [], info);
        });
      }
      return pickSearchRow(rows, info);
    });
  }

  function pickSearchRow(rows, info) {
    if (!rows.length) return '';
    var want = String(info.title || '').toLowerCase();
    var seasonHint = isTv && ctx.season ? 'season ' + Number(ctx.season || 1) : '';
    var match =
      rows.filter(function (item) {
        var t = String(item.title || item.name || '').toLowerCase();
        if (!(t.indexOf(want) >= 0 || want.indexOf(t) >= 0)) return false;
        if (seasonHint && t.indexOf(seasonHint) < 0 && t.indexOf('s0' + Number(ctx.season || 1)) < 0) {
          return false;
        }
        return true;
      })[0] ||
      rows.filter(function (item) {
        var t = String(item.title || item.name || '').toLowerCase();
        return t.indexOf(want) >= 0 || want.indexOf(t) >= 0;
      })[0] ||
      rows[0];
    var movieId = String(match.id || match.redirectId || match.redirectIdStr || '');
    if (movieId && typeof ctx.log === 'function') {
      ctx.log('Found match: ' + (match.title || match.name || info.title) + ' (id: ' + movieId + ')');
    }
    return movieId;
  }

  function details(movieId) {
    var url =
      api +
      '/film-api/v1.9.9/movie?channel=' +
      encodeURIComponent(channel) +
      '&clientType=' +
      encodeURIComponent(client) +
      '&lang=' +
      encodeURIComponent(lang) +
      '&movieId=' +
      encodeURIComponent(movieId) +
      '&packageName=' +
      encodeURIComponent(pkg);
    return fetchDecrypted(url);
  }

  function getVideo(movieId, episodeId, languageId, resolution) {
    var url =
      api +
      '/film-api/v2.0.1/movie/getVideo2?clientType=' +
      encodeURIComponent(client) +
      '&packageName=' +
      encodeURIComponent(pkg) +
      '&channel=' +
      encodeURIComponent(channel) +
      '&lang=' +
      encodeURIComponent(lang);
    var body = {
      mode: '1',
      appMarket: 'GuanWang',
      clientType: client,
      woolUser: 'false',
      apkSignKey: 'ED0955EB04E67A1D9F3305B95454FED485261475',
      androidVersion: '13',
      movieId: String(movieId),
      episodeId: String(episodeId),
      isNewUser: 'true',
      resolution: String(resolution),
      packageName: pkg,
    };
    if (languageId) body.languageId = String(languageId);
    return fetchDecrypted(url, body);
  }

  function qualityLabel(v, fallback) {
    var q = String(v || '').replace(/^(SD|HD|FHD)\s+/i, '');
    return q || fallback;
  }

  function mapVideoResponse(videoData, info, seasonNum, episodeNum, resolution, languageInfo) {
    var data = unwrapData(videoData);
    var videoUrl = data.videoUrl;
    if (!videoUrl) return [];
    var subtitles = [];
    (data.subtitles || []).forEach(function (sub) {
      if (!sub || !sub.url) return;
      subtitles.push({
        url: sub.url,
        lang: sub.abbreviate || 'Unknown',
      });
    });
    var baseTitle = info.title || 'Unknown';
    if (isTv) baseTitle = baseTitle + ' S' + seasonNum + 'E' + episodeNum;
    var quality = resolution === 3 ? '1080p' : resolution === 2 ? '720p' : '480p';
    var rows = [];
    if (Array.isArray(data.videos) && data.videos.length) {
      data.videos.forEach(function (video) {
        rows.push({
          url: video.url || videoUrl,
          name: 'Castle ' + languageInfo,
          quality: qualityLabel(video.resolutionDescription || video.resolution, quality),
          headers: playHeaders(),
          subtitles: subtitles,
        });
      });
      return rows;
    }
    return [
      {
        url: videoUrl,
        name: 'Castle ' + languageInfo,
        quality: quality,
        headers: playHeaders(),
        subtitles: subtitles,
      },
    ];
  }

  return tmdbInfo()
    .then(function (info) {
      if (typeof ctx.log === 'function') {
        ctx.log(
          'Starting extraction for TMDB ID: ' +
            ctx.tmdbId +
            ', Type: ' +
            ctx.type +
            (isTv ? ', S:' + (ctx.season || 1) + 'E:' + (ctx.episode || 1) : ''),
        );
        ctx.log('TMDB Info: "' + info.title + '" (' + info.year + ')');
      }
      return searchMovieId(info).then(function (movieId) {
        if (!movieId) return [];
        if (typeof ctx.log === 'function') ctx.log('Fetching details for movieId: ' + movieId);
        return details(movieId).then(function (rawDetails) {
          var currentMovieId = movieId;
          var detailsData = unwrapData(rawDetails);
          function seasonMovieId(s) {
            if (!s) return '';
            return String(
              s.movieId ||
                s.redirectId ||
                s.redirectIdStr ||
                s.id ||
                '',
            );
          }
          function pickEpisodes(data) {
            if (!data) return [];
            if (Array.isArray(data.episodes) && data.episodes.length) return data.episodes;
            if (Array.isArray(data.episodeList) && data.episodeList.length) return data.episodeList;
            if (Array.isArray(data.eps) && data.eps.length) return data.eps;
            return [];
          }
          if (isTv) {
            var wantSeason = Number(ctx.season || 1);
            var seasons = detailsData.seasons || detailsData.seasonList || [];
            var seasonHit = seasons.filter(function (s) {
              return Number(s.number != null ? s.number : s.seasonNumber) === wantSeason;
            })[0];
            // Some titles only list seasons on the parent; episodes live on season movieId.
            var sid = seasonMovieId(seasonHit);
            if (sid && sid !== String(movieId)) {
              currentMovieId = sid;
              return details(currentMovieId).then(function (seasonDetails) {
                var sd = unwrapData(seasonDetails);
                return {
                  info: info,
                  movieId: currentMovieId,
                  detailsData: sd,
                  episodesOverride: pickEpisodes(sd).length
                    ? pickEpisodes(sd)
                    : pickEpisodes(seasonHit),
                };
              });
            }
            if (seasonHit && pickEpisodes(seasonHit).length) {
              return {
                info: info,
                movieId: currentMovieId,
                detailsData: detailsData,
                episodesOverride: pickEpisodes(seasonHit),
              };
            }
          }
          return {
            info: info,
            movieId: currentMovieId,
            detailsData: detailsData,
            episodesOverride: pickEpisodes(detailsData),
          };
        });
      });
    })
    .then(function (state) {
      if (!state || !state.detailsData) return [];
      var seasonNum = Number(ctx.season || 1);
      var episodeNum = Number(ctx.episode || 1);
      var episodes = state.episodesOverride || [];
      if (!episodes.length) {
        var detailsData = state.detailsData || {};
        episodes = detailsData.episodes || detailsData.episodeList || detailsData.eps || [];
      }
      if (!episodes.length && Array.isArray((state.detailsData || {}).seasons)) {
        var seasonRow = state.detailsData.seasons.filter(function (s) {
          return Number(s.number != null ? s.number : s.seasonNumber) === seasonNum;
        })[0];
        if (seasonRow) {
          episodes = seasonRow.episodes || seasonRow.episodeList || seasonRow.eps || [];
        }
      }
      function epNo(e) {
        if (!e) return NaN;
        if (e.number != null) return Number(e.number);
        if (e.episodeNumber != null) return Number(e.episodeNumber);
        if (e.episode_number != null) return Number(e.episode_number);
        if (e.ep != null) return Number(e.ep);
        return NaN;
      }
      var episodeHit = isTv
        ? episodes.filter(function (e) { return epNo(e) === episodeNum; })[0]
        : episodes[0];
      if (!episodeHit || !(episodeHit.id || episodeHit.episodeId)) {
        if (typeof ctx.error === 'function') {
          ctx.error(
            'Could not find episode ID (episodes=' +
              episodes.length +
              ' want=S' +
              seasonNum +
              'E' +
              episodeNum +
              ' sample=' +
              JSON.stringify(episodes.slice(0, 2)).slice(0, 240) +
              ')',
          );
        }
        return [];
      }
      var episodeId = episodeHit.id || episodeHit.episodeId;
      var resolution = 2;
      var tracks = (episodeHit && episodeHit.tracks) || [];
      var tasks = tracks
        .filter(function (track) { return track && track.existIndividualVideo && track.languageId; })
        .map(function (track) {
          var langName = track.languageName || track.abbreviate || 'Unknown';
          return getVideo(state.movieId, episodeId, track.languageId, resolution)
            .then(function (videoData) {
              return mapVideoResponse(videoData, state.info, seasonNum, episodeNum, resolution, '[' + langName + ']');
            })
            .catch(function () {
              return [];
            });
        });
      return Promise.all(tasks).then(function (groups) {
        var out = [].concat.apply([], groups);
        if (out.length) return out;
        return getVideo(state.movieId, episodeId, '', resolution)
          .then(function (videoData) {
            return mapVideoResponse(videoData, state.info, seasonNum, episodeNum, resolution, '[Shared]');
          })
          .catch(function () {
            return [];
          });
      });
    })
    .catch(function () {
      return [];
    });
}
