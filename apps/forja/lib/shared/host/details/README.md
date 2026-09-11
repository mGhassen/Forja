# Host details enrich (RFC-106 G11)

TMDB backdrop / rich / logo fetch for kit details lives here.

Kit UI calls [`KitDetailsHostHooks`](../../engine/hub/kit_details_host_hooks.dart);
[`TmdbDetailsEnrich.ensureRegistered`](tmdb_details_enrich.dart) wires `TmdbApi`.

Do not put new `TmdbApi` calls in package widgets.
