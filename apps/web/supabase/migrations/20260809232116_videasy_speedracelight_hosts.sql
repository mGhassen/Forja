-- Videasy live API moved off wingsdatabase (DNS dead) to speedracelight.
-- Remap cloud provider_runtime_config so clients stop seeding the stale hosts.

UPDATE public.provider_runtime_config
SET
  config = jsonb_set(
    jsonb_set(
      config,
      '{apis,videasyApiHost}',
      '"api.speedracelight.com"'
    ),
    '{apis,videasyDbHost}',
    '"db.speedracelight.com"'
  ),
  updated_at = now()
WHERE id = 1
  AND (
    config #>> '{apis,videasyApiHost}' IS DISTINCT FROM 'api.speedracelight.com'
    OR config #>> '{apis,videasyDbHost}' IS DISTINCT FROM 'db.speedracelight.com'
  );
