-- Opaque internal member number for support / PostHog (not email / PII).
-- Distinct from accounts.id (UUID). Assigned once; never reused. Starts at 10001.

create sequence if not exists public.accounts_member_number_seq
  as bigint
  start with 10001
  increment by 1
  owned by none;

alter table public.accounts
  add column if not exists member_number bigint;

-- Backfill existing rows in signup order (deterministic).
with ranked as (
  select
    id,
    10000 + row_number() over (order by created_at asc, id asc) as n
  from public.accounts
  where member_number is null
)
update public.accounts a
set member_number = ranked.n
from ranked
where a.id = ranked.id;

-- Advance sequence past backfilled max so new signups do not collide.
select setval(
  'public.accounts_member_number_seq',
  greatest(
    coalesce((select max(member_number) from public.accounts), 10000),
    10000
  )
);

alter table public.accounts
  alter column member_number set default nextval('public.accounts_member_number_seq');

alter table public.accounts
  alter column member_number set not null;

create unique index if not exists accounts_member_number_uidx
  on public.accounts (member_number);

comment on column public.accounts.member_number is
  'Internal opaque member id for ops / analytics (not email).';
