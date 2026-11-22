-- Table privileges for the API roles.
--
-- Newer Supabase projects do not auto-grant new public tables to
-- anon/authenticated, so without these the REST API answers "permission
-- denied" before RLS is even evaluated. Grants mirror the RLS policies
-- (least privilege); RLS still decides which rows are visible/writable.
-- `anon` gets nothing: the app requires sign-in for all data.

grant usage on schema public to authenticated;

grant select, update on public.profiles to authenticated;
grant select, insert, update, delete on public.posts to authenticated;
grant select, insert, delete on public.post_tags to authenticated;
grant select, insert, delete on public.likes to authenticated;
grant select, insert, delete on public.bookmarks to authenticated;
grant select, insert on public.shares to authenticated;
grant select, insert, update, delete on public.comments to authenticated;
grant select, insert, delete on public.comment_likes to authenticated;
grant select, insert, update, delete on public.stories to authenticated;
grant select, insert on public.story_views to authenticated;
grant select, insert, delete on public.follows to authenticated;
grant select, insert on public.conversations to authenticated;
grant select, insert, delete on public.messages to authenticated;
grant select, insert, delete on public.message_reactions to authenticated;
grant select, update, delete on public.notifications to authenticated;
grant select, insert, update on public.user_settings to authenticated;

-- Views (security_invoker, so the caller's RLS applies underneath).
grant select on public.post_feed, public.profile_stats, public.story_tray to authenticated;
