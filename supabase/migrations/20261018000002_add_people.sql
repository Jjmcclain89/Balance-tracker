create table public.people (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now(),
  unique (id, user_id)
);
create index people_user_idx on public.people (user_id);

alter table public.people enable row level security;
create policy "own people select" on public.people for select to authenticated using ((select auth.uid()) = user_id);
create policy "own people insert" on public.people for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "own people update" on public.people for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "own people delete" on public.people for delete to authenticated using ((select auth.uid()) = user_id);

-- Move existing data onto a person per user (named from settings.name when set).
insert into public.people (user_id, name)
select u.user_id, coalesce(nullif(trim(s.name), ''), 'Person 1')
from (select distinct user_id from public.transactions union select user_id from public.settings) u
left join public.settings s on s.user_id = u.user_id;

alter table public.transactions add column person_id uuid;
update public.transactions t set person_id = p.id from public.people p where p.user_id = t.user_id;
alter table public.transactions alter column person_id set not null;
-- Composite FK guarantees a transaction's person belongs to the same user.
alter table public.transactions
  add constraint transactions_person_fk foreign key (person_id, user_id) references public.people (id, user_id) on delete cascade;
create index transactions_person_date_idx on public.transactions (person_id, date desc, created_at desc);

-- settings.name (single other person) is superseded by people.name.
comment on column public.settings.name is 'Unused: superseded by people.name';
