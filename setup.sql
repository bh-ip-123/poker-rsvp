-- Deal Me In — Supabase setup
-- Paste this whole file into Supabase Dashboard → SQL Editor → New query → Run.
-- Safe to re-run any time (this file is idempotent, even if you ran an
-- earlier version of it already).

create table if not exists event_details (
  id text primary key default 'main',
  game text,
  host_name text,
  date date,
  time text,
  location text,
  buy_in numeric,
  max_seats int,
  note text,
  updated_at timestamptz default now()
);

create table if not exists rsvps (
  id text primary key,
  name text not null,
  status text not null check (status in ('in','maybe','out')),
  guests int not null default 0,
  note text,
  created_at bigint not null,
  updated_at timestamptz default now()
);

-- Tags each RSVP with the game night it belongs to (the app computes this
-- automatically as the fourth Thursday of the month, 8pm ET — never
-- entered by hand). Old months' RSVPs just stop matching the current
-- value and quietly drop out of the roster; nothing needs to be deleted.
alter table rsvps add column if not exists game_date text;
create index if not exists rsvps_game_date_idx on rsvps (game_date);

-- game_type: the free-text description of the cash game format.
-- override_key: which auto-computed cycle (e.g. '2026-09-24') the saved
-- date/time in this row apply to. When it matches today's computed cycle,
-- the app uses the saved date/time instead of the automatic default —
-- letting the host push a single month's game to a different day. Once
-- the cycle rolls past, a stale override_key is ignored automatically.
alter table event_details add column if not exists game_type text;
alter table event_details add column if not exists override_key text;

-- roster: comma-separated names of the regular players. The app renders
-- one clickable row per name so guests pick their own name and set their
-- status instead of typing it — edit this list anytime from the app's
-- Edit panel, no SQL needed after this.
alter table event_details add column if not exists roster text;

alter table event_details enable row level security;
alter table rsvps enable row level security;

-- No login for guests: anyone holding the page's anon key (embedded in the
-- app, same trust model as a shared link) can read and write these two
-- tables. Fine for a friend group's game night; don't put sensitive data here.

drop policy if exists "public read event" on event_details;
create policy "public read event" on event_details for select using (true);
drop policy if exists "public write event" on event_details;
create policy "public write event" on event_details for insert with check (true);
drop policy if exists "public update event" on event_details;
create policy "public update event" on event_details for update using (true) with check (true);

drop policy if exists "public read rsvps" on rsvps;
create policy "public read rsvps" on rsvps for select using (true);
drop policy if exists "public write rsvps" on rsvps;
create policy "public write rsvps" on rsvps for insert with check (true);
drop policy if exists "public update rsvps" on rsvps;
create policy "public update rsvps" on rsvps for update using (true) with check (true);
drop policy if exists "public delete rsvps" on rsvps;
create policy "public delete rsvps" on rsvps for delete using (true);

-- Live sync: let the app hear changes from other guests in real time.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'event_details'
  ) then
    alter publication supabase_realtime add table event_details;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'rsvps'
  ) then
    alter publication supabase_realtime add table rsvps;
  end if;
end $$;
