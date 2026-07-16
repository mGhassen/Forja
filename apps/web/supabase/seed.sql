-- Local seed after `supabase db reset`.
-- Test auth users are created by `scripts/create-forja-test-users.js` (Admin Auth API).

insert into public.announcements (title, body, severity, active)
select
  'Welcome to Forja',
  'Local Supabase is running. Sign in on the web portal or sync settings from the app.',
  'info',
  true
where not exists (
  select 1 from public.announcements where title = 'Welcome to Forja'
);
