-- Deal Me In — Supabase setup
-- Paste this whole file into Supabase Dashboard → SQL Editor → New query → Run.

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

alter table event_details enable row level security;
alter table rsvps enable row level security;

-- No login for guests: anyone holding the page's anon key (embedded in the
-- app, same trust model as a shared link) can read and write these two
-- tables. Fine for a friend group's game night; don't put sensitive data here.

create policy "public read event" on event_details for select using (true);
create policy "public write event" on event_details for insert with check (true);
create policy "public update event" on event_details for update using (true) with check (true);

create policy "public read rsvps" on rsvps for select using (true);
create policy "public write rsvps" on rsvps for insert with check (true);
create policy "public update rsvps" on rsvps for update using (true) with check (true);
create policy "public delete rsvps" on rsvps for delete using (true);

-- Live sync: let the app hear changes from other guests in real time.
alter publication supabase_realtime add table event_details;
alter publication supabase_realtime add table rsvps;
