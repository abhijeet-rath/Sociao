-- Storage buckets. Object paths always start with the owner's uid:
--   avatars/{uid}/avatar.jpg
--   posts/{uid}/{postId}/image.jpg
--   videos/{uid}/{postId}/video.mp4
--   stories/{uid}/{storyId}.jpg|mp4

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('avatars', 'avatars', true, 2097152,   array['image/jpeg', 'image/png', 'image/webp']),
  ('posts',   'posts',   true, 10485760,  array['image/jpeg', 'image/png', 'image/webp']),
  ('videos',  'videos',  true, 104857600, array['video/mp4', 'video/quicktime', 'video/webm']),
  ('stories', 'stories', true, 52428800,  array['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/quicktime'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "sociao_media_public_read" on storage.objects for select
  using (bucket_id in ('avatars', 'posts', 'videos', 'stories'));

create policy "sociao_media_insert_own_folder" on storage.objects for insert to authenticated
  with check (bucket_id in ('avatars', 'posts', 'videos', 'stories')
              and (storage.foldername(name))[1] = auth.uid()::text);

create policy "sociao_media_update_own_folder" on storage.objects for update to authenticated
  using (bucket_id in ('avatars', 'posts', 'videos', 'stories')
         and (storage.foldername(name))[1] = auth.uid()::text);

create policy "sociao_media_delete_own_folder" on storage.objects for delete to authenticated
  using (bucket_id in ('avatars', 'posts', 'videos', 'stories')
         and (storage.foldername(name))[1] = auth.uid()::text);
