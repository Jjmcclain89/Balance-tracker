alter table public.people add column if not exists discord_channel_id text check (discord_channel_id ~ '^[0-9]{15,21}$');
comment on column public.people.discord_id is 'Unused: reports post to people.discord_channel_id instead of DMs';
comment on column public.settings.discord_id is 'Unused: reports post to people.discord_channel_id instead of DMs';
