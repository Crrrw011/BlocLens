-- Keep internal notification trigger functions independent of caller-controlled
-- schemas. Their bodies already qualify every application relation explicitly.
alter function private.enqueue_notifications(
  public.notification_category,
  uuid,
  uuid,
  uuid[],
  jsonb
) set search_path = '';

alter function private.enqueue_beta_notifications()
  set search_path = '';

alter function private.enqueue_reset_notifications()
  set search_path = '';

alter function private.enqueue_project_removal_notifications()
  set search_path = '';
