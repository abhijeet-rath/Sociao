-- Realtime: live chat, reactions and notification badges. RLS still applies.

alter publication supabase_realtime add table
  public.messages, public.message_reactions, public.notifications;

-- Needed so DELETE events (e.g. removing a heart) carry the old row's columns.
alter table public.message_reactions replica identity full;
