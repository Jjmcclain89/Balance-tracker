alter table public.people add column discord_id text check (discord_id ~ '^[0-9]{15,21}$');
