-- MONZABI database setup. Paste this whole file into Supabase > SQL Editor > New query, then Run.

create table public.profiles (id uuid primary key references auth.users on delete cascade, name text, email text, role text not null default 'user', created_at timestamptz default now());
create table public.tracks (id text primary key, title text not null, artist text not null, album text, genre text, lyrics text, audio text not null, cover text, owner uuid default auth.uid() references auth.users on delete set null, plays int not null default 0, created bigint not null);
create table public.likes (user_id uuid not null default auth.uid() references auth.users on delete cascade, track_id text not null references public.tracks(id) on delete cascade, primary key (user_id, track_id));

create function public.is_admin() returns boolean language sql security definer stable set search_path = public as $$ select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin') $$;
create function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$ begin insert into public.profiles (id, name, email) values (new.id, coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1)), new.email); return new; end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();
create function public.inc_play(tid text) returns void language sql security definer set search_path = public as $$ update public.tracks set plays = plays + 1 where id = tid $$;

alter table public.profiles enable row level security;
alter table public.tracks enable row level security;
alter table public.likes enable row level security;
create policy "profiles read" on public.profiles for select using (id = auth.uid() or public.is_admin());
create policy "tracks read" on public.tracks for select using (auth.uid() is not null);
create policy "tracks add" on public.tracks for insert with check (public.is_admin());
create policy "tracks delete" on public.tracks for delete using (public.is_admin());
create policy "tracks update" on public.tracks for update using (public.is_admin()) with check (public.is_admin());
create policy "likes read" on public.likes for select using (user_id = auth.uid());
create policy "likes add" on public.likes for insert with check (user_id = auth.uid());
create policy "likes delete" on public.likes for delete using (user_id = auth.uid());

insert into storage.buckets (id, name, public, file_size_limit) values ('songs', 'songs', true, 52428800) on conflict (id) do nothing;
create policy "songs read" on storage.objects for select using (bucket_id = 'songs');
create policy "songs add" on storage.objects for insert with check (bucket_id = 'songs' and public.is_admin());
create policy "songs delete" on storage.objects for delete using (bucket_id = 'songs' and public.is_admin());

-- AFTER you sign up on the site with your admin email, run this line once to become admin:
-- update public.profiles set role = 'admin' where email = 'mohammadmehdifouladi88@gmail.com';

-- Song requests (run once, needed for the "Requests" section to be shared with everyone)
create table public.requests (id bigint generated always as identity primary key, user_id uuid not null default auth.uid() references auth.users on delete cascade, user_name text, title text not null, artist text, note text, status text not null default 'pending', created_at timestamptz default now());
create table public.request_votes (request_id bigint not null references public.requests(id) on delete cascade, user_id uuid not null default auth.uid() references auth.users on delete cascade, primary key (request_id, user_id));
alter table public.requests enable row level security;
alter table public.request_votes enable row level security;
create policy "requests read" on public.requests for select using (auth.uid() is not null);
create policy "requests add" on public.requests for insert with check (user_id = auth.uid() and status = 'pending');
create policy "requests admin update" on public.requests for update using (public.is_admin()) with check (public.is_admin());
create policy "requests delete" on public.requests for delete using (user_id = auth.uid() or public.is_admin());
create policy "votes read" on public.request_votes for select using (auth.uid() is not null);
create policy "votes add" on public.request_votes for insert with check (user_id = auth.uid());
create policy "votes delete" on public.request_votes for delete using (user_id = auth.uid());