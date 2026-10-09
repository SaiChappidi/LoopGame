-- LOOP hosted publishing prototype: private packages, developer submissions,
-- human review, and a public catalog. Apply to a dedicated test project only.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.loop_user_roles (
    user_id uuid primary key references auth.users(id) on delete cascade,
    role text not null default 'developer'
        check (role in ('developer', 'reviewer', 'admin')),
    created_at timestamptz not null default now()
);

create or replace function public.loop_has_role(wanted_role text)
returns boolean
language sql stable security definer
set search_path = ''
as $$
    select exists (
        select 1 from public.loop_user_roles r
        where r.user_id = (select auth.uid())
          and (r.role = wanted_role or r.role = 'admin')
    );
$$;

revoke all on function public.loop_has_role(text) from public;
grant execute on function public.loop_has_role(text) to authenticated;
grant execute on function public.loop_has_role(text) to anon;

create or replace function public.loop_add_new_developer()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
    insert into public.loop_user_roles(user_id, role)
    values (new.id, 'developer')
    on conflict (user_id) do nothing;
    return new;
end;
$$;

drop trigger if exists loop_new_user_role on auth.users;
create trigger loop_new_user_role after insert on auth.users
for each row execute function public.loop_add_new_developer();

-- Existing test accounts also receive the least-privileged developer role.
insert into public.loop_user_roles(user_id, role)
select id, 'developer' from auth.users
on conflict (user_id) do nothing;

create table if not exists public.loop_games (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid not null references auth.users(id) on delete restrict,
    slug text not null unique check (slug ~ '^[a-z0-9_]{2,40}$'),
    title text not null check (char_length(title) between 2 and 60),
    description text not null check (char_length(description) between 10 and 2000),
    category text not null default 'Arcade',
    age_rating text not null default 'Everyone'
        check (age_rating in ('Everyone', '10+', '13+', '16+', '18+')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.loop_game_versions (
    id uuid primary key default gen_random_uuid(),
    game_id uuid not null references public.loop_games(id) on delete cascade,
    version text not null check (version ~ '^[0-9]+[.][0-9]+([.][0-9]+)?$'),
    package_path text not null unique,
    package_bytes bigint not null check (package_bytes between 1 and 15728640),
    sha256 text not null check (sha256 ~ '^[0-9a-fA-F]{64}$'),
    manifest jsonb not null,
    status text not null default 'pending_review'
        check (status in ('pending_review', 'approved', 'rejected', 'published', 'withdrawn')),
    release_notes text not null default '',
    submitted_at timestamptz not null default now(),
    reviewed_at timestamptz,
    unique (game_id, version)
);

create table if not exists public.loop_reviews (
    id uuid primary key default gen_random_uuid(),
    version_id uuid not null references public.loop_game_versions(id) on delete cascade,
    reviewer_id uuid not null references auth.users(id) on delete restrict,
    decision text not null check (decision in ('approved', 'rejected')),
    notes text not null default '' check (char_length(notes) <= 2000),
    created_at timestamptz not null default now()
);

create table if not exists public.loop_comments (
    id uuid primary key default gen_random_uuid(),
    game_id uuid not null references public.loop_games(id) on delete cascade,
    author_id uuid not null references auth.users(id) on delete restrict,
    body text not null check (char_length(body) between 1 and 1000),
    status text not null default 'visible' check (status in ('visible', 'hidden')),
    created_at timestamptz not null default now()
);

create or replace function public.loop_owns_game(target_game uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
    select exists (
        select 1 from public.loop_games g
        where g.id = target_game and g.owner_id = (select auth.uid())
    );
$$;

create or replace function public.loop_has_published_version(target_game uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
    select exists (
        select 1 from public.loop_game_versions v
        where v.game_id = target_game and v.status = 'published'
    );
$$;

revoke all on function public.loop_owns_game(uuid) from public;
revoke all on function public.loop_has_published_version(uuid) from public;
grant execute on function public.loop_owns_game(uuid) to anon, authenticated;
grant execute on function public.loop_has_published_version(uuid) to anon, authenticated;

create index if not exists loop_versions_game_status_idx
    on public.loop_game_versions(game_id, status, submitted_at desc);
create index if not exists loop_comments_game_created_idx
    on public.loop_comments(game_id, created_at desc);

alter table public.loop_user_roles enable row level security;
alter table public.loop_games enable row level security;
alter table public.loop_game_versions enable row level security;
alter table public.loop_reviews enable row level security;
alter table public.loop_comments enable row level security;

drop policy if exists loop_roles_read_self on public.loop_user_roles;
create policy loop_roles_read_self on public.loop_user_roles
for select to authenticated using (user_id = (select auth.uid()) or public.loop_has_role('reviewer'));

drop policy if exists loop_games_public_or_owner_read on public.loop_games;
create policy loop_games_public_or_owner_read on public.loop_games
for select to anon, authenticated using (
    public.loop_has_published_version(id)
    or owner_id = (select auth.uid())
    or public.loop_has_role('reviewer')
);

drop policy if exists loop_games_owner_insert on public.loop_games;
create policy loop_games_owner_insert on public.loop_games
for insert to authenticated with check (
    owner_id = (select auth.uid()) and public.loop_has_role('developer')
);

drop policy if exists loop_games_owner_update on public.loop_games;
create policy loop_games_owner_update on public.loop_games
for update to authenticated using (
    owner_id = (select auth.uid()) and not public.loop_has_role('reviewer')
) with check (owner_id = (select auth.uid()));

drop policy if exists loop_versions_public_owner_reviewer_read on public.loop_game_versions;
create policy loop_versions_public_owner_reviewer_read on public.loop_game_versions
for select to anon, authenticated using (
    status = 'published'
    or public.loop_owns_game(game_id)
    or public.loop_has_role('reviewer')
);

drop policy if exists loop_versions_owner_submit on public.loop_game_versions;
create policy loop_versions_owner_submit on public.loop_game_versions
for insert to authenticated with check (
    status = 'pending_review'
    and public.loop_owns_game(game_id)
    and package_path like (select auth.uid())::text || '/%'
);

drop policy if exists loop_versions_reviewer_update on public.loop_game_versions;
create policy loop_versions_reviewer_update on public.loop_game_versions
for update to authenticated using (
    public.loop_has_role('reviewer')
) with check (public.loop_has_role('reviewer'));

drop policy if exists loop_reviews_reviewer_read on public.loop_reviews;
create policy loop_reviews_reviewer_read on public.loop_reviews
for select to authenticated using (
    reviewer_id = (select auth.uid()) or public.loop_has_role('reviewer')
);

drop policy if exists loop_reviews_reviewer_insert on public.loop_reviews;
create policy loop_reviews_reviewer_insert on public.loop_reviews
for insert to authenticated with check (
    reviewer_id = (select auth.uid()) and public.loop_has_role('reviewer')
);

drop policy if exists loop_comments_read_visible on public.loop_comments;
create policy loop_comments_read_visible on public.loop_comments
for select to anon, authenticated using (status = 'visible' or public.loop_has_role('reviewer'));

drop policy if exists loop_comments_insert_self on public.loop_comments;
create policy loop_comments_insert_self on public.loop_comments
for insert to authenticated with check (
    author_id = (select auth.uid())
    and public.loop_has_published_version(game_id)
);

-- A private bucket stores pending and published bundles. The object key must
-- start with the uploader's auth UUID. No anonymous uploads are permitted.
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('loop-game-packages', 'loop-game-packages', false, 15728640,
        array['application/zip', 'application/octet-stream'])
on conflict (id) do update set public = false, file_size_limit = 15728640;

drop policy if exists loop_package_upload_own_folder on storage.objects;
create policy loop_package_upload_own_folder on storage.objects
for insert to authenticated with check (
    bucket_id = 'loop-game-packages'
    and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists loop_package_read_owner_or_reviewer on storage.objects;
create policy loop_package_read_owner_or_reviewer on storage.objects
for select to authenticated using (
    bucket_id = 'loop-game-packages'
    and (
        (storage.foldername(name))[1] = (select auth.uid())::text
        or public.loop_has_role('reviewer')
    )
);

drop policy if exists loop_package_read_published on storage.objects;
create policy loop_package_read_published on storage.objects
for select to anon, authenticated using (
    bucket_id = 'loop-game-packages'
    and exists (
        select 1 from public.loop_game_versions v
        where v.package_path = name and v.status = 'published'
    )
);

-- Reviewer actions are callable by signed-in reviewers only. Approval is
-- distinct from publication; the owner or reviewer can publish an approved
-- immutable version through the guarded RPC below.
create or replace function public.loop_review_version(
    target_version uuid, decision_value text, review_notes text default ''
) returns void
language plpgsql security definer
set search_path = ''
as $$
declare current_status text;
begin
    if not public.loop_has_role('reviewer') then
        raise exception 'reviewer role required' using errcode = '42501';
    end if;
    if decision_value not in ('approved', 'rejected') then
        raise exception 'decision must be approved or rejected';
    end if;
    select status into current_status from public.loop_game_versions
    where id = target_version for update;
    if current_status is distinct from 'pending_review' then
        raise exception 'version is not awaiting review';
    end if;
    update public.loop_game_versions
        set status = decision_value, reviewed_at = now()
        where id = target_version;
    insert into public.loop_reviews(version_id, reviewer_id, decision, notes)
        values (target_version, (select auth.uid()), decision_value, left(coalesce(review_notes, ''), 2000));
end;
$$;

create or replace function public.loop_publish_version(target_version uuid)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare current_status text; game_owner uuid;
begin
    select v.status, g.owner_id into current_status, game_owner
    from public.loop_game_versions v join public.loop_games g on g.id = v.game_id
    where v.id = target_version for update of v;
    if current_status is distinct from 'approved' then
        raise exception 'version must be approved before publication';
    end if;
    if game_owner <> (select auth.uid()) and not public.loop_has_role('reviewer') then
        raise exception 'only the owner or reviewer may publish';
    end if;
    update public.loop_game_versions set status = 'withdrawn'
    where game_id = (select game_id from public.loop_game_versions where id = target_version)
      and status = 'published';
    update public.loop_game_versions set status = 'published' where id = target_version;
end;
$$;

revoke all on function public.loop_review_version(uuid, text, text) from public;
revoke all on function public.loop_publish_version(uuid) from public;
grant execute on function public.loop_review_version(uuid, text, text) to authenticated;
grant execute on function public.loop_publish_version(uuid) to authenticated;

grant select, insert, update on public.loop_user_roles to authenticated;
revoke insert, update, delete on public.loop_user_roles from authenticated;
grant select, insert, update on public.loop_games to authenticated;
grant select on public.loop_games to anon;
grant select, insert on public.loop_game_versions to authenticated;
grant select on public.loop_game_versions to anon;
grant select, insert on public.loop_reviews to authenticated;
grant select, insert on public.loop_comments to authenticated;
grant select on public.loop_comments to anon;
