# CLAUDE.md — Sociao Development Guide

Sociao is a mobile-first social media app. **Frontend: Flutter (Dart). Backend: Supabase only** (Auth, Postgres, Storage, Realtime). Do not introduce any other frontend framework or backend (no Firebase, no custom Node/Python server, no REST wrapper).

> Read this file fully before writing code. Follow the phase order in §14. Tick the checklist in §15 as you finish items. Reference screens live in `reference/` (see §10).

---

## 1. Project state & ground rules

- Project exists as a fresh Flutter template (`lib/main.dart` is still the counter demo). `supabase_flutter` and `material_ui` are already in `pubspec.yaml`. Dart SDK `^3.14.0`, Flutter 3.50.
- **UI imports:** this project uses the `material_ui` package (the template imports `package:material_ui/material_ui.dart`). Keep that import style; do not swap it without telling the user.
- **Never hard-code app content** (users, posts, captions, counts, avatars). All content comes from Supabase. The only allowed static data is DB seed data (`supabase/seed.sql`) and UI labels/strings.
- **No secrets in the app or repo.** See §6.
- Do not add features, packages or abstractions beyond this document without asking. Prefer the simplest thing that works.
- Do not commit unless asked. Never commit `env.json`.

---

## 2. Architecture

Feature-first, three layers per feature, unidirectional data flow:

```
UI (screens/widgets)  →  Riverpod providers (state)  →  Repositories  →  Supabase client
```

- **Screens/widgets** only read providers and render; no Supabase calls in widgets.
- **Providers** (`flutter_riverpod`) hold async state (`AsyncValue`) and expose actions (toggleLike, sendMessage…).
- **Repositories** are the only code that touches `Supabase.instance.client`. One repository per feature, injected via a provider (so tests can override it).
- **Models** are immutable Dart classes with `fromJson` / `toJson` (hand-written, no codegen) and `copyWith`.
- Errors: repositories throw `AppException(message)`; providers surface them as `AsyncError`; UI shows an error state with Retry.

---

## 3. Dependencies

Add with `flutter pub add <pkg>` so versions resolve to current. Keep the list tight.

| Package | Purpose |
|---|---|
| `supabase_flutter` (already present) | Auth, DB, Storage, Realtime |
| `flutter_riverpod` | State management |
| `go_router` | Navigation + auth redirects |
| `cached_network_image` | Avatars / post images |
| `video_player` | Video viewer, video tiles |
| `image_picker` | Pick images/videos for posts, stories, avatar |
| `share_plus` | Share action |
| `intl` | Date/number formatting |
| `timeago` | "2m ago", "3 min ago" labels |
| `shared_preferences` | Local theme + language preference |
| `url_launcher` | Open profile website / help link |
| `skeletonizer` (or `shimmer`) | Loading skeletons |
| dev: `mocktail`, `flutter_lints` (present) | Tests / lint |

Font: **Manrope** (matches the references) via bundled font assets under `assets/fonts/` (preferred, offline-safe) or `google_fonts`.

---

## 4. Folder structure

```
lib/
  main.dart                  # init Supabase, ProviderScope, runApp
  app.dart                   # MaterialApp.router, theme, router
  core/
    config/env.dart          # reads --dart-define values
    supabase/supabase_client.dart
    router/app_router.dart   # go_router + auth redirect
    theme/                   # app_colors.dart, app_text_styles.dart, app_theme.dart (light+dark)
    widgets/                 # shared: AppButton, AppTextField, UserAvatar, PillStat, EmptyState, ErrorState, LoadingSkeleton, SectionHeader
    utils/                   # validators.dart, formatters.dart (12,8k / 1,450), result/AppException
  features/
    auth/        {data, domain, presentation}
    feed/        # home feed, stories, post card, post options
    video/       # video viewer
    comments/    # bottom sheet
    messages/    # inbox, chat
    profile/     # profile, edit profile, followers/following
    create/      # create post / story
    settings/
    notifications/
    shell/       # bottom-nav scaffold
  # each feature: data/ (repository, dto), domain/ (models), presentation/ (screens, widgets, providers)
supabase/
  config.toml
  migrations/                # timestamped .sql files (schema, RLS, storage, realtime)
  seed.sql
env.example.json             # committed, placeholder values only
env.json                     # git-ignored, real values
reference/                   # UI reference screenshots (read-only)
test/                        # mirrors lib/
```

---

## 5. Supabase integration

Init in `main.dart` before `runApp`:

```dart
await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabasePublishableKey); // `anonKey` is deprecated
```

- Access the client through one provider (`supabaseClientProvider`); repositories receive it by constructor.
- **Auth:** `auth.signUp(email, password, data: {'full_name': ...})`, `signInWithPassword`, `signOut`. Session persistence is handled by `supabase_flutter`. Router listens to `onAuthStateChange` (via a provider) to redirect.
- **DB reads:** use PostgREST with explicit column lists and joins, e.g. `from('post_feed').select().order('created_at', ascending: false).range(from, to)`. Paginate (20 per page).
- **Writes that must be atomic/safe** (like toggle, follow, create conversation) use RPC functions or plain insert/delete guarded by constraints — never read-then-write in Dart.
- **Realtime:** subscribe to `messages` (per conversation), `message_reactions`, and `notifications`; unsubscribe in provider `onDispose`. Feed does not need realtime — refresh on pull-to-refresh.
- **Storage:** upload via `storage.from(bucket).upload('$uid/${uuid}.ext', file)`, then store the **path/public URL** in the row.

### 5.1 Database schema (migration `0001_schema.sql`)

Use `snake_case`, `uuid` PKs (`gen_random_uuid()`), `timestamptz default now()`.

```sql
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9._]{3,30}$'),
  full_name text not null default '',
  avatar_url text,
  bio text default '' check (char_length(bio) <= 200),
  website text,
  created_at timestamptz not null default now()
);

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  caption text not null default '' check (char_length(caption) <= 2200),
  media_type text not null default 'none' check (media_type in ('none','image','video')),
  media_url text,
  thumbnail_url text,
  music_title text,                       -- "Benson Boone - Beautiful Things"
  likes_count int not null default 0,
  comments_count int not null default 0,
  shares_count int not null default 0,
  saves_count int not null default 0,
  views_count int not null default 0,     -- shown on profile Video grid
  created_at timestamptz not null default now(),
  check ((media_type = 'none') = (media_url is null))
);
create index posts_user_created_idx on public.posts (user_id, created_at desc);
create index posts_created_idx on public.posts (created_at desc);
create index posts_video_idx on public.posts (created_at desc) where media_type = 'video';

create table public.post_tags (            -- Profile "Tag" tab: posts the user is tagged in
  post_id uuid references public.posts(id) on delete cascade,
  tagged_user_id uuid references public.profiles(id) on delete cascade,
  primary key (post_id, tagged_user_id)
);
create index post_tags_user_idx on public.post_tags (tagged_user_id);

create table public.likes (
  user_id uuid references public.profiles(id) on delete cascade,
  post_id uuid references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)           -- prevents duplicate likes
);
create index likes_post_idx on public.likes (post_id);

create table public.bookmarks (
  user_id uuid references public.profiles(id) on delete cascade,
  post_id uuid references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create table public.shares (               -- log of share taps, drives shares_count
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  parent_id uuid references public.comments(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  likes_count int not null default 0,
  created_at timestamptz not null default now()
);
create index comments_post_idx on public.comments (post_id, created_at);
create index comments_parent_idx on public.comments (parent_id);
-- One-level replies: trigger rejects insert when parent's own parent_id is not null.

create table public.comment_likes (
  user_id uuid references public.profiles(id) on delete cascade,
  comment_id uuid references public.comments(id) on delete cascade,
  primary key (user_id, comment_id)
);

create table public.stories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  media_url text not null,
  media_type text not null default 'image' check (media_type in ('image','video')),
  is_live boolean not null default false,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours'
);
create index stories_active_idx on public.stories (user_id, expires_at desc);

create table public.story_views (          -- drives ring colour (unseen vs seen)
  story_id uuid references public.stories(id) on delete cascade,
  viewer_id uuid references public.profiles(id) on delete cascade,
  primary key (story_id, viewer_id)
);

create table public.follows (
  follower_id uuid references public.profiles(id) on delete cascade,
  following_id uuid references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);
create index follows_following_idx on public.follows (following_id);

create table public.conversations (        -- 1:1 chats; user_a < user_b guarantees one row per pair
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references public.profiles(id) on delete cascade,
  user_b uuid not null references public.profiles(id) on delete cascade,
  last_message_at timestamptz not null default now(),
  unique (user_a, user_b),
  check (user_a < user_b)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  read_at timestamptz,                     -- null = unread by recipient (blue dot in inbox)
  created_at timestamptz not null default now()
);
create index messages_conv_created_idx on public.messages (conversation_id, created_at desc);

create table public.message_reactions (    -- heart reaction with count
  message_id uuid references public.messages(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  emoji text not null default '❤️',
  primary key (message_id, user_id)
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,   -- recipient
  actor_id uuid references public.profiles(id) on delete cascade,
  type text not null check (type in ('like','comment','follow','message')),
  post_id uuid references public.posts(id) on delete cascade,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);

create table public.user_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  theme text not null default 'light' check (theme in ('light','dark','system')),
  notifications_enabled boolean not null default true,
  language text not null default 'en'
);
```

### 5.2 Triggers, views and RPCs (migration `0002_functions.sql`)

- `handle_new_user()` — `security definer` trigger on `auth.users` insert: creates `profiles` (username derived from email local-part + uniqueness suffix, `full_name` from `raw_user_meta_data`) and a `user_settings` row.
- **Counter triggers** (`security definer`, `set search_path = ''`): maintain `posts.likes_count` (on `likes`), `comments_count` (on `comments`, top-level + replies), `saves_count` (on `bookmarks`), `shares_count` (on `shares`), `comments.likes_count` (on `comment_likes`). Counts therefore stay accurate across refreshes and are never computed in Dart.
- `enforce_single_level_reply()` — before insert on `comments`.
- `touch_conversation()` — after insert on `messages`: updates `conversations.last_message_at`.
- `notify_on_like/comment/follow()` — insert into `notifications` (skip self-actions).
- **View `post_feed`** (`with (security_invoker = true)`): post columns + author `username, full_name, avatar_url` + `liked_by_me` and `bookmarked_by_me` via `exists(... where user_id = auth.uid())`. Feed, profile Posts tab, video viewer all read this view.
- **View `profile_stats`** (security_invoker): `profile_id, posts_count, followers_count, following_count`.
- **View `story_tray`**: active stories (`expires_at > now()`) grouped per user with `has_unseen`, `is_live`, ordered live → unseen → seen. Current user's "Add Story" tile is a UI element, not a row.
- **RPC `toggle_like(p_post_id uuid) returns boolean`**: inserts `likes` row `on conflict do nothing`; if nothing inserted, deletes it. Returns new liked state. Same pattern for `toggle_bookmark`, `toggle_comment_like`, `toggle_follow`.
- **RPC `get_or_create_conversation(p_other uuid) returns uuid`**: orders the pair so `user_a < user_b`.
- **RPC `inbox()`**: per conversation — other user's profile, last message body/time, `unread` (exists message from other with `read_at is null`).
- **RPC `mark_conversation_read(p_conversation_id uuid)`** and **`increment_post_views(p_post_id uuid)`**, **`log_share(p_post_id uuid)`**.

All RPCs use `security invoker` unless they must bypass RLS for counters (then `security definer` with `set search_path = ''` and an explicit `auth.uid()` check).

### 5.3 Row Level Security (migration `0003_rls.sql`)

**Enable RLS on every table in `public`.** Default is deny; add only these policies (`auth.uid()` = current user):

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| profiles | any authenticated | (trigger only) | `id = auth.uid()` | — |
| posts | any authenticated | `user_id = auth.uid()` | owner | owner |
| post_tags | authenticated | owner of the post | — | post owner |
| likes / bookmarks / comment_likes | authenticated (likes), own rows only (bookmarks) | `user_id = auth.uid()` | — | `user_id = auth.uid()` |
| shares | own | `user_id = auth.uid()` | — | — |
| comments | authenticated | `user_id = auth.uid()` | owner (body) | owner or post owner |
| stories | authenticated where `expires_at > now()` or owner | owner | owner | owner |
| story_views | own | `viewer_id = auth.uid()` | — | — |
| follows | authenticated | `follower_id = auth.uid()` | — | `follower_id = auth.uid()` **or** `following_id = auth.uid()` (supports "Remove follower") |
| conversations | `auth.uid() in (user_a, user_b)` | via RPC; `auth.uid() in (user_a, user_b)` | — | — |
| messages | participant of the conversation | `sender_id = auth.uid()` **and** participant | recipient may set `read_at` only (use RPC) | sender |
| message_reactions | participant of the message's conversation | `user_id = auth.uid()` + participant | — | `user_id = auth.uid()` |
| notifications | `user_id = auth.uid()` | (triggers only) | `user_id = auth.uid()` | `user_id = auth.uid()` |
| user_settings | own | own | own | — |

**Table grants are required too.** This project does not auto-grant new `public` tables to `authenticated`, so RLS alone gives "permission denied". Migration `20260101000006_grants.sql` grants least-privilege per table and `select` on the views; `anon` gets nothing. **Every new table/view needs a matching `grant` in its migration.**

Write participant checks as a `security definer` helper `is_conversation_member(conv_id uuid)` to avoid recursive policy lookups. Test each policy with two different users (§13).

### 5.4 Storage (migration `0004_storage.sql`)

Buckets and layout — object path always starts with the owner's uid so policies can check `(storage.foldername(name))[1] = auth.uid()::text`:

| Bucket | Public read | Path | Limits |
|---|---|---|---|
| `avatars` | yes | `{uid}/avatar.jpg` (upsert) | images ≤ 2 MB |
| `posts` | yes | `{uid}/{postId}/image.jpg`, `{uid}/{postId}/thumb.jpg` | images ≤ 10 MB |
| `videos` | yes | `{uid}/{postId}/video.mp4` | video ≤ 100 MB |
| `stories` | yes | `{uid}/{storyId}.jpg\|mp4` | ≤ 50 MB |

Policies per bucket: public `select`; `insert/update/delete` only when the first folder equals `auth.uid()`. Set `allowed_mime_types` and `file_size_limit` on each bucket. Store the public URL (or path + helper `publicUrl`) in the DB row.

### 5.5 Realtime (migration `0005_realtime.sql`)

```sql
alter publication supabase_realtime add table public.messages, public.message_reactions, public.notifications;
```

Realtime respects RLS, so users only receive rows they can select.

---

## 6. Environment & key safety

| Key | Where it lives | Use |
|---|---|---|
| **Project URL** | `env.json` | Public, fine in app |
| **Publishable key** (`sb_publishable_…`, legacy name *anon key*) | `env.json` → app | Safe in the client **because RLS protects data**. This is the only key the Flutter app may use. |
| **Secret key** (`sb_secret_…`, legacy name *service_role key*) | **Never in the app, never in the repo.** Only in your shell/CI secrets for admin scripts | Bypasses RLS entirely. |

Rules:
1. The Flutter app, `env.json`, `env.example.json`, tests and docs must **never** contain the secret/service-role key.
2. `env.json` is git-ignored — add `env.json` to `.gitignore` (existing `.env*` rule does not cover it). Commit `env.example.json`:
   ```json
   { "SUPABASE_URL": "https://YOUR-PROJECT.supabase.co", "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_xxx" }
   ```
3. `Env` reads values with `String.fromEnvironment('SUPABASE_URL')` and throws a clear error on startup if empty.
4. If a secret key is ever pasted into chat, a commit or the app, tell the user to **rotate it immediately** in the Supabase dashboard.
5. Seeding/migrations run through the Supabase CLI or SQL editor (authenticated as the project owner) — not through app code.

---

## 7. Supabase project configuration

1. Create a project at supabase.com (or use local: `supabase start`, needs Docker).
2. Dashboard → **Authentication → Providers**: Email enabled. For development, disable "Confirm email" so seeded/new users can log in immediately (re-enable for production). Set password minimum length to 8.
3. Dashboard → **Settings → API**: copy Project URL and **publishable** key into `env.json`.
4. Install the Supabase CLI, then:
   ```bash
   supabase login
   supabase init                      # once; creates supabase/config.toml
   supabase link --project-ref <ref>  # remote project
   supabase db push                   # applies supabase/migrations/*.sql
   ```
5. Local alternative: `supabase start` then `supabase db reset` (applies migrations **and** `seed.sql`).
6. Create storage buckets in migration `0004` (insert into `storage.buckets`) so they are reproducible, not clicked by hand.

---

## 8. Seed data (`supabase/seed.sql`)

Requirements: **≥ 5 users, ≥ 10 posts** (aim for 6 users, 14 posts: mix of text-only, image and video), plus follows, likes, comments (incl. replies), 4+ stories (one `is_live`), a few conversations/messages (with unread + heart reaction), and tags.

- Insert users into `auth.users` (with `crypt('Password123!', gen_salt('bf'))`, `email_confirmed_at = now()`, matching `auth.identities` rows) using fixed UUIDs; the `handle_new_user` trigger creates profiles, then `update` them with username/name/bio. Document the test credentials in `supabase/README.md` (dev-only passwords).
- Seed usernames/names should follow the references (e.g. `gustavo.levin`, `marilyn.torff`, `lindsey.septimus`, `livia.botosh`, `randy.vetrovs`, `ahmad.korsgaard`).
- Media: seed rows may point to stable placeholder image/video URLs, or to files uploaded to the buckets by a `supabase/seed_media/` upload step. Counters are produced by triggers from the seeded `likes`/`comments` rows — do not hard-set counts.
- Run: remote → paste into SQL editor or `psql < seed.sql`; local → `supabase db reset`.
- Seed is idempotent-by-reset; never run it against production.

---

## 9. State management & navigation

**State: Riverpod** (`flutter_riverpod`).
- `AsyncNotifier`/`FutureProvider` for lists and detail; `StreamProvider` for realtime chat/notification badges; `family` providers keyed by id (`postCommentsProvider(postId)`, `chatProvider(conversationId)`).
- Auth state: `authStateProvider` (stream of `AuthState`) → `currentUserProvider`.
- **Likes/bookmarks use optimistic updates:** flip local state and count immediately, call the RPC, reconcile with returned state, and roll back + show a snackbar on error. The DB is the source of truth; after refresh counts must match.
- Pagination: simple page index + `loadMore()` in the notifier.
- Local-only prefs (theme mode, language) in `shared_preferences`, mirrored to `user_settings` when logged in.

**Navigation: `go_router`.**
- `StatefulShellRoute.indexedStack` with 5 branches for the bottom bar: `/home`, `/video`, *(Create is an action, not a tab)*, `/inbox`, `/profile`.
- `redirect`: unauthenticated → `/login` (allow `/login`, `/signup`); authenticated on auth routes → `/home`. Refresh on auth stream via `refreshListenable`.
- Routes: `/login`, `/signup`, `/home`, `/video` (+ `/video/:postId`), `/inbox`, `/chat/:conversationId`, `/profile`, `/profile/:userId`, `/profile/edit`, `/profile/:userId/followers`, `/profile/:userId/following`, `/create`, `/settings`, `/notifications`.
- Comments = modal bottom sheet (`showModalBottomSheet`, `isScrollControlled`, draggable, rounded top), not a route.
- Create (+) opens `/create` full-screen (post vs story choice inside).

---

## 10. UI guidelines (derived from `reference/`)

Match these screens closely: `Screen_01_Login` … `Screen_13_Following` (iPhone portrait, light theme). Dark theme is selectable in Settings and must also work.

**Design tokens** (put in `core/theme`, never inline):
- Background `#FAFAFA`; surface/card white with 1px light-grey border (`~#EDEDED`) and large radius (cards ≈ 24, inputs/buttons fully pill ≈ 28+, small chips pill).
- Primary/ink `#171717` (dark pill buttons, outgoing chat bubbles, selected nav, Add Story circle). Secondary text grey `#8A8A8A`. Link/accent blue `~#2F55D4` (links, "Message" buttons, unread dot, unseen-story ring). Like red `~#E53935`.
- Font Manrope; titles 24–28 medium, body 15–16, meta 13 grey.
- Generous spacing, 16–20 px horizontal page padding, soft pills, no heavy shadows (bottom-nav Create button has a soft shadow).
- Circular icon buttons (grey `#F2F2F2` fill, ~44px) for bell, chat, settings, search, "…", back actions.

**Screens**

1. **Login (01)** — Title "Welcome Back!", subtitle, `Email` field (hint `name@gmail.com`), `Password` field with show/hide eye, full-width pill **Login** button that is **greyed/disabled until email and password are valid**, footer link, Terms/Privacy text. *Reference has typos to correct:* label reads "Create Password" → use **"Password"**; link reads "New here? Sign in" → use **"New here? Sign up"** (goes to Create Account).
2. **Create Account (02)** — "Create Account", `Full Name`, `Email`, `Password` (eye toggle), disabled-until-valid **Create Account** pill, "Already have an account? **Log in**", Terms/Privacy text.
   - Validation: email regex; password ≥ 8 chars with a letter and a number; name non-empty. Show inline errors on blur/submit. Map Supabase errors (invalid credentials, already registered) to friendly messages.
3. **Home Feed (03)** — Header: title "Social" left; circular **bell** (notifications) and **chat** (→ Inbox) buttons right. **Stories row** (horizontal): first tile **Add Story** (dark circle with +), then followed users' stories: avatar with coloured ring (blue = unseen; red + small "Live" pill badge = live), name beneath. Below, vertical list of **post cards**: avatar, username, relative time, "…" options button; caption text; optional rounded image/video (video shows play affordance); action row of pills — **Like** (heart + count; filled red when liked), **Comment** (count → opens comments sheet), **Share** (count), and **Bookmark** icon button on the far right. Tapping a video post opens the Video Viewer. Pull-to-refresh, infinite scroll.
   - Post "…" menu (bottom sheet): owner → Delete; others → Copy link, Report (stub), Unfollow.
4. **Video Viewer (04)** — Full-screen, immersive, black bg. Top-left **✕** + title "Video". Vertical `PageView` of video posts. Right rail of circular translucent buttons with counts: **Like** (heart), **Comment**, **Share**, **Save**. Bottom-left overlay: creator avatar + name, caption, music chip (♪ + `music_title`). Tap to pause/play; autoplay current, dispose others. Only `media_type = 'video'` posts. Increment `views_count` once per open.
5. **Comments (05)** — Draggable bottom sheet over the dimmed video, rounded top, drag handle, header "**N Comments**". Each comment: avatar, name, relative time, text, then pills **♥ count** (like toggle) and **Reply**. **Replies are one level only**, indented with a vertical connector line under the parent; replies show Like/Reply too, but replying to a reply attaches to the same parent. Bottom input: black circular **+** on the left, pill text field "Comment…". Empty state: "No comments yet — start the conversation."
6. **Messages Inbox (06)** — Title "Messages" + circular settings button. List rows: avatar, name, last-message preview (single-line ellipsis), time "3 min ago" top-right; **unread**: darker preview and blue dot, subtle highlighted row background. Divider between rows. Empty state with a "Start a chat" hint.
7. **Chat (09)** — App bar: ← back, contact name, circular **video-call** and **phone** icon buttons (UI-only placeholders → "Coming soon" snackbar). Grey background. Incoming: white rounded bubble with small avatar (shown on first bubble of a group). Outgoing: dark `#171717` bubble, white text, right-aligned. Timestamp ("3 min ago") sits beside the bubble. **Heart reaction** chip (♥ + count) under a bubble; double-tap or long-press a bubble toggles it. Composer: black **+** circle (attachment placeholder), pill field "Message…", waveform icon at right (voice placeholder) which swaps to a **send** icon when text is present. Realtime via Supabase; auto-scroll to newest; mark read on open.
8. **Profile (07, 08)** — Title "Profile" + circular settings button. Header card: avatar, display name, `@username` grey, bio, (website link if set). Three stat tiles in this order: **Following**, **Followers**, **Posts** (numbers formatted `490`, `12,8k`; tiles for Following/Followers navigate to lists). Segmented pill tabs with icons: **Post** | **Video** | **Tag**. Post tab = list of post cards (same card as feed, compact). Video tab = 2-column grid of rounded video thumbnails with an **eye + views_count** chip bottom-left; tap → Video Viewer. Tag tab = posts the user is tagged in (grid). Own profile shows settings; other users' profiles show Follow/Unfollow + Message instead.
9. **Edit Profile (10)** — "‹ Back" + centered title. Circular avatar with small white **pencil** badge (opens image picker → uploads to `avatars`). Fields: `Name`, `Username` (shown with `@` prefix; validate pattern + uniqueness), `Bio` (multiline), `Link` row with globe icon + "Website" + URL field. Save action (button/app-bar) with loading state.
10. **Settings (11)** — Title "Settings". Rows (grey circular icon, label, chevron): **Edit Profile**; section *Preferences*: **Notifications** (→ toggle screen/sheet), **Dark Mode** (inline dropdown: Light / Dark / System); section *Resources*: **Setting** (general/account stub), **Help & Support** (opens help URL/stub page), **Languages** (inline dropdown, English default; at least English + one more or UI-ready), **Sign Out** (confirm dialog → `signOut` → `/login`).
11. **Followers / Following (12, 13)** — "‹ Back", centered title, circular **search** button (toggles an inline search field filtering by name/username). Rows: avatar, name, `@username` grey, divider. Followers right action: **Message** (blue outline pill) if I follow them back / mutual, otherwise **Remove** (text button → removes follower via delete on `follows`). Following right action: **Message** pill (long-press or overflow to unfollow). Message creates/opens the conversation.
12. **Bottom navigation (03, 06, 07)** — Floating-style bar: **Home**, **Video**, centered dark pill **+** (Create), **Inbox**, **Profile**. Selected item = filled icon + bold label in ink; unselected = outline + grey label. Hidden on Video viewer, Chat, Edit Profile, Settings, Followers/Following. Inbox shows an unread badge from realtime.
13. **Create Post** (no reference screen — designed to match the others; same tokens, Manrope, pill shapes, `#FAFAFA` background):
    - Top bar like Edit Profile: "‹ Back" left, centered title "Create", dark pill **Post** button right (disabled until caption or media exists; shows progress while uploading).
    - Segmented pill switch at top, same style as the Profile tabs: **Post** | **Story**.
    - Post mode: white rounded card containing author avatar + name, multiline caption field ("What's on your mind?", counter at 2200), media preview (rounded 24, with ✕ remove button, video shows play icon) or a dashed-border picker area with two pill buttons **Photo** / **Video** (`image_picker`; gallery + camera).
    - Below the card, grey circular-icon rows (same style as Settings rows): **Tag people** (opens searchable followers/following sheet, saves to `post_tags`) and **Add music** (text field → `music_title`, video posts only).
    - Story mode: full-width media picker (image/video), preview, **Share to story** button; uploads to `stories` bucket; optional "Go live" toggle is out of scope (`is_live` is seed-only).
    - Upload flow: generate post id client-side → upload media to storage → insert row → pop back to Home and refresh feed. On failure keep the form state and show an error snackbar with Retry.
    - Entry points: centered **+** in the bottom nav, and the **Add Story** tile (opens directly in Story mode).

**Responsive & polish**
- Use `SafeArea`, `LayoutBuilder`/`MediaQuery`, flexible widgets; never fixed pixel heights for text containers. Verify small phone (360×640) and large/tablet-ish widths (constrain content to max ~600 wide, centered).
- Every async screen has **loading** (skeleton), **empty** (icon + message + action), and **error** (message + Retry) states via shared widgets.
- Images: `cached_network_image` with placeholder + error fallback; avatar fallback = initials.
- Buttons show progress and disable while submitting (prevent double taps). Keyboard-aware screens; tap-outside dismisses keyboard.
- Accessibility: min 44×44 tap targets, `Semantics`/tooltips on icon buttons, text contrast ≥ 4.5:1.

---

## 11. Coding standards

- `flutter analyze` must be clean; follow `flutter_lints`. Format with `dart format .`.
- Files `snake_case.dart`; classes `PascalCase`; one primary widget per file; widgets < ~150 lines — extract subwidgets (`const` constructors wherever possible).
- No business logic or Supabase calls in widgets. No `print` (use `debugPrint` sparingly, remove before finishing).
- Colors/text styles/spacing only from theme tokens. Strings centralised (ready for localisation); no magic numbers.
- Prefer `final`, immutability, null-safety; no `dynamic` leaking out of repositories (parse to models).
- Always dispose controllers, subscriptions, video controllers, realtime channels.
- `async` gaps: check `context.mounted` before using `BuildContext`.
- Use SQL migrations for every schema change — never alter the DB by hand without a migration file.
- Small, focused commits when asked to commit; conventional messages.

---

## 12. Commands

```bash
flutter pub get
flutter analyze
dart format .
flutter test
flutter run --dart-define-from-file=env.json                 # picks default device
flutter run -d chrome --dart-define-from-file=env.json
flutter run -d windows --dart-define-from-file=env.json
flutter build apk --dart-define-from-file=env.json
```

Supabase CLI is run as `npx supabase ...` (not installed globally). Project ref `msixwhfpvemwgcktsvuv` is linked. The CLI targets a **local** DB by default, so always pass `--remote` (e.g. `npx supabase db push --remote`, `npx supabase db query --remote --read-only "<sql>"`, seed: `npx supabase db query --remote --yes -f supabase/seed.sql` — only with the user's go-ahead, it writes to the live project).

Supabase: `supabase start | stop | status`, `supabase db reset` (local migrate+seed), `supabase db push` (remote migrate), `supabase migration new <name>`, `supabase gen types` is **not** needed (models are hand-written).

Platform notes: Android needs `INTERNET` (present by default in debug) plus camera/storage permissions for `image_picker`; iOS needs `NSPhotoLibraryUsageDescription` / `NSCameraUsageDescription` in `Info.plist`; Android `minSdk` per `supabase_flutter`/`video_player` requirements.

---

## 13. Testing

- **Unit:** validators, formatters (`12,8k`, `1,450`), models `fromJson`, notifier logic with a mocked repository (`mocktail`) — especially optimistic like + rollback.
- **Widget:** login/signup form validation (button disabled until valid, eye toggle), post card (liked state, counts), comments sheet (reply indentation), empty/error states.
- **Backend/RLS (manual SQL or pgTAP in `supabase/tests`):** with two users verify — cannot insert a like for another user; duplicate like is rejected (PK) / `toggle_like` is idempotent; cannot read others' bookmarks/notifications; cannot read/post messages in conversations you're not in; cannot update another user's profile/post; storage upload to another user's folder fails; replies to replies are rejected.
- **Persistence check:** like a post → kill/restart app → count and heart state are unchanged; second device sees the same count.
- **Manual smoke test per phase:** run on at least one Android emulator/device and Chrome; test airplane-mode error state.
- Definition of done for a feature: `flutter analyze` clean, tests added/passing, loading/empty/error states present, matches reference screen, checklist ticked.

---

## 14. Implementation phases

Work strictly in order; finish and verify each before the next. After each phase, summarise what was done and wait for the user's go-ahead if anything is ambiguous.

**Phase 0 — Foundation:** remove counter demo; add dependencies; `env.json` + `Env`; Supabase init; theme (light/dark tokens, Manrope); shared widgets; `go_router` shell with 5-item bottom bar and placeholder pages; `.gitignore` update.

**Phase 1 — Supabase, Auth, DB, seed, Home Feed (with persistent likes):**
migrations 0001–0005 (schema, functions/views, RLS, storage, realtime) → `seed.sql` (≥5 users, ≥10 posts) → Login & Create Account with validation/show-hide → protected routes + logout → Home Feed: stories row (Add Story, Live, seen/unseen), post cards from `post_feed`, **like/unlike via `toggle_like`** with optimistic UI, bookmark, share (`share_plus` + `log_share`), post options, pull-to-refresh/pagination, loading/empty/error states, bell and chat header buttons.

**Phase 2 — User Profile:** real profile data + `profile_stats`; Post / Video / Tag tabs; own vs other-user profile; follow/unfollow.

**Phase 3 — Video Viewer & Comments:** full-screen vertical video pager with actions and creator/caption/music; comments bottom sheet with one-level replies, comment likes, comment input, live count.

**Phase 4 — Messages & Chat:** `inbox()` list with unread dots; chat screen with Realtime messages, timestamps, heart reactions, composer, mark-as-read; start chat from profile/follower lists.

**Phase 5 — Remaining screens:** Create Post/Story (uploads to Storage) → bottom-nav Create button flow → Settings (theme, notifications, language, help, sign out; persisted in `user_settings`) → Edit Profile (avatar upload, username uniqueness) → Followers & Following (search, Message/Remove) → Notifications screen.

---

## 15. Feature checklist

Mark `[x]` when done and verified.

**Foundation**
- [x] Remove demo code, add dependencies, env handling, `.gitignore` (`env.json`)
- [x] Theme tokens (light + dark), Manrope font (via `google_fonts`), shared widgets
- [x] Router + bottom navigation shell

**Phase 1 — Supabase / Auth / Home**
- [x] Migrations 0001–0005 applied (schema, functions, RLS, storage, realtime) — files are `supabase/migrations/2026010100000N_*.sql`
- [x] Seed data (6 users, 14 posts, follows, comments, stories, messages) — `supabase/seed.sql`, login `<username>@sociao.test` / `Password123!`
- [x] Login with validation + show/hide password
- [x] Create Account with validation + show/hide password
- [x] Protected routes + logout (Sign Out lives in Settings; Settings is otherwise a Phase 5 stub)
- [x] Stories row (Add Story, Live, seen/unseen ring) — tapping a story is a "coming soon" stub
- [x] Feed post cards (text / image / video thumbnail)
- [x] Like / unlike persisted, accurate counts after refresh, no duplicates (verified against the live DB)
- [x] Bookmark, share, post options menu (owner: Delete; others: Report stub; "Copy text" replaces "Copy link" — no deep links exist; "Unfollow" deferred to Phase 2 when follow state is available)
- [x] Notifications + messages header buttons (Notifications screen itself is a Phase 5 placeholder)
- [x] Loading / empty / error states on feed
- [x] Comment pill opens the comments sheet and video tap opens the viewer

**Phase 2 — Profile**
- [x] Profile header with real data + stats (Following / Followers / Posts)
- [x] Post tab · Video grid tab (views) · Tag tab
- [x] Other-user profile (`/u/:userId`), follow / unfollow, Message

**Phase 3 — Video & Comments**
- [x] Full-screen video viewer (creator, caption, music); Video tab hides the bottom bar
- [x] Like / comment / share / save in viewer
- [x] Comments bottom sheet, one-level replies, comment likes, input, delete own

**Phase 4 — Messages**
- [x] Inbox (avatar, name, preview, time, unread dot, nav badge)
- [x] Chat thread with Realtime send/receive
- [x] Heart reactions, timestamps, mark-as-read, composer (video/phone/voice/attach are "coming soon" placeholders)

**Phase 5 — Rest**
- [x] Create Post (image/video/text, tag people, music) and Add Story; story viewer
- [x] Settings (edit profile, notifications, dark mode, languages, help, sign out) — theme/notifications persisted locally + `user_settings`; only English is selectable
- [x] Edit Profile (avatar upload, name, username uniqueness, bio, website)
- [x] Followers list (search, Message/Remove)
- [x] Following list (search, Message, long-press to unfollow)
- [x] Notifications screen (realtime, unread dot)

**Quality**
- [x] RLS verified against the live DB (forged like, other users' bookmarks, reply-to-reply, storage owner folders)
- [x] `flutter analyze` clean; 27 tests passing; browser walkthrough of every flow
- [x] No secret/service-role key anywhere in repo or app
- [ ] UI reviewed against all 13 reference screens (small + large screens)
