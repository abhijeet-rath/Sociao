# Sociao

A modern, mobile-first social media app built with **Flutter** and **Supabase**.
Share photos and videos, post stories, comment, follow people and chat in real time.

![Flutter](https://img.shields.io/badge/Flutter-3.50-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.14-0175C2?logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Backend-Supabase-3ECF8E?logo=supabase&logoColor=white)
![State](https://img.shields.io/badge/State-Riverpod-5C6BC0)

> The UI follows the design screens in [`reference/`](reference/). Development rules and the full
> architecture notes live in [`CLAUDE.md`](CLAUDE.md).

---

## Features

| Area | What you get |
|---|---|
| **Authentication** | Sign up and log in with email and password, inline validation, show/hide password, sign out, protected routes |
| **Home feed** | Stories row (Add Story, Live badge, seen/unseen rings), image/video/text posts, like, comment, share, bookmark, post options, pull-to-refresh, infinite scroll |
| **Video viewer** | Full-screen vertical video pager with creator, caption, music and like/comment/share/save |
| **Comments** | Bottom sheet with one-level replies, comment likes, delete your own |
| **Messages** | Inbox with unread dots and a tab badge, realtime 1:1 chat, heart reactions, read receipts |
| **Profile** | Photo, name, username, bio, website, Following/Followers/Posts counts, Post / Video / Tag tabs, follow and message other users |
| **Create** | Post (photo, video or text, tag people, music) and Story, uploaded to Supabase Storage |
| **Followers / Following** | Searchable lists, Message, Remove follower, unfollow |
| **Edit profile** | Avatar upload, username uniqueness check, bio, website |
| **Settings** | Dark mode (light / dark / system), notifications, language, help, sign out |
| **Notifications** | Live list of likes, comments and follows with an unread dot |

Every screen has loading, empty and error states. No app content is hard-coded: everything comes from Supabase.

## Tech stack

- **Frontend:** Flutter and Dart, Material UI (`material_ui`), Manrope font
- **State management:** [Riverpod](https://riverpod.dev)
- **Navigation:** [go_router](https://pub.dev/packages/go_router) with auth redirects
- **Backend:** [Supabase](https://supabase.com) via `supabase_flutter`
  - **Auth:** email/password sessions
  - **Postgres:** tables, views, RPC functions, triggers, Row Level Security
  - **Storage:** `avatars`, `posts`, `videos`, `stories` buckets
  - **Realtime:** chat messages, reactions, notifications
- **Media:** `image_picker`, `video_player`, `cached_network_image`, `share_plus`

## Architecture

Feature-first, with one direction of data flow:

```
Screens / widgets  ->  Riverpod providers  ->  Repositories  ->  Supabase client
```

- Widgets only read providers and render. They never call Supabase directly.
- Repositories are the only code that talks to Supabase, and are injected through providers so tests can fake them.
- Likes, bookmarks and comment likes update instantly (optimistic), then reconcile with the database, and roll back on failure.
- Counts (likes, comments, saves, shares) are maintained by **database triggers**, so they stay accurate after a refresh and a user can never like a post twice.

```
lib/
  main.dart, app.dart        App entry and root widget
  core/                      config, router, theme, shared widgets, utils
  features/
    auth/  feed/  video/  comments/  messages/
    profile/  create/  settings/  notifications/  shell/
supabase/
  migrations/                Schema, functions, RLS, storage, realtime, grants
  seed.sql                   Demo data (dev only)
reference/                   UI reference screens
test/                        Unit and widget tests
```

## Getting started

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) 3.50 or newer (Dart 3.14)
- A free [Supabase](https://supabase.com) project
- Node.js (only to run the Supabase CLI through `npx`)

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Create your Supabase project

1. Create a project at supabase.com.
2. In **Authentication -> Providers -> Email**, turn **off** "Confirm email" for development, so new accounts can log in immediately.
3. In **Project Settings -> API**, copy the **Project URL** and the **publishable key**.

### 3. Add your keys

```bash
cp env.example.json env.json
```

Edit `env.json`:

```json
{
  "SUPABASE_URL": "https://YOUR-PROJECT.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."
}
```

`env.json` is git-ignored. Only the **publishable** key belongs here. See [Security](#security).

### 4. Create the database

```bash
npx supabase login
npx supabase link --project-ref <your-project-ref>   # asks for your database password
npx supabase db push --remote                        # applies supabase/migrations/*.sql
```

> The CLI targets a local database by default, so always pass `--remote` for your hosted project.

### 5. (Optional) Load demo data

```bash
npx supabase db query --remote --yes -f supabase/seed.sql
```

This adds 6 users, 14 posts, follows, likes, comments, stories and chats. It writes to the linked project, so only run it on a development project.

### 6. Run the app

```bash
flutter run --dart-define-from-file=env.json                 # default device
flutter run -d chrome --dart-define-from-file=env.json       # web
```

If you start the app without `env.json`, it shows a "setup required" screen instead of crashing.

## Demo accounts

After seeding, log in with any of these (password for all: `Password123!`):

| Email | Name |
|---|---|
| `gustavo.levin@sociao.test` | Gustavo Levin |
| `marilyn.torff@sociao.test` | Marilyn Torff |
| `lindsey.septimus@sociao.test` | Lindsey Septimus |
| `livia.botosh@sociao.test` | Livia Botosh |
| `randy.vetrovs@sociao.test` | Randy Vetrovs |
| `ahmad.korsgaard@sociao.test` | Ahmad Korsgaard |

These are development-only accounts. Delete them before going live.

## Common commands

```bash
flutter analyze              # static analysis (should report no issues)
dart format .                # format code
flutter test                 # run all tests
flutter build apk --dart-define-from-file=env.json
npx supabase migration new <name>   # add a new migration
```

## Testing

`flutter test` runs unit and widget tests covering:

- Validators and formatters
- Login and sign-up forms (button disabled until valid, show/hide password)
- Feed like/unlike with rollback on failure
- Comment threads, one-level replies and comment likes
- Chat reaction summaries and inbox unread state
- Settings (dark mode switch is saved)
- A regression test for the bottom-bar layout

The main flows were also checked against a live Supabase project, including the security rules: a user cannot like as someone else, cannot read other people's bookmarks, and cannot reply to a reply.

## Security

- **Publishable key (`sb_publishable_...`, formerly "anon key")** is safe in the app because every table is protected by Row Level Security.
- **Secret key (`sb_secret_...`, formerly "service_role key")** bypasses all security rules. **Never put it in the app, in `env.json`, or in git.** If it is ever exposed, rotate it in the Supabase dashboard immediately.
- Every table has RLS enabled and grants only what its policies need. Anonymous users get no data access.
- Files are stored under the owner's user id, and storage policies only let you write to your own folder.
- Any new table or view needs both an RLS policy and a `grant` in its migration.

## Database at a glance

`profiles`, `posts`, `post_tags`, `likes`, `bookmarks`, `shares`, `comments`, `comment_likes`, `stories`, `story_views`, `follows`, `conversations`, `messages`, `message_reactions`, `notifications`, `user_settings`.

Views: `post_feed`, `profile_stats`, `story_tray`. RPC functions: `toggle_like`, `toggle_bookmark`, `toggle_comment_like`, `toggle_follow`, `get_or_create_conversation`, `inbox`, `mark_conversation_read`, `increment_post_views`, `log_share`.

## Known limitations

- Chat video call, voice call, voice message and attachment buttons show "coming soon".
- Only English is selectable; other languages are listed but disabled.
- Uploaded videos have no generated thumbnail (a grey tile shows until opened).
- Password reset by email is not built yet.
- Seed images come from placeholder services and the sample video is a public clip.

## Roadmap

- Password reset and email confirmation flow
- Push notifications
- Video thumbnails and a story "seen by" list
- Video and voice calls in chat
- Full translations

## Contributing

Read [`CLAUDE.md`](CLAUDE.md) first for the architecture, coding standards and the feature checklist. Before opening a change, make sure `flutter analyze` is clean and `flutter test` passes.
