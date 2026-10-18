create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  type text not null check (type in ('pickup','action','generic')),
  date date not null default current_date,
  -- pickup / action
  casino text,
  identity text,
  amount numeric(12,2),
  pct numeric(6,2) check (pct between 0 and 100),
  cut numeric(12,2),
  -- action
  side text check (side in ('bought','sold')),
  game text,
  result numeric(12,2),
  share numeric(12,2),
  -- generic
  description text,
  dir smallint check (dir in (1,-1)),
  -- effect on balance: positive = I owe them, negative = they owe me
  delta numeric(12,2) not null,
  created_at timestamptz not null default now()
);
create index transactions_user_date_idx on public.transactions (user_id, date desc, created_at desc);

create table public.settings (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  name text not null default '',
  default_pct numeric(6,2) check (default_pct between 0 and 100),
  updated_at timestamptz not null default now()
);

alter table public.transactions enable row level security;
alter table public.settings enable row level security;

create policy "own transactions select" on public.transactions for select to authenticated using ((select auth.uid()) = user_id);
create policy "own transactions insert" on public.transactions for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "own transactions delete" on public.transactions for delete to authenticated using ((select auth.uid()) = user_id);

create policy "own settings select" on public.settings for select to authenticated using ((select auth.uid()) = user_id);
create policy "own settings insert" on public.settings for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "own settings update" on public.settings for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
