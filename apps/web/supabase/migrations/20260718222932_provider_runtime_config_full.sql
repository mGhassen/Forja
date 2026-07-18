-- Expand provider_runtime_config seed to full movie/TV templates + anime APIs.
-- Safe if the v1 row already exists (UPDATE). Fresh installs that only ran the
-- narrow seed get the full overlay; extract logic stays in the app.

update public.provider_runtime_config
set
  schema_version = 1,
  config = '{
    "schema": 1,
    "templates": {
      "vidlink": {
        "movie": "https://vidlink.pro/movie/{tmdb}",
        "tv": "https://vidlink.pro/tv/{tmdb}/{season}/{episode}"
      },
      "vixsrc": {
        "movie": "https://vixsrc.to/movie/{tmdb}/",
        "tv": "https://vixsrc.to/tv/{tmdb}/{season}/{episode}/"
      },
      "vidnest": {
        "movie": "https://vidnest.fun/movie/{tmdb}",
        "tv": "https://vidnest.fun/tv/{tmdb}/{season}/{episode}"
      },
      "vidzee": {
        "movie": "https://player.vidzee.wtf/embed/movie/{tmdb}",
        "tv": "https://player.vidzee.wtf/embed/tv/{tmdb}/{season}/{episode}"
      },
      "vidrock": {
        "movie": "https://vidrock.ru/movie/{tmdb}",
        "tv": "https://vidrock.ru/tv/{tmdb}/{season}/{episode}"
      },
      "vidfast": {
        "movie": "https://vidfast.vc/movie/{tmdb}?autoPlay=true",
        "tv": "https://vidfast.vc/tv/{tmdb}/{season}/{episode}?autoPlay=true"
      },
      "2embed": {
        "movie": "https://2embed.stream/embed/movie/{tmdb}",
        "tv": "https://2embed.stream/embed/tv/{tmdb}/{season}/{episode}"
      },
      "autoembed": {
        "movie": "https://player.autoembed.co/embed/movie/{tmdb}",
        "tv": "https://player.autoembed.co/embed/tv/{tmdb}/{season}-{episode}/"
      },
      "vidlove": {
        "movie": "https://player.vidlove.cc/embed/movie/{tmdb}",
        "tv": "https://player.vidlove.cc/embed/tv/{tmdb}/{season}/{episode}"
      },
      "vidsrcsbs": {
        "movie": "https://vidsrc.sbs/embed/movie/{tmdb}",
        "tv": "https://vidsrc.sbs/embed/tv/{tmdb}/{season}/{episode}"
      },
      "vidsrcwin": {
        "movie": "https://video.moviepire.co/embed/movie/{tmdb}",
        "tv": "https://video.moviepire.co/embed/tv/{tmdb}/{season}/{episode}"
      },
      "111movies": {
        "movie": "https://player.vidlove.cc/embed/movie/{tmdb}",
        "tv": "https://player.vidlove.cc/embed/tv/{tmdb}/{season}/{episode}"
      },
      "moviesapi": {
        "movie": "https://moviesapi.to/movie/{tmdb}",
        "tv": "https://moviesapi.to/tv/{tmdb}-{season}-{episode}"
      }
    },
    "apis": {
      "vidnestApi": "https://new.vidnest.fun",
      "vidnestEmbed": "https://vidnest.fun",
      "anikotoApi": "https://anikotoapi.site",
      "anikotoTv": "https://anikototv.to",
      "allanimeApi": "https://api.allanime.day/api",
      "allanimeReferer": "https://allmanga.to",
      "allanimeClock": "https://allanime.day",
      "watchhentaiOrigin": "https://watchhentai.net",
      "hentainiSite": "https://hentaini.com",
      "hentainiApi": "https://admin.hentaini.com/api",
      "videasyApiHost": "api.wingsdatabase.com",
      "videasyDbHost": "db.wingsdatabase.com",
      "videasyPlayerOrigin": "https://player.videasy.to",
      "vidsrcEmbed": "https://vsembed.su",
      "vixsrcBase": "https://vixsrc.to",
      "index111477": "https://a.111477.xyz"
    },
    "anime": {
      "megaplay": {
        "host": "megaplay.buzz",
        "pathCatalog": "/stream/s-2/{embedId}/{lang}",
        "pathAnilist": "/stream/ani/{anilistId}/{ep}/{lang}",
        "scrapeReferer": "https://www.enma.lol/"
      },
      "vidwish": {
        "host": "vidwish.live",
        "pathCatalog": "/stream/s-2/{embedId}/{lang}",
        "pathAnilist": "/stream/ani/{anilistId}/{ep}/{lang}",
        "scrapeReferer": "https://www.enma.lol/"
      },
      "miruroOrigins": [
        "https://www.miruro.tv",
        "https://www.miruro.to",
        "https://www.miruro.bz",
        "https://www.miruro.ru"
      ],
      "kisskhMirrors": [
        "https://kisskh.co",
        "https://kisskh.nl",
        "https://kisskh.ovh",
        "https://kisskh.la",
        "https://kisskh.do"
      ]
    },
    "cdnRefererRules": [
      {
        "hostContains": ["mewstream", "nekostream", "lostproject", "megaplay"],
        "referer": "https://megaplay.buzz/",
        "origin": "https://megaplay.buzz",
        "acceptRefererContains": ["megaplay"]
      },
      {
        "hostContains": ["watching.onl", "vidwish"],
        "referer": "https://vidwish.live/",
        "origin": "https://vidwish.live",
        "acceptRefererContains": ["vidwish"]
      },
      {
        "hostContains": ["fast4speed"],
        "referer": "https://allmanga.to/",
        "origin": "https://allmanga.to",
        "acceptRefererContains": ["allmanga"]
      }
    ]
  }'::jsonb,
  updated_at = now()
where id = 1;
