-- Row Level Security. Everything is denied unless a policy allows it.

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.post_tags enable row level security;
alter table public.likes enable row level security;
alter table public.bookmarks enable row level security;
alter table public.shares enable row level security;
alter table public.comments enable row level security;
alter table public.comment_likes enable row level security;
alter table public.stories enable row level security;
alter table public.story_views enable row level security;
alter table public.follows enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.message_reactions enable row level security;
alter table public.notifications enable row level security;
alter table public.user_settings enable row level security;

-- profiles (rows are created by the handle_new_user trigger only)
create policy "profiles_select" on public.profiles for select to authenticated using (true);
create policy "profiles_update_own" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- posts
create policy "posts_select" on public.posts for select to authenticated using (true);
create policy "posts_insert_own" on public.posts for insert to authenticated
  with check (user_id = auth.uid());
create policy "posts_update_own" on public.posts for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "posts_delete_own" on public.posts for delete to authenticated
  using (user_id = auth.uid());

-- post_tags
create policy "post_tags_select" on public.post_tags for select to authenticated using (true);
create policy "post_tags_insert_post_owner" on public.post_tags for insert to authenticated
  with check (exists (select 1 from public.posts p
                      where p.id = post_id and p.user_id = auth.uid()));
create policy "post_tags_delete_post_owner" on public.post_tags for delete to authenticated
  using (exists (select 1 from public.posts p
                 where p.id = post_id and p.user_id = auth.uid()));

-- likes
create policy "likes_select" on public.likes for select to authenticated using (true);
create policy "likes_insert_own" on public.likes for insert to authenticated
  with check (user_id = auth.uid());
create policy "likes_delete_own" on public.likes for delete to authenticated
  using (user_id = auth.uid());

-- bookmarks (private)
create policy "bookmarks_select_own" on public.bookmarks for select to authenticated
  using (user_id = auth.uid());
create policy "bookmarks_insert_own" on public.bookmarks for insert to authenticated
  with check (user_id = auth.uid());
create policy "bookmarks_delete_own" on public.bookmarks for delete to authenticated
  using (user_id = auth.uid());

-- shares
create policy "shares_select_own" on public.shares for select to authenticated
  using (user_id = auth.uid());
create policy "shares_insert_own" on public.shares for insert to authenticated
  with check (user_id = auth.uid());

-- comments
create policy "comments_select" on public.comments for select to authenticated using (true);
create policy "comments_insert_own" on public.comments for insert to authenticated
  with check (user_id = auth.uid());
create policy "comments_update_own" on public.comments for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "comments_delete_own_or_post_owner" on public.comments for delete to authenticated
  using (user_id = auth.uid()
         or exists (select 1 from public.posts p
                    where p.id = post_id and p.user_id = auth.uid()));

-- comment_likes
create policy "comment_likes_select" on public.comment_likes for select to authenticated using (true);
create policy "comment_likes_insert_own" on public.comment_likes for insert to authenticated
  with check (user_id = auth.uid());
create policy "comment_likes_delete_own" on public.comment_likes for delete to authenticated
  using (user_id = auth.uid());

-- stories
create policy "stories_select_active_or_own" on public.stories for select to authenticated
  using (expires_at > now() or user_id = auth.uid());
create policy "stories_insert_own" on public.stories for insert to authenticated
  with check (user_id = auth.uid());
create policy "stories_update_own" on public.stories for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "stories_delete_own" on public.stories for delete to authenticated
  using (user_id = auth.uid());

-- story_views
create policy "story_views_select_own" on public.story_views for select to authenticated
  using (viewer_id = auth.uid());
create policy "story_views_insert_own" on public.story_views for insert to authenticated
  with check (viewer_id = auth.uid());

-- follows (either side may delete: unfollow, or remove a follower)
create policy "follows_select" on public.follows for select to authenticated using (true);
create policy "follows_insert_own" on public.follows for insert to authenticated
  with check (follower_id = auth.uid());
create policy "follows_delete_either_side" on public.follows for delete to authenticated
  using (follower_id = auth.uid() or following_id = auth.uid());

-- conversations
create policy "conversations_select_member" on public.conversations for select to authenticated
  using (auth.uid() in (user_a, user_b));
create policy "conversations_insert_member" on public.conversations for insert to authenticated
  with check (auth.uid() in (user_a, user_b));

-- messages (read receipts go through mark_conversation_read)
create policy "messages_select_member" on public.messages for select to authenticated
  using (public.is_conversation_member(conversation_id));
create policy "messages_insert_sender" on public.messages for insert to authenticated
  with check (sender_id = auth.uid() and public.is_conversation_member(conversation_id));
create policy "messages_delete_sender" on public.messages for delete to authenticated
  using (sender_id = auth.uid());

-- message_reactions
create policy "message_reactions_select_member" on public.message_reactions for select to authenticated
  using (exists (select 1 from public.messages m
                 where m.id = message_id and public.is_conversation_member(m.conversation_id)));
create policy "message_reactions_insert_own" on public.message_reactions for insert to authenticated
  with check (user_id = auth.uid()
              and exists (select 1 from public.messages m
                          where m.id = message_id
                            and public.is_conversation_member(m.conversation_id)));
create policy "message_reactions_delete_own" on public.message_reactions for delete to authenticated
  using (user_id = auth.uid());

-- notifications (inserted by triggers only)
create policy "notifications_select_own" on public.notifications for select to authenticated
  using (user_id = auth.uid());
create policy "notifications_update_own" on public.notifications for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "notifications_delete_own" on public.notifications for delete to authenticated
  using (user_id = auth.uid());

-- user_settings
create policy "user_settings_select_own" on public.user_settings for select to authenticated
  using (user_id = auth.uid());
create policy "user_settings_insert_own" on public.user_settings for insert to authenticated
  with check (user_id = auth.uid());
create policy "user_settings_update_own" on public.user_settings for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
