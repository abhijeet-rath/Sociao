-- Sociao functions: triggers, views and RPCs.

-- ---------------------------------------------------------------------------
-- New user -> profile + settings
-- ---------------------------------------------------------------------------
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  base text;
  candidate text;
  n int := 0;
begin
  base := regexp_replace(lower(split_part(new.email, '@', 1)), '[^a-z0-9._]', '', 'g');
  if char_length(base) < 3 then
    base := base || 'user';
  end if;
  base := left(base, 24);
  candidate := base;
  while exists (select 1 from public.profiles where username = candidate) loop
    n := n + 1;
    candidate := base || n::text;
  end loop;

  insert into public.profiles (id, username, full_name)
  values (new.id, candidate, coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  insert into public.user_settings (user_id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Counter triggers (counts are maintained by the database, never in Dart)
-- ---------------------------------------------------------------------------
create function public.sync_likes_count()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    update public.posts set likes_count = likes_count + 1 where id = new.post_id;
  else
    update public.posts set likes_count = greatest(likes_count - 1, 0) where id = old.post_id;
  end if;
  return null;
end;
$$;
create trigger likes_count_sync after insert or delete on public.likes
  for each row execute function public.sync_likes_count();

create function public.sync_saves_count()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    update public.posts set saves_count = saves_count + 1 where id = new.post_id;
  else
    update public.posts set saves_count = greatest(saves_count - 1, 0) where id = old.post_id;
  end if;
  return null;
end;
$$;
create trigger saves_count_sync after insert or delete on public.bookmarks
  for each row execute function public.sync_saves_count();

create function public.sync_shares_count()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.posts set shares_count = shares_count + 1 where id = new.post_id;
  return null;
end;
$$;
create trigger shares_count_sync after insert on public.shares
  for each row execute function public.sync_shares_count();

create function public.sync_comments_count()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    update public.posts set comments_count = comments_count + 1 where id = new.post_id;
  else
    update public.posts set comments_count = greatest(comments_count - 1, 0) where id = old.post_id;
  end if;
  return null;
end;
$$;
create trigger comments_count_sync after insert or delete on public.comments
  for each row execute function public.sync_comments_count();

create function public.sync_comment_likes_count()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    update public.comments set likes_count = likes_count + 1 where id = new.comment_id;
  else
    update public.comments set likes_count = greatest(likes_count - 1, 0) where id = old.comment_id;
  end if;
  return null;
end;
$$;
create trigger comment_likes_count_sync after insert or delete on public.comment_likes
  for each row execute function public.sync_comment_likes_count();

-- ---------------------------------------------------------------------------
-- One-level replies only
-- ---------------------------------------------------------------------------
create function public.enforce_single_level_reply()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.parent_id is not null and not exists (
    select 1 from public.comments
    where id = new.parent_id and parent_id is null and post_id = new.post_id
  ) then
    raise exception 'Replies are limited to one level on the same post';
  end if;
  return new;
end;
$$;
create trigger comments_single_level before insert on public.comments
  for each row execute function public.enforce_single_level_reply();

-- ---------------------------------------------------------------------------
-- Conversations
-- ---------------------------------------------------------------------------
create function public.touch_conversation()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.conversations set last_message_at = new.created_at where id = new.conversation_id;
  return null;
end;
$$;
create trigger messages_touch_conversation after insert on public.messages
  for each row execute function public.touch_conversation();

-- ---------------------------------------------------------------------------
-- Notifications (self-actions are skipped)
-- ---------------------------------------------------------------------------
create function public.notify_on_like()
returns trigger language plpgsql security definer set search_path = '' as $$
declare owner_id uuid;
begin
  select user_id into owner_id from public.posts where id = new.post_id;
  if owner_id is not null and owner_id <> new.user_id then
    insert into public.notifications (user_id, actor_id, type, post_id)
    values (owner_id, new.user_id, 'like', new.post_id);
  end if;
  return null;
end;
$$;
create trigger likes_notify after insert on public.likes
  for each row execute function public.notify_on_like();

create function public.notify_on_comment()
returns trigger language plpgsql security definer set search_path = '' as $$
declare owner_id uuid;
begin
  select user_id into owner_id from public.posts where id = new.post_id;
  if owner_id is not null and owner_id <> new.user_id then
    insert into public.notifications (user_id, actor_id, type, post_id)
    values (owner_id, new.user_id, 'comment', new.post_id);
  end if;
  return null;
end;
$$;
create trigger comments_notify after insert on public.comments
  for each row execute function public.notify_on_comment();

create function public.notify_on_follow()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.notifications (user_id, actor_id, type)
  values (new.following_id, new.follower_id, 'follow');
  return null;
end;
$$;
create trigger follows_notify after insert on public.follows
  for each row execute function public.notify_on_follow();

-- ---------------------------------------------------------------------------
-- Helper used by RLS policies (security definer avoids recursive lookups)
-- ---------------------------------------------------------------------------
create function public.is_conversation_member(conv_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.conversations c
    where c.id = conv_id and auth.uid() in (c.user_a, c.user_b)
  );
$$;

-- ---------------------------------------------------------------------------
-- Views (security_invoker: RLS of the caller applies)
-- ---------------------------------------------------------------------------
create view public.post_feed with (security_invoker = true) as
select
  p.id, p.user_id, p.caption, p.media_type, p.media_url, p.thumbnail_url,
  p.music_title, p.likes_count, p.comments_count, p.shares_count,
  p.saves_count, p.views_count, p.created_at,
  pr.username, pr.full_name, pr.avatar_url,
  exists (select 1 from public.likes l
          where l.post_id = p.id and l.user_id = auth.uid()) as liked_by_me,
  exists (select 1 from public.bookmarks b
          where b.post_id = p.id and b.user_id = auth.uid()) as bookmarked_by_me
from public.posts p
join public.profiles pr on pr.id = p.user_id;

create view public.profile_stats with (security_invoker = true) as
select
  pr.id as profile_id,
  (select count(*) from public.posts p where p.user_id = pr.id)::int as posts_count,
  (select count(*) from public.follows f where f.following_id = pr.id)::int as followers_count,
  (select count(*) from public.follows f where f.follower_id = pr.id)::int as following_count
from public.profiles pr;

-- Active stories grouped per user: own + people I follow.
create view public.story_tray with (security_invoker = true) as
with active as (
  select
    s.user_id, s.is_live, s.created_at,
    not exists (select 1 from public.story_views v
                where v.story_id = s.id and v.viewer_id = auth.uid()) as unseen
  from public.stories s
  where s.expires_at > now()
    and (s.user_id = auth.uid()
         or s.user_id in (select f.following_id from public.follows f
                          where f.follower_id = auth.uid()))
)
select
  a.user_id,
  pr.username, pr.full_name, pr.avatar_url,
  bool_or(a.is_live) as is_live,
  bool_or(a.unseen) as has_unseen,
  max(a.created_at) as latest_at
from active a
join public.profiles pr on pr.id = a.user_id
group by a.user_id, pr.username, pr.full_name, pr.avatar_url
order by bool_or(a.is_live) desc, bool_or(a.unseen) desc, max(a.created_at) desc;

-- ---------------------------------------------------------------------------
-- RPCs: toggles are idempotent and race-safe (PK conflict instead of read-then-write)
-- ---------------------------------------------------------------------------
create function public.toggle_like(p_post_id uuid)
returns boolean language plpgsql set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_rows int;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  insert into public.likes (user_id, post_id) values (v_uid, p_post_id)
    on conflict do nothing;
  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    delete from public.likes where user_id = v_uid and post_id = p_post_id;
    return false;
  end if;
  return true;
end;
$$;

create function public.toggle_bookmark(p_post_id uuid)
returns boolean language plpgsql set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_rows int;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  insert into public.bookmarks (user_id, post_id) values (v_uid, p_post_id)
    on conflict do nothing;
  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    delete from public.bookmarks where user_id = v_uid and post_id = p_post_id;
    return false;
  end if;
  return true;
end;
$$;

create function public.toggle_comment_like(p_comment_id uuid)
returns boolean language plpgsql set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_rows int;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  insert into public.comment_likes (user_id, comment_id) values (v_uid, p_comment_id)
    on conflict do nothing;
  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    delete from public.comment_likes where user_id = v_uid and comment_id = p_comment_id;
    return false;
  end if;
  return true;
end;
$$;

create function public.toggle_follow(p_user_id uuid)
returns boolean language plpgsql set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_rows int;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  if v_uid = p_user_id then raise exception 'You cannot follow yourself'; end if;
  insert into public.follows (follower_id, following_id) values (v_uid, p_user_id)
    on conflict do nothing;
  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    delete from public.follows where follower_id = v_uid and following_id = p_user_id;
    return false;
  end if;
  return true;
end;
$$;

create function public.get_or_create_conversation(p_other uuid)
returns uuid language plpgsql set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_a uuid;
  v_b uuid;
  v_id uuid;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  if v_uid = p_other then raise exception 'Cannot start a chat with yourself'; end if;
  v_a := least(v_uid, p_other);
  v_b := greatest(v_uid, p_other);
  insert into public.conversations (user_a, user_b) values (v_a, v_b)
    on conflict (user_a, user_b) do nothing;
  select id into v_id from public.conversations where user_a = v_a and user_b = v_b;
  return v_id;
end;
$$;

create function public.inbox()
returns table (
  conversation_id uuid,
  other_user_id uuid,
  username text,
  full_name text,
  avatar_url text,
  last_message text,
  last_message_at timestamptz,
  last_sender_id uuid,
  unread boolean
)
language sql stable set search_path = '' as $$
  select
    c.id, o.id, o.username, o.full_name, o.avatar_url,
    lm.body, lm.created_at, lm.sender_id,
    exists (select 1 from public.messages m
            where m.conversation_id = c.id
              and m.sender_id <> auth.uid()
              and m.read_at is null)
  from public.conversations c
  join public.profiles o
    on o.id = case when c.user_a = auth.uid() then c.user_b else c.user_a end
  join lateral (
    select m.body, m.created_at, m.sender_id
    from public.messages m
    where m.conversation_id = c.id
    order by m.created_at desc
    limit 1
  ) lm on true
  where auth.uid() in (c.user_a, c.user_b)
  order by lm.created_at desc;
$$;

create function public.mark_conversation_read(p_conversation_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_conversation_member(p_conversation_id) then
    raise exception 'Not a member of this conversation';
  end if;
  update public.messages
  set read_at = now()
  where conversation_id = p_conversation_id
    and sender_id <> auth.uid()
    and read_at is null;
end;
$$;

create function public.increment_post_views(p_post_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  update public.posts set views_count = views_count + 1 where id = p_post_id;
end;
$$;

create function public.log_share(p_post_id uuid)
returns void language plpgsql set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  insert into public.shares (user_id, post_id) values (auth.uid(), p_post_id);
end;
$$;

-- RPCs are callable by signed-in users only; trigger functions by nobody directly.
do $$
declare fn text;
begin
  foreach fn in array array[
    'toggle_like(uuid)', 'toggle_bookmark(uuid)', 'toggle_comment_like(uuid)',
    'toggle_follow(uuid)', 'get_or_create_conversation(uuid)', 'inbox()',
    'mark_conversation_read(uuid)', 'increment_post_views(uuid)', 'log_share(uuid)',
    'is_conversation_member(uuid)'
  ] loop
    execute format('revoke execute on function public.%s from public, anon', fn);
    execute format('grant execute on function public.%s to authenticated', fn);
  end loop;

  foreach fn in array array[
    'handle_new_user()', 'sync_likes_count()', 'sync_saves_count()',
    'sync_shares_count()', 'sync_comments_count()', 'sync_comment_likes_count()',
    'enforce_single_level_reply()', 'touch_conversation()', 'notify_on_like()',
    'notify_on_comment()', 'notify_on_follow()'
  ] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', fn);
  end loop;
end;
$$;
