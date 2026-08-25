-- DEVELOPMENT FIXTURE ONLY.
-- This file is intentionally separate from production migrations.
-- Every identity uses a reserved .invalid email and cannot represent a real person.
begin;

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('90000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'fixture-climber-1@bloclens.invalid', null, now(), '{"provider":"fixture","providers":["fixture"]}', '{"username":"Fixture Climber 1"}', now(), now()),
  ('90000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'fixture-climber-2@bloclens.invalid', null, now(), '{"provider":"fixture","providers":["fixture"]}', '{"username":"Fixture Climber 2"}', now(), now()),
  ('90000000-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'fixture-climber-3@bloclens.invalid', null, now(), '{"provider":"fixture","providers":["fixture"]}', '{"username":"Fixture Climber 3"}', now(), now())
on conflict (id) do nothing;

update public.profiles
set age_confirmed_16_plus_at = coalesce(age_confirmed_16_plus_at, '2026-08-20T00:00:00Z'::timestamptz)
where id in (
  '90000000-0000-4000-8000-000000000001',
  '90000000-0000-4000-8000-000000000002',
  '90000000-0000-4000-8000-000000000003'
);

insert into public.gyms (
  id, name, brand_name, slug, description, suburb, state, postcode,
  latitude, longitude, is_claimed, is_verified, data_source, created_at, updated_at
) values
  ('10000000-0000-4000-8000-000000000001', 'Urban Climb West End', 'Urban Climb', 'urban-climb-west-end', 'Development Fixture — not live gym information.', 'West End', 'QLD', '4101', -27.4808, 153.0096, true, true, 'development_fixture', '2026-08-20T00:00:00Z', '2026-08-20T00:00:00Z'),
  ('10000000-0000-4000-8000-000000000002', 'Urban Climb Newstead', 'Urban Climb', 'urban-climb-newstead', 'Development Fixture — not live gym information.', 'Newstead', 'QLD', '4006', -27.4494, 153.0441, true, true, 'development_fixture', '2026-08-20T00:00:00Z', '2026-08-20T00:00:00Z'),
  ('10000000-0000-4000-8000-000000000003', '9 Degrees Enoggera', '9 Degrees', 'nine-degrees-enoggera', 'Development Fixture — not live gym information.', 'Enoggera', 'QLD', '4051', -27.4193, 152.9917, false, false, 'development_fixture', '2026-08-20T00:00:00Z', '2026-08-20T00:00:00Z')
on conflict (id) do update set
  name = excluded.name, brand_name = excluded.brand_name, slug = excluded.slug,
  description = excluded.description, suburb = excluded.suburb, state = excluded.state,
  postcode = excluded.postcode, latitude = excluded.latitude, longitude = excluded.longitude,
  is_claimed = excluded.is_claimed, is_verified = excluded.is_verified,
  data_source = excluded.data_source;

insert into public.gym_facilities (gym_id, facility, source) values
  ('10000000-0000-4000-8000-000000000001', 'parking', 'development_fixture'),
  ('10000000-0000-4000-8000-000000000001', 'showers', 'development_fixture'),
  ('10000000-0000-4000-8000-000000000001', 'training_board', 'development_fixture'),
  ('10000000-0000-4000-8000-000000000001', 'cafe', 'development_fixture'),
  ('10000000-0000-4000-8000-000000000001', 'lockers', 'development_fixture'),
  ('10000000-0000-4000-8000-000000000001', 'accessible_entry', 'development_fixture'),
  ('10000000-0000-4000-8000-000000000002', 'parking', 'development_fixture'),
  ('10000000-0000-4000-8000-000000000002', 'showers', 'development_fixture'),
  ('10000000-0000-4000-8000-000000000002', 'training_board', 'development_fixture'),
  ('10000000-0000-4000-8000-000000000002', 'cafe', 'development_fixture'),
  ('10000000-0000-4000-8000-000000000002', 'lockers', 'development_fixture'),
  ('10000000-0000-4000-8000-000000000002', 'accessible_entry', 'development_fixture'),
  ('10000000-0000-4000-8000-000000000003', 'parking', 'development_fixture'),
  ('10000000-0000-4000-8000-000000000003', 'training_board', 'development_fixture'),
  ('10000000-0000-4000-8000-000000000003', 'cafe', 'development_fixture'),
  ('10000000-0000-4000-8000-000000000003', 'lockers', 'development_fixture')
on conflict (gym_id, facility) do update set
  is_available = true, source = excluded.source;

insert into public.wall_zones (
  id, gym_id, name, location_description, wall_type, display_order,
  availability, last_reset_date
) values
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'River Slab', 'Near the river-side entry', 'slab', 0, 'active', '2026-08-18T00:00:00Z'),
  ('20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001', 'Main Cave', 'Central steep section', 'cave', 1, 'active', '2026-08-11T00:00:00Z'),
  ('20000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000001', 'Competition Wall', 'Beside the spectator area', 'mixed', 2, 'active', '2026-08-22T00:00:00Z'),
  ('20000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000002', 'The Island', 'Freestanding centre wall', 'mixed', 0, 'active', '2026-08-20T00:00:00Z'),
  ('20000000-0000-4000-8000-000000000005', '10000000-0000-4000-8000-000000000002', 'Steep Bay', 'Rear overhanging bay', 'overhang', 1, 'active', '2026-08-14T00:00:00Z'),
  ('20000000-0000-4000-8000-000000000006', '10000000-0000-4000-8000-000000000002', 'North Vertical', 'Along the northern wall', 'vertical', 2, 'active', '2026-08-07T00:00:00Z'),
  ('20000000-0000-4000-8000-000000000007', '10000000-0000-4000-8000-000000000003', 'Front Slab', 'Immediately left of reception', 'slab', 0, 'active', '2026-08-19T00:00:00Z'),
  ('20000000-0000-4000-8000-000000000008', '10000000-0000-4000-8000-000000000003', 'Back Cave', 'Rear corner steep section', 'cave', 1, 'active', '2026-08-12T00:00:00Z'),
  ('20000000-0000-4000-8000-000000000009', '10000000-0000-4000-8000-000000000003', 'Main Wall', 'Long wall through the centre', 'vertical', 2, 'active', '2026-08-05T00:00:00Z')
on conflict (id) do update set
  gym_id = excluded.gym_id, name = excluded.name,
  location_description = excluded.location_description, wall_type = excluded.wall_type,
  display_order = excluded.display_order, availability = excluded.availability,
  last_reset_date = excluded.last_reset_date;

insert into public.routes (
  id, gym_id, wall_zone_id, colour, gym_grade, lifecycle, set_date,
  estimated_archive_date, is_archive_date_estimated, archived_at,
  archived_reason, moderation_status, hidden_at
) values
  ('30000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Blue',-1,'active','2026-08-18T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Red',0,'active','2026-08-18T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Yellow',2,'active','2026-08-18T00:00:00Z','2026-09-01T00:00:00Z',true,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000002','Green',1,'active','2026-08-11T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000005','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000002','Purple',3,'active','2026-08-11T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000006','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000002','Black',5,'active','2026-08-11T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000007','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000003','Pink',2,'active','2026-08-22T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000008','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000003','White',4,'active','2026-08-22T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000009','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000003','Orange',6,'active','2026-08-22T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000010','10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000004','Blue',-1,'active','2026-08-20T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000011','10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000004','Red',3,'active','2026-08-20T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000012','10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000004','Yellow',7,'active','2026-08-20T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000013','10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000005','Green',0,'active','2026-08-14T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000014','10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000005','Purple',4,'active','2026-08-14T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000015','10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000005','Black',8,'active','2026-08-14T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000016','10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000006','Pink',1,'active','2026-08-07T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000017','10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000006','White',5,'active','2026-08-07T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000018','10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000006','Orange',7,'active','2026-08-07T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000019','10000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000007','Blue',-1,'active','2026-08-19T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000020','10000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000007','Red',2,'active','2026-08-19T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000021','10000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000007','Yellow',4,'active','2026-08-19T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000022','10000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000008','Green',1,'active','2026-08-12T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000023','10000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000008','Purple',3,'active','2026-08-12T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000024','10000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000008','Black',6,'temporarily_hidden','2026-08-12T00:00:00Z',null,false,null,null,'temporarily_hidden','2026-08-24T00:00:00Z'),
  ('30000000-0000-4000-8000-000000000025','10000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000009','Pink',0,'active','2026-08-05T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000026','10000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000009','White',5,'active','2026-08-05T00:00:00Z',null,false,null,null,'visible',null),
  ('30000000-0000-4000-8000-000000000027','10000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000009','Orange',8,'archived','2026-08-05T00:00:00Z',null,false,'2026-08-24T00:00:00Z','Development Fixture archive','visible',null)
on conflict (id) do update set
  gym_id = excluded.gym_id, wall_zone_id = excluded.wall_zone_id,
  colour = excluded.colour, gym_grade = excluded.gym_grade,
  lifecycle = excluded.lifecycle, set_date = excluded.set_date,
  estimated_archive_date = excluded.estimated_archive_date,
  is_archive_date_estimated = excluded.is_archive_date_estimated,
  archived_at = excluded.archived_at, archived_reason = excluded.archived_reason,
  moderation_status = excluded.moderation_status, hidden_at = excluded.hidden_at;

insert into public.beta_links (
  id, route_id, public_url, platform, original_author_display_name,
  original_post_url, submitted_by, tags, submitter_height_cm,
  submitter_arm_span_cm, link_status, embed_capability, moderation_status, hidden_at, created_at
) values
  ('40000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','https://example.com/bloclens/beta/west-end-slab-a','youtube','Development Fixture Author A','https://example.com/bloclens/source/west-end-slab-a','90000000-0000-4000-8000-000000000001',array['full_solution','static','short_climber']::public.beta_tag[],165,164,'healthy','supported','visible',null,'2026-08-20T00:00:00Z'),
  ('40000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000001','https://example.com/bloclens/beta/west-end-slab-b','instagram','Development Fixture Author B','https://example.com/bloclens/source/west-end-slab-b','90000000-0000-4000-8000-000000000002',array['crux','dynamic','tall_climber']::public.beta_tag[],184,190,'healthy','source_platform_only','visible',null,'2026-08-20T00:00:00Z'),
  ('40000000-0000-4000-8000-000000000003','30000000-0000-4000-8000-000000000001','https://example.com/bloclens/beta/broken','other','Development Fixture Author C','https://example.com/bloclens/source/broken','90000000-0000-4000-8000-000000000003',array['crux']::public.beta_tag[],null,null,'broken','source_platform_only','visible',null,'2026-08-20T00:00:00Z'),
  ('40000000-0000-4000-8000-000000000004','30000000-0000-4000-8000-000000000001','https://example.com/bloclens/beta/hidden','other','Development Fixture Author D','https://example.com/bloclens/source/hidden','90000000-0000-4000-8000-000000000003',array['full_solution']::public.beta_tag[],170,170,'healthy','source_platform_only','temporarily_hidden','2026-08-24T00:00:00Z','2026-08-20T00:00:00Z'),
  ('40000000-0000-4000-8000-000000000005','30000000-0000-4000-8000-000000000005','https://example.com/bloclens/beta/west-end-cave','vimeo','Development Fixture Author E','https://example.com/bloclens/source/west-end-cave','90000000-0000-4000-8000-000000000001',array['full_solution','dynamic']::public.beta_tag[],174,176,'healthy','supported','visible',null,'2026-08-20T00:00:00Z'),
  ('40000000-0000-4000-8000-000000000006','30000000-0000-4000-8000-000000000012','https://example.com/bloclens/beta/newstead-island','tiktok','Development Fixture Author F','https://example.com/bloclens/source/newstead-island','90000000-0000-4000-8000-000000000002',array['full_solution','tall_climber']::public.beta_tag[],181,187,'healthy','source_platform_only','visible',null,'2026-08-20T00:00:00Z')
on conflict (id) do update set
  route_id = excluded.route_id, public_url = excluded.public_url,
  platform = excluded.platform, original_author_display_name = excluded.original_author_display_name,
  original_post_url = excluded.original_post_url, tags = excluded.tags,
  submitter_height_cm = excluded.submitter_height_cm,
  submitter_arm_span_cm = excluded.submitter_arm_span_cm,
  link_status = excluded.link_status, embed_capability = excluded.embed_capability,
  moderation_status = excluded.moderation_status;

insert into public.reset_events (
  id, gym_id, wall_zone_id, reset_date, source, state,
  confirmation_count, is_estimated, is_official, created_by
) values
  ('50000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000003','2026-08-22T00:00:00Z','official','confirmed',0,false,true,null),
  ('50000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000004','2026-08-20T00:00:00Z','community_confirmed','confirmed',3,false,false,'90000000-0000-4000-8000-000000000001'),
  ('50000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000003',null,'2026-08-19T00:00:00Z','estimated','estimated',1,true,false,null)
on conflict (id) do update set
  reset_date = excluded.reset_date, source = excluded.source, state = excluded.state,
  confirmation_count = excluded.confirmation_count, is_estimated = excluded.is_estimated,
  is_official = excluded.is_official;

insert into public.logbook_entries (
  id, user_id, route_id, status, climbed_at, attempts, private_note,
  predicted_v_grade, client_created_at, client_idempotency_key
) values
  ('60000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','projecting','2026-08-24T00:00:00Z',4,'Development fixture private note',2,'2026-08-24T00:00:00Z','61000000-0000-4000-8000-000000000001'),
  ('60000000-0000-4000-8000-000000000002','90000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000001','sent','2026-08-23T00:00:00Z',3,null,2,'2026-08-23T00:00:00Z','61000000-0000-4000-8000-000000000002'),
  ('60000000-0000-4000-8000-000000000003','90000000-0000-4000-8000-000000000003','30000000-0000-4000-8000-000000000001','flash','2026-08-22T00:00:00Z',1,null,3,'2026-08-22T00:00:00Z','61000000-0000-4000-8000-000000000003'),
  ('60000000-0000-4000-8000-000000000004','90000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000002','projecting','2026-08-24T00:00:00Z',2,null,0,'2026-08-24T00:00:00Z','61000000-0000-4000-8000-000000000004'),
  ('60000000-0000-4000-8000-000000000005','90000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000002','sent','2026-08-23T00:00:00Z',5,null,1,'2026-08-23T00:00:00Z','61000000-0000-4000-8000-000000000005')
on conflict (user_id, route_id) do update set
  status = excluded.status, climbed_at = excluded.climbed_at,
  attempts = excluded.attempts, private_note = excluded.private_note,
  predicted_v_grade = excluded.predicted_v_grade;

insert into public.route_grade_votes (
  id, route_id, user_id, v_grade
) values
  ('70000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001',2),
  ('70000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000002',3),
  ('70000000-0000-4000-8000-000000000003','30000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000003',4),
  ('70000000-0000-4000-8000-000000000004','30000000-0000-4000-8000-000000000002','90000000-0000-4000-8000-000000000001',0),
  ('70000000-0000-4000-8000-000000000005','30000000-0000-4000-8000-000000000002','90000000-0000-4000-8000-000000000002',1)
on conflict (route_id, user_id) do update set
  v_grade = excluded.v_grade, is_valid = true;

commit;
