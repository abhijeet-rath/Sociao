-- Sociao seed data (DEV ONLY). 6 users, 14 posts, plus follows, likes,
-- comments, stories and chats. Safe to re-run: everything uses fixed ids and
-- "on conflict do nothing". Counters (likes/comments/saves) are produced by the
-- database triggers from the rows below; they are never hard-set.
--
-- Test login for every seeded user:  <email>  /  Password123!
--   gustavo.levin@sociao.test   marilyn.torff@sociao.test
--   lindsey.septimus@sociao.test livia.botosh@sociao.test
--   randy.vetrovs@sociao.test   ahmad.korsgaard@sociao.test

-- ---------------------------------------------------------------------------
-- Users (auth.users -> trigger creates profiles + user_settings)
-- ---------------------------------------------------------------------------
create temp table seed_users (
  id uuid, email text, full_name text, bio text, avatar_url text
) on commit drop;

insert into seed_users values
  ('00000000-0000-4000-8000-000000000001', 'gustavo.levin@sociao.test',     'Gustavo Levin',     'Dream big, work hard, stay focused, and surround yourself with good energy. 💪', 'https://i.pravatar.cc/300?img=12'),
  ('00000000-0000-4000-8000-000000000002', 'marilyn.torff@sociao.test',     'Marilyn Torff',     'Chasing sunsets and good light. 🌅',                                             'https://i.pravatar.cc/300?img=47'),
  ('00000000-0000-4000-8000-000000000003', 'lindsey.septimus@sociao.test',  'Lindsey Septimus',  'Food, travel and everything in between. 🍽️',                                    'https://i.pravatar.cc/300?img=32'),
  ('00000000-0000-4000-8000-000000000004', 'livia.botosh@sociao.test',      'Livia Botosh',      'Coffee first, opinions later. ☕',                                                'https://i.pravatar.cc/300?img=44'),
  ('00000000-0000-4000-8000-000000000005', 'randy.vetrovs@sociao.test',     'Randy Vetrovs',     'Designer. Dad jokes. Desk setups.',                                              'https://i.pravatar.cc/300?img=15'),
  ('00000000-0000-4000-8000-000000000006', 'ahmad.korsgaard@sociao.test',   'Ahmad Korsgaard',   'Tech news, gadgets and good vibes.',                                             'https://i.pravatar.cc/300?img=68');

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new
)
select
  '00000000-0000-0000-0000-000000000000', s.id, 'authenticated', 'authenticated',
  s.email, extensions.crypt('Password123!', extensions.gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  jsonb_build_object('full_name', s.full_name),
  now(), now(), '', '', '', ''
from seed_users s
on conflict (id) do nothing;

insert into auth.identities (
  id, user_id, provider_id, provider, identity_data,
  last_sign_in_at, created_at, updated_at
)
select
  gen_random_uuid(), s.id, s.id::text, 'email',
  jsonb_build_object('sub', s.id::text, 'email', s.email, 'email_verified', true),
  now(), now(), now()
from seed_users s
where not exists (
  select 1 from auth.identities i where i.user_id = s.id and i.provider = 'email'
);

update public.profiles p
set full_name = s.full_name, bio = s.bio,
    -- Keep an uploaded (Storage) avatar if there is one: external hosts such
    -- as pravatar block browser (web) requests via CORS.
    avatar_url = coalesce(p.avatar_url, s.avatar_url)
from seed_users s
where p.id = s.id;

-- ---------------------------------------------------------------------------
-- Posts: 4 text-only, 6 image, 4 video
-- ---------------------------------------------------------------------------
insert into public.posts
  (id, user_id, caption, media_type, media_url, thumbnail_url, music_title, views_count, created_at)
values
  -- text-only
  ('10000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000004', 'If Monday had a face, I would punch it. 😆', 'none', null, null, null, 0, now() - interval '2 minutes'),
  ('10000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000003', 'Happiness is a perfectly cooked meal. 🍽️😋', 'none', null, null, null, 0, now() - interval '9 minutes'),
  ('10000000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-000000000006', 'Hot take: the best feature of any phone is battery life. 🔋', 'none', null, null, null, 0, now() - interval '3 hours'),
  ('10000000-0000-4000-8000-000000000004', '00000000-0000-4000-8000-000000000001', 'Happiness is a perfectly cooked meal. 🍽️😋', 'none', null, null, null, 0, now() - interval '5 hours'),
  -- image
  ('10000000-0000-4000-8000-000000000005', '00000000-0000-4000-8000-000000000002', 'Just living life one sunset at a time. 🌇✨', 'image', 'https://picsum.photos/seed/sociao-sunset/1080/1080', null, null, 0, now() - interval '15 minutes'),
  ('10000000-0000-4000-8000-000000000006', '00000000-0000-4000-8000-000000000001', 'Dream big, work hard, stay focused, and surround yourself with good energy. 💪', 'image', 'https://picsum.photos/seed/sociao-desk/1080/1080', null, null, 0, now() - interval '40 minutes'),
  ('10000000-0000-4000-8000-000000000007', '00000000-0000-4000-8000-000000000005', 'New plant, new desk, new me. 🪴', 'image', 'https://picsum.photos/seed/sociao-plants/1080/1080', null, null, 0, now() - interval '1 hour'),
  ('10000000-0000-4000-8000-000000000008', '00000000-0000-4000-8000-000000000003', 'Sunday brunch done right.', 'image', 'https://picsum.photos/seed/sociao-brunch/1080/1080', null, null, 0, now() - interval '6 hours'),
  ('10000000-0000-4000-8000-000000000009', '00000000-0000-4000-8000-000000000004', 'Morning light hits different. ☀️', 'image', 'https://picsum.photos/seed/sociao-morning/1080/1080', null, null, 0, now() - interval '8 hours'),
  ('10000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000006', 'Unboxing day! 📦', 'image', 'https://picsum.photos/seed/sociao-unbox/1080/1080', null, null, 0, now() - interval '1 day'),
  -- video
  ('10000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000001', 'Dream big, work hard, stay focused, and surround yourself with good energy. 💪', 'video', 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4', 'https://picsum.photos/seed/sociao-vid1/720/1280', 'Benson Boone - Beautiful Things', 1450, now() - interval '20 minutes'),
  ('10000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000001', 'Studio setup tour. 🎬', 'video', 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4', 'https://picsum.photos/seed/sociao-vid2/720/1280', 'Lizzo - About Damn Time', 8450, now() - interval '2 days'),
  ('10000000-0000-4000-8000-000000000013', '00000000-0000-4000-8000-000000000002', 'Golden hour never gets old. 🌅', 'video', 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4', 'https://picsum.photos/seed/sociao-vid3/720/1280', 'Dua Lipa - Levitating', 3200, now() - interval '4 hours'),
  ('10000000-0000-4000-8000-000000000014', '00000000-0000-4000-8000-000000000005', 'Behind the scenes of today''s shoot.', 'video', 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4', 'https://picsum.photos/seed/sociao-vid4/720/1280', 'The Weeknd - Blinding Lights', 980, now() - interval '12 hours')
on conflict (id) do nothing;

-- Tags (Profile "Tag" tab): Gustavo is tagged in posts by others.
insert into public.post_tags (post_id, tagged_user_id) values
  ('10000000-0000-4000-8000-000000000013', '00000000-0000-4000-8000-000000000001'),
  ('10000000-0000-4000-8000-000000000014', '00000000-0000-4000-8000-000000000001'),
  ('10000000-0000-4000-8000-000000000007', '00000000-0000-4000-8000-000000000001'),
  ('10000000-0000-4000-8000-000000000005', '00000000-0000-4000-8000-000000000004')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Follows: Gustavo <-> everyone, plus a deterministic sprinkling between others
-- ---------------------------------------------------------------------------
insert into public.follows (follower_id, following_id)
select a.id, b.id
from public.profiles a
join public.profiles b on a.id <> b.id
where a.id in (select id from seed_users) and b.id in (select id from seed_users)
  and (a.id = '00000000-0000-4000-8000-000000000001'
    or b.id = '00000000-0000-4000-8000-000000000001'
    or abs(hashtext(a.id::text || b.id::text)) % 3 <> 0)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Likes / bookmarks / shares (deterministic pseudo-random spread)
-- ---------------------------------------------------------------------------
insert into public.likes (user_id, post_id)
select u.id, p.id
from seed_users u
cross join public.posts p
where p.id::text like '10000000-%'
  and abs(hashtext(u.id::text || p.id::text)) % 5 < 3
on conflict do nothing;

insert into public.bookmarks (user_id, post_id) values
  ('00000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000005'),
  ('00000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000013'),
  ('00000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000011'),
  ('00000000-0000-4000-8000-000000000005', '10000000-0000-4000-8000-000000000011')
on conflict do nothing;

insert into public.shares (user_id, post_id)
select u.id, '10000000-0000-4000-8000-000000000011'
from seed_users u
where u.id <> '00000000-0000-4000-8000-000000000001'
  and not exists (select 1 from public.shares s
                  where s.user_id = u.id and s.post_id = '10000000-0000-4000-8000-000000000011');

-- ---------------------------------------------------------------------------
-- Comments with one-level replies (on Gustavo's video post)
-- ---------------------------------------------------------------------------
insert into public.comments (id, post_id, user_id, parent_id, body, created_at) values
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000004', null, 'Dream big, work hard, stay focused, and surround yourself with good energy. 💪', now() - interval '18 minutes'),
  ('20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000005', null, 'Totally agree! Surrounding yourself with positive vibes is key! 🙌✨', now() - interval '16 minutes'),
  ('20000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000004', '20000000-0000-4000-8000-000000000002', 'That''s the winning formula right there! 🔥💯', now() - interval '14 minutes'),
  ('20000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000006', null, 'Dream big, stay focused, and never settle! Love this! 💪💫', now() - interval '10 minutes'),
  ('20000000-0000-4000-8000-000000000005', '10000000-0000-4000-8000-000000000005', '00000000-0000-4000-8000-000000000001', null, 'Stunning shot!', now() - interval '12 minutes'),
  ('20000000-0000-4000-8000-000000000006', '10000000-0000-4000-8000-000000000005', '00000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000005', 'Thank you! 🌇', now() - interval '11 minutes'),
  ('20000000-0000-4000-8000-000000000007', '10000000-0000-4000-8000-000000000006', '00000000-0000-4000-8000-000000000003', null, 'Love that desk setup.', now() - interval '30 minutes')
on conflict (id) do nothing;

insert into public.comment_likes (user_id, comment_id) values
  ('00000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000002'),
  ('00000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000002'),
  ('00000000-0000-4000-8000-000000000005', '20000000-0000-4000-8000-000000000003'),
  ('00000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000004'),
  ('00000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000004'),
  ('00000000-0000-4000-8000-000000000004', '20000000-0000-4000-8000-000000000004')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Stories (Marilyn is live; Gustavo has already viewed Randy's)
-- ---------------------------------------------------------------------------
insert into public.stories (id, user_id, media_url, media_type, is_live, created_at) values
  ('40000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000002', 'https://picsum.photos/seed/sociao-story1/720/1280', 'image', true,  now() - interval '5 minutes'),
  ('40000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000005', 'https://picsum.photos/seed/sociao-story2/720/1280', 'image', false, now() - interval '1 hour'),
  ('40000000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-000000000006', 'https://picsum.photos/seed/sociao-story3/720/1280', 'image', false, now() - interval '2 hours'),
  ('40000000-0000-4000-8000-000000000004', '00000000-0000-4000-8000-000000000004', 'https://picsum.photos/seed/sociao-story4/720/1280', 'image', false, now() - interval '3 hours'),
  ('40000000-0000-4000-8000-000000000005', '00000000-0000-4000-8000-000000000003', 'https://picsum.photos/seed/sociao-story5/720/1280', 'image', false, now() - interval '4 hours')
on conflict (id) do nothing;

insert into public.story_views (story_id, viewer_id) values
  ('40000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Chats with Gustavo. user_a must be the smaller uuid.
-- ---------------------------------------------------------------------------
insert into public.conversations (id, user_a, user_b) values
  ('50000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000006'),
  ('50000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000005'),
  ('50000000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000004')
on conflict (id) do nothing;

insert into public.messages (id, conversation_id, sender_id, body, read_at, created_at) values
  -- Ahmad: last message is unread by Gustavo
  ('60000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000006', 'Hey!', now() - interval '20 minutes', now() - interval '12 minutes'),
  ('60000000-0000-4000-8000-000000000002', '50000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000006', 'Did you hear about the new AI-powered phone that just came out?', now() - interval '20 minutes', now() - interval '11 minutes'),
  ('60000000-0000-4000-8000-000000000003', '50000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'Yeah, I saw that! It''s supposed to have crazy good battery life and that AI camera feature. Have you tried it yet?', now() - interval '9 minutes', now() - interval '8 minutes'),
  ('60000000-0000-4000-8000-000000000004', '50000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000006', 'Not yet, but I''m really tempted. They say it learns your habits and adjusts the settings automatically. Sounds pretty cool, right?', now() - interval '7 minutes', now() - interval '6 minutes'),
  ('60000000-0000-4000-8000-000000000005', '50000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'Totally! I''m just curious if all the hype is real.', now() - interval '4 minutes', now() - interval '3 minutes'),
  ('60000000-0000-4000-8000-000000000006', '50000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000006', 'Thank you!', null, now() - interval '3 minutes'),
  -- Randy
  ('60000000-0000-4000-8000-000000000007', '50000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'Did you finish the mockups?', now() - interval '1 hour', now() - interval '2 hours'),
  ('60000000-0000-4000-8000-000000000008', '50000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000005', 'Not yet', now() - interval '1 hour', now() - interval '3 minutes'),
  -- Livia
  ('60000000-0000-4000-8000-000000000009', '50000000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-000000000004', 'Did you hear about the new AI-powered phone...', now() - interval '1 hour', now() - interval '3 minutes')
on conflict (id) do nothing;

-- Heart reaction on Gustavo's message to Ahmad.
insert into public.message_reactions (message_id, user_id) values
  ('60000000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-000000000006')
on conflict do nothing;
