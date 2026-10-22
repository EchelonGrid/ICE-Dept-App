-- ICE Department App - Supabase baseline schema
-- Run once in the SQL Editor of a NEW Supabase project.
-- This is an initial schema, not a migration for an existing production database.

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Identity and role helpers
-- ---------------------------------------------------------------------------

create table if not exists public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null unique,
  name text not null default 'User',
  role text not null default 'student'
    check (role in ('admin', 'teacher', 'student')),
  password_changed boolean not null default false,
  initials text,
  created_at timestamptz not null default now()
);

create index if not exists users_role_idx on public.users (role);

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.users u
    where u.id = (select auth.uid())
      and u.role = 'admin'
  );
$$;

create or replace function public.is_teacher()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.users u
    where u.id = (select auth.uid())
      and u.role = 'teacher'
  );
$$;

create or replace function public.is_student()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.users u
    where u.id = (select auth.uid())
      and u.role = 'student'
  );
$$;

create or replace function public.protect_user_role_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (new.role is distinct from old.role or new.email is distinct from old.email)
     and not public.is_admin()
     and coalesce(auth.role(), '') <> 'service_role'
     and current_user not in ('postgres', 'supabase_admin') then
    raise exception 'Only an administrator can change account role or email';
  end if;

  return new;
end;
$$;

drop trigger if exists protect_user_role_fields on public.users;
create trigger protect_user_role_fields
before update on public.users
for each row execute function public.protect_user_role_fields();

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
  v_role text;
  v_initials text;
begin
  v_name := coalesce(
    nullif(new.raw_user_meta_data ->> 'name', ''),
    nullif(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    'User'
  );

  -- app_metadata is only writable by trusted Supabase server-side code.
  v_role := case
    when new.raw_app_meta_data ->> 'role' in ('admin', 'teacher', 'student')
      then new.raw_app_meta_data ->> 'role'
    else 'student'
  end;
  v_initials := nullif(upper(trim(new.raw_user_meta_data ->> 'initials')), '');

  insert into public.users (id, email, name, role, password_changed, initials)
  values (new.id, coalesce(new.email, ''), v_name, v_role, false, v_initials)
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

-- Backfill accounts that existed before this script was run. Do not promote
-- accounts based on user_metadata; assign admin/teacher roles using trusted SQL.
insert into public.users (id, email, name, role, password_changed, initials)
select
  au.id,
  coalesce(au.email, ''),
  coalesce(
    nullif(au.raw_user_meta_data ->> 'name', ''),
    nullif(au.raw_user_meta_data ->> 'full_name', ''),
    nullif(split_part(coalesce(au.email, ''), '@', 1), ''),
    'User'
  ),
  case
    when au.raw_app_meta_data ->> 'role' in ('admin', 'teacher', 'student')
      then au.raw_app_meta_data ->> 'role'
    else 'student'
  end,
  false,
  nullif(upper(trim(au.raw_user_meta_data ->> 'initials')), '')
from auth.users au
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Academic batches, profiles, faculty and routines
-- ---------------------------------------------------------------------------

create table if not exists public.batches (
  id uuid primary key default gen_random_uuid(),
  batch_number integer not null unique check (batch_number > 0),
  name text,
  code text,
  status text not null default 'active'
    check (lower(status) in ('active', 'graduated')),
  current_semester text not null default '1-1',
  semester_start_date date,
  created_at timestamptz not null default now()
);

-- The app uses this ID as a fallback when a student profile is not available.
insert into public.batches (id, batch_number, name, code, status, current_semester)
values (
  'cba1ba2e-d3ae-49c6-9d35-ae5753a224dc',
  21,
  'Batch 21',
  'ICE-21',
  'active',
  '3-1'
)
on conflict (batch_number) do nothing;

create table if not exists public.student_profiles (
  user_id uuid primary key references public.users (id) on delete cascade,
  batch_id uuid not null references public.batches (id) on delete restrict,
  is_cr boolean not null default false,
  student_id_roll text not null,
  current_semester text not null default '3-1',
  created_at timestamptz not null default now(),
  constraint student_profiles_batch_roll_unique unique (batch_id, student_id_roll)
);

create index if not exists student_profiles_batch_idx
  on public.student_profiles (batch_id);

create or replace function public.is_cr()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.student_profiles sp
    where sp.user_id = (select auth.uid())
      and sp.is_cr
  );
$$;

create or replace function public.current_student_batch_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select sp.batch_id
  from public.student_profiles sp
  where sp.user_id = (select auth.uid())
  limit 1;
$$;

create or replace function public.can_access_batch_label(p_batch text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_admin()
      or public.is_teacher()
      or (
        public.is_student()
        and exists (
          select 1
          from public.student_profiles sp
          join public.batches b on b.id = sp.batch_id
          where sp.user_id = (select auth.uid())
            and b.batch_number::text =
              nullif(regexp_replace(coalesce(p_batch, ''), '[^0-9]', '', 'g'), '')
        )
      );
$$;

create table if not exists public.faculty_directory (
  id uuid primary key default gen_random_uuid(),
  initials text not null unique,
  initial text,
  full_name text not null,
  designation text,
  department text not null default 'ICE',
  email text,
  user_id uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists faculty_directory_user_id_idx
  on public.faculty_directory (user_id);

-- Seed the directory used by the app when the table is first installed.
insert into public.faculty_directory
  (initials, initial, full_name, designation, department, email)
values
  ('AM', 'AM', 'Akif Mahdi', 'Lecturer', 'ICE', 'akif@ice.dept'),
  ('DAF', 'DAF', 'Dr. A. F. M. Zainul Abadin', 'Associate Professor', 'ICE', 'daf@ice.dept'),
  ('KK', 'KK', 'Prof. Dr. Kamruzzaman Khan', 'Professor', 'ICE', 'kamruzzaman@ice.dept'),
  ('MAH', 'MAH', 'Prof. Dr. Md. Anwar Hossain', 'Professor', 'ICE', 'anwar@ice.dept'),
  ('MAR', 'MAR', 'Dr. Md. Azizur Rahman', 'Associate Professor', 'ICE', 'azizur@ice.dept'),
  ('MIH', 'MIH', 'Dr. Md. Imran Hossain', 'Associate Professor', 'ICE', 'imran@ice.dept'),
  ('MIK', 'MIK', 'Md. Ibrahim Khalil', 'Assistant Professor', 'ICE', 'ibrahim@ice.dept'),
  ('MKIC', 'MKIC', 'Prof. Dr. Mir Khaled Iqbal Chowdhury', 'Professor', 'ICE', 'khaled@ice.dept'),
  ('MOF', 'MOF', 'Prof. Dr. Md. Omar Faruk', 'Professor', 'ICE', 'omar@ice.dept'),
  ('MSH', 'MSH', 'Prof. Dr. Md. Sarwar Hosain', 'Professor', 'ICE', 'sarwar@ice.dept'),
  ('SS', 'SS', 'Soma Saha', 'Assistant Professor', 'ICE', 'soma@ice.dept'),
  ('TD', 'TD', 'Tarun Debnath', 'Assistant Professor', 'ICE', 'tarun@ice.dept'),
  ('TNT', 'TNT', 'Taskin Noor Turna', 'Assistant Professor', 'ICE', 'turna@ice.dept')
on conflict (initials) do nothing;

create table if not exists public.class_routine (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.batches (id) on delete cascade,
  teacher_id uuid not null references public.users (id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 1 and 7),
  start_time time not null,
  end_time time not null,
  course_name text not null,
  room_number text not null default 'ICE-Room 101',
  status text not null default 'scheduled'
    check (status in ('scheduled', 'canceled')),
  created_at timestamptz not null default now(),
  constraint class_routine_time_order check (end_time > start_time)
);

create index if not exists class_routine_batch_day_time_idx
  on public.class_routine (batch_id, day_of_week, start_time);
create index if not exists class_routine_teacher_day_time_idx
  on public.class_routine (teacher_id, day_of_week, start_time);

create table if not exists public.department_routines (
  id text primary key default gen_random_uuid()::text,
  batch text not null,
  day_of_week text not null,
  start_time time not null,
  end_time time not null,
  course_code text not null,
  teacher_initial text,
  room_number text not null default 'TBA',
  is_lab boolean not null default false,
  week_parity text not null default 'all'
    check (lower(week_parity) in ('all', 'odd', 'even')),
  effective_start_date date,
  created_at timestamptz not null default now(),
  constraint department_routines_time_order check (end_time > start_time)
);

create index if not exists department_routines_batch_day_time_idx
  on public.department_routines (batch, day_of_week, start_time);
create index if not exists department_routines_teacher_idx
  on public.department_routines (upper(teacher_initial));

-- ---------------------------------------------------------------------------
-- Notices, class tests and resource vault
-- ---------------------------------------------------------------------------

create table if not exists public.notices (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.users (id) on delete cascade,
  batch_id uuid references public.batches (id) on delete cascade,
  title text not null,
  content text not null,
  is_cr_notice boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists notices_batch_created_idx
  on public.notices (batch_id, created_at desc);
create index if not exists notices_author_idx on public.notices (author_id);

create table if not exists public.department_notices (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  content text not null,
  attachment_url text,
  attachment_name text,
  target_batch text not null default 'all',
  priority text not null default 'normal'
    check (lower(priority) in ('normal', 'urgent')),
  is_pinned boolean not null default false,
  author_name text not null default 'Department Office',
  created_at timestamptz not null default now(),
  expires_at timestamptz
);

create index if not exists department_notices_pinned_created_idx
  on public.department_notices (is_pinned desc, created_at desc);
create index if not exists department_notices_expiry_idx
  on public.department_notices (expires_at)
  where expires_at is not null;

create table if not exists public.class_tests (
  id uuid primary key default gen_random_uuid(),
  batch text not null,
  course_code text not null,
  title text not null,
  syllabus text,
  test_date date not null,
  test_time time,
  created_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists class_tests_batch_date_time_idx
  on public.class_tests (batch, test_date, test_time);

create table if not exists public.academic_resources (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null default 'notes',
  course_name text not null,
  subject_name text,
  file_url text not null,
  file_path text,
  uploader_name text,
  uploader_id uuid,
  is_local boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists academic_resources_course_idx
  on public.academic_resources (course_name);
create index if not exists academic_resources_subject_idx
  on public.academic_resources (subject_name);

-- ---------------------------------------------------------------------------
-- Attendance
-- ---------------------------------------------------------------------------

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  -- The app uses both class_routine UUIDs and department_routines IDs here.
  class_id text not null,
  student_id uuid not null references public.users (id) on delete cascade,
  date date not null,
  status text not null default 'present'
    check (lower(status) in ('present', 'absent')),
  created_at timestamptz not null default now(),
  constraint attendance_class_student_date_unique
    unique (class_id, student_id, date)
);

create index if not exists attendance_student_date_idx
  on public.attendance (student_id, date desc);
create index if not exists attendance_class_date_idx
  on public.attendance (class_id, date desc);

create table if not exists public.attendance_sessions (
  id uuid primary key default gen_random_uuid(),
  course_code text not null,
  batch text not null,
  teacher_initial text not null,
  session_date date not null default current_date,
  start_time time,
  status text not null default 'COMPLETED'
    check (upper(status) in ('COMPLETED', 'ACTIVE', 'CANCELLED', 'RESCHEDULED')),
  total_students integer not null default 0 check (total_students >= 0),
  present_count integer not null default 0 check (present_count >= 0),
  created_at timestamptz not null default now(),
  constraint attendance_sessions_present_lte_total
    check (present_count <= total_students)
);

create index if not exists attendance_sessions_date_idx
  on public.attendance_sessions (session_date desc);
create index if not exists attendance_sessions_teacher_batch_date_idx
  on public.attendance_sessions (upper(teacher_initial), batch, session_date desc);

create table if not exists public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.attendance_sessions (id) on delete cascade,
  student_id uuid references public.users (id) on delete set null,
  student_roll text not null default '',
  student_name text not null default '',
  status text not null default 'PRESENT'
    check (upper(status) in ('PRESENT', 'ABSENT')),
  scanned_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists attendance_records_session_roll_idx
  on public.attendance_records (session_id, student_roll);
create index if not exists attendance_records_student_idx
  on public.attendance_records (student_id);

-- Keep session summaries consistent when roster rows are manually changed.
create or replace function public.refresh_attendance_session_counts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session_id uuid;
begin
  v_session_id := coalesce(new.session_id, old.session_id);

  update public.attendance_sessions s
  set total_students = counts.total_count,
      present_count = counts.present_count
  from (
    select count(*)::integer as total_count,
           count(*) filter (where upper(status) = 'PRESENT')::integer as present_count
    from public.attendance_records
    where session_id = v_session_id
  ) counts
  where s.id = v_session_id;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists refresh_attendance_session_counts on public.attendance_records;
create trigger refresh_attendance_session_counts
after insert or update or delete on public.attendance_records
for each row execute function public.refresh_attendance_session_counts();

-- ---------------------------------------------------------------------------
-- Chat
-- ---------------------------------------------------------------------------

create table if not exists public.common_chat (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid references public.batches (id) on delete cascade,
  sender_id uuid not null references public.users (id) on delete cascade,
  sender_name text not null,
  message text not null default '',
  chat_scope text not null default 'batch'
    check (chat_scope in ('batch', 'department', 'cr')),
  is_edited boolean not null default false,
  reactions jsonb not null default '{}'::jsonb
    check (jsonb_typeof(reactions) = 'object'),
  attachment_url text,
  attachment_name text,
  attachment_type text check (attachment_type in ('image', 'file')),
  referenced_notice_id text,
  referenced_notice_title text,
  reply_to_id uuid references public.common_chat (id) on delete set null,
  reply_to_text text,
  reply_to_sender text,
  created_at timestamptz not null default now(),
  constraint common_chat_batch_scope_check
    check (chat_scope <> 'batch' or batch_id is not null)
);

create index if not exists common_chat_batch_created_idx
  on public.common_chat (batch_id, created_at);
create index if not exists common_chat_scope_created_idx
  on public.common_chat (chat_scope, created_at);
create index if not exists common_chat_sender_idx
  on public.common_chat (sender_id);

create or replace function public.prepare_chat_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.sender_id is distinct from (select auth.uid())
       and coalesce(auth.role(), '') <> 'service_role' then
      raise exception 'sender_id must match the authenticated user';
    end if;

    select u.name into new.sender_name
    from public.users u
    where u.id = new.sender_id;

    if new.sender_name is null then
      raise exception 'Chat sender profile does not exist';
    end if;

    return new;
  end if;

  if not public.is_admin() then
    if old.sender_id is distinct from (select auth.uid()) then
      if (to_jsonb(new) - 'reactions') is distinct from
         (to_jsonb(old) - 'reactions') then
        raise exception 'Only the sender can edit message content';
      end if;
    elsif (to_jsonb(new) - array['message', 'is_edited', 'reactions']) is distinct from
          (to_jsonb(old) - array['message', 'is_edited', 'reactions']) then
      raise exception 'Chat message identity and attachments cannot be changed';
    end if;
  end if;

  if new.reactions is distinct from old.reactions
     and not public.is_admin() then
    if jsonb_typeof(new.reactions) <> 'object' then
      raise exception 'Reactions must be a JSON object';
    end if;

    if exists (
      select 1
      from jsonb_each(new.reactions) entry
      where jsonb_typeof(entry.value) <> 'array'
    ) then
      raise exception 'Each reaction must contain a list of user IDs';
    end if;

    if exists (
      select 1
      from (
        select key
        from jsonb_object_keys(coalesce(old.reactions, '{}'::jsonb) ||
                               coalesce(new.reactions, '{}'::jsonb)) keys(key)
      ) emojis
      where (
        select coalesce(jsonb_agg(to_jsonb(member) order by member), '[]'::jsonb)
        from jsonb_array_elements_text(coalesce(old.reactions -> emojis.key, '[]'::jsonb)) values_old(member)
        where member <> (select auth.uid())::text
      ) is distinct from (
        select coalesce(jsonb_agg(to_jsonb(member) order by member), '[]'::jsonb)
        from jsonb_array_elements_text(coalesce(new.reactions -> emojis.key, '[]'::jsonb)) values_new(member)
        where member <> (select auth.uid())::text
      )
    ) then
      raise exception 'Users may only change their own reactions';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists prepare_chat_message on public.common_chat;
create trigger prepare_chat_message
before insert or update on public.common_chat
for each row execute function public.prepare_chat_message();

-- ---------------------------------------------------------------------------
-- QR attendance RPC
-- ---------------------------------------------------------------------------

create or replace function public.mark_qr_attendance(
  p_class_id text,
  p_qr_timestamp bigint,
  p_qr_token text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_expected_token text;
  v_today date := (clock_timestamp() at time zone 'Asia/Dhaka')::date;
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'message', 'You must be signed in.');
  end if;

  if not public.is_student() then
    return jsonb_build_object('success', false, 'message', 'Only students can submit QR attendance.');
  end if;

  if p_class_id is null or p_qr_timestamp is null or p_qr_token is null then
    return jsonb_build_object('success', false, 'message', 'Invalid QR payload.');
  end if;

  if abs(extract(epoch from clock_timestamp()) * 1000 - p_qr_timestamp) > 30000 then
    return jsonb_build_object('success', false, 'message', 'This QR code has expired.');
  end if;

  if not exists (
    select 1
    from public.department_routines dr
    join public.student_profiles sp on sp.user_id = v_user_id
    join public.batches b on b.id = sp.batch_id
    where dr.id = p_class_id
      and regexp_replace(dr.batch, '[^0-9]', '', 'g') = b.batch_number::text
  ) then
    return jsonb_build_object('success', false, 'message', 'This class is not assigned to your batch.');
  end if;

  -- Compatibility with QRTokenHelper in this repository. The salt is present
  -- in the client bundle, so this hash is NOT a secure signature. See README.
  v_expected_token := encode(
    extensions.digest(
      convert_to(p_class_id || ':' || p_qr_timestamp::text || ':ICE_SECURE_QR_2026', 'UTF8'),
      'sha256'
    ),
    'hex'
  );

  if lower(p_qr_token) <> v_expected_token then
    return jsonb_build_object('success', false, 'message', 'QR token validation failed.');
  end if;

  insert into public.attendance (class_id, student_id, date, status)
  values (p_class_id, v_user_id, v_today, 'present')
  on conflict (class_id, student_id, date)
  do update set status = 'present';

  return jsonb_build_object('success', true, 'message', 'Attendance marked successfully.');
end;
$$;

-- Do not expose internal helper functions or the attendance RPC to anonymous users.
revoke all on function public.is_admin() from public, anon;
revoke all on function public.is_teacher() from public, anon;
revoke all on function public.is_student() from public, anon;
revoke all on function public.is_cr() from public, anon;
revoke all on function public.current_student_batch_id() from public, anon;
revoke all on function public.can_access_batch_label(text) from public, anon;
revoke all on function public.mark_qr_attendance(text, bigint, text) from public, anon;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_teacher() to authenticated;
grant execute on function public.is_student() to authenticated;
grant execute on function public.is_cr() to authenticated;
grant execute on function public.current_student_batch_id() to authenticated;
grant execute on function public.can_access_batch_label(text) to authenticated;
grant execute on function public.mark_qr_attendance(text, bigint, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.users enable row level security;
alter table public.batches enable row level security;
alter table public.student_profiles enable row level security;
alter table public.faculty_directory enable row level security;
alter table public.class_routine enable row level security;
alter table public.department_routines enable row level security;
alter table public.notices enable row level security;
alter table public.department_notices enable row level security;
alter table public.class_tests enable row level security;
alter table public.academic_resources enable row level security;
alter table public.attendance enable row level security;
alter table public.attendance_sessions enable row level security;
alter table public.attendance_records enable row level security;
alter table public.common_chat enable row level security;

-- Users
drop policy if exists users_select_authenticated on public.users;
create policy users_select_authenticated on public.users
for select to authenticated using ((select auth.uid()) is not null);
drop policy if exists users_update_self_or_admin on public.users;
create policy users_update_self_or_admin on public.users
for update to authenticated
using (id = (select auth.uid()) or (select public.is_admin()))
with check (id = (select auth.uid()) or (select public.is_admin()));
drop policy if exists users_delete_admin on public.users;
create policy users_delete_admin on public.users
for delete to authenticated using ((select public.is_admin()));

-- Batches and student profiles
drop policy if exists batches_select_authenticated on public.batches;
create policy batches_select_authenticated on public.batches
for select to authenticated using ((select auth.uid()) is not null);
drop policy if exists batches_admin_write on public.batches;
create policy batches_admin_write on public.batches
for all to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

drop policy if exists student_profiles_select_self_or_admin on public.student_profiles;
create policy student_profiles_select_self_or_admin on public.student_profiles
for select to authenticated
using (user_id = (select auth.uid()) or (select public.is_admin()));
drop policy if exists student_profiles_admin_write on public.student_profiles;
create policy student_profiles_admin_write on public.student_profiles
for all to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

-- Faculty directory and timetable
drop policy if exists faculty_directory_select_authenticated on public.faculty_directory;
create policy faculty_directory_select_authenticated on public.faculty_directory
for select to authenticated using ((select auth.uid()) is not null);
drop policy if exists faculty_directory_admin_write on public.faculty_directory;
create policy faculty_directory_admin_write on public.faculty_directory
for all to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

drop policy if exists class_routine_select_authenticated on public.class_routine;
create policy class_routine_select_authenticated on public.class_routine
for select to authenticated using ((select auth.uid()) is not null);
drop policy if exists class_routine_admin_write on public.class_routine;
create policy class_routine_admin_write on public.class_routine
for all to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

drop policy if exists department_routines_select_authenticated on public.department_routines;
create policy department_routines_select_authenticated on public.department_routines
for select to authenticated using ((select auth.uid()) is not null);
drop policy if exists department_routines_admin_write on public.department_routines;
create policy department_routines_admin_write on public.department_routines
for all to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

-- Notices
drop policy if exists notices_select_relevant on public.notices;
create policy notices_select_relevant on public.notices
for select to authenticated
using (
  (select public.is_admin())
  or (select public.is_teacher())
  or batch_id is null
  or batch_id = (select public.current_student_batch_id())
);
drop policy if exists notices_insert_authorized on public.notices;
create policy notices_insert_authorized on public.notices
for insert to authenticated
with check (
  author_id = (select auth.uid())
  and (
    (select public.is_admin())
    or (select public.is_teacher())
    or (
      is_cr_notice
      and (select public.is_cr())
      and batch_id = (select public.current_student_batch_id())
    )
  )
);
drop policy if exists notices_delete_author_or_admin on public.notices;
create policy notices_delete_author_or_admin on public.notices
for delete to authenticated
using (author_id = (select auth.uid()) or (select public.is_admin()));

drop policy if exists department_notices_select_authenticated on public.department_notices;
create policy department_notices_select_authenticated on public.department_notices
for select to authenticated using ((select auth.uid()) is not null);
drop policy if exists department_notices_admin_write on public.department_notices;
create policy department_notices_admin_write on public.department_notices
for all to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

drop policy if exists class_tests_select_relevant on public.class_tests;
create policy class_tests_select_relevant on public.class_tests
for select to authenticated
using (public.can_access_batch_label(batch));
drop policy if exists class_tests_insert_cr_or_admin on public.class_tests;
create policy class_tests_insert_cr_or_admin on public.class_tests
for insert to authenticated
with check (
  (
    (select public.is_admin())
    or (
      (select public.is_cr())
      and public.can_access_batch_label(batch)
    )
  )
  and (created_by is null or created_by = (select auth.uid()))
);
drop policy if exists class_tests_update_cr_or_admin on public.class_tests;
create policy class_tests_update_cr_or_admin on public.class_tests
for update to authenticated
using (
  (select public.is_admin())
  or ((select public.is_cr()) and public.can_access_batch_label(batch))
)
with check (
  (select public.is_admin())
  or ((select public.is_cr()) and public.can_access_batch_label(batch))
);
drop policy if exists class_tests_delete_cr_or_admin on public.class_tests;
create policy class_tests_delete_cr_or_admin on public.class_tests
for delete to authenticated
using (
  (select public.is_admin())
  or ((select public.is_cr()) and public.can_access_batch_label(batch))
);

-- Department resource vault
drop policy if exists academic_resources_select_authenticated on public.academic_resources;
create policy academic_resources_select_authenticated on public.academic_resources
for select to authenticated using ((select auth.uid()) is not null);
drop policy if exists academic_resources_insert_staff_or_cr on public.academic_resources;
create policy academic_resources_insert_staff_or_cr on public.academic_resources
for insert to authenticated
with check (
  (select public.is_admin())
  or (select public.is_teacher())
  or (select public.is_cr())
);
drop policy if exists academic_resources_update_staff_or_uploader on public.academic_resources;
create policy academic_resources_update_staff_or_uploader on public.academic_resources
for update to authenticated
using (
  (select public.is_admin())
  or (select public.is_teacher())
  or uploader_id = (select auth.uid())
)
with check (
  (select public.is_admin())
  or (select public.is_teacher())
  or uploader_id = (select auth.uid())
);
drop policy if exists academic_resources_delete_staff_or_uploader on public.academic_resources;
create policy academic_resources_delete_staff_or_uploader on public.academic_resources
for delete to authenticated
using (
  (select public.is_admin())
  or (select public.is_teacher())
  or uploader_id = (select auth.uid())
);

-- Attendance. QR check-ins are written by the SECURITY DEFINER RPC above.
drop policy if exists attendance_select_owner_or_staff on public.attendance;
create policy attendance_select_owner_or_staff on public.attendance
for select to authenticated
using (
  student_id = (select auth.uid())
  or (select public.is_admin())
  or (select public.is_teacher())
);
drop policy if exists attendance_staff_insert on public.attendance;
create policy attendance_staff_insert on public.attendance
for insert to authenticated
with check (
  (select public.is_admin())
  or (select public.is_teacher())
);
drop policy if exists attendance_staff_update on public.attendance;
create policy attendance_staff_update on public.attendance
for update to authenticated
using ((select public.is_admin()) or (select public.is_teacher()))
with check ((select public.is_admin()) or (select public.is_teacher()));

drop policy if exists attendance_sessions_select_staff on public.attendance_sessions;
create policy attendance_sessions_select_staff on public.attendance_sessions
for select to authenticated
using ((select public.is_admin()) or (select public.is_teacher()));
drop policy if exists attendance_sessions_staff_write on public.attendance_sessions;
create policy attendance_sessions_staff_write on public.attendance_sessions
for all to authenticated
using ((select public.is_admin()) or (select public.is_teacher()))
with check ((select public.is_admin()) or (select public.is_teacher()));

drop policy if exists attendance_records_select_owner_or_staff on public.attendance_records;
create policy attendance_records_select_owner_or_staff on public.attendance_records
for select to authenticated
using (
  student_id = (select auth.uid())
  or (select public.is_admin())
  or (select public.is_teacher())
);
drop policy if exists attendance_records_staff_write on public.attendance_records;
create policy attendance_records_staff_write on public.attendance_records
for all to authenticated
using ((select public.is_admin()) or (select public.is_teacher()))
with check ((select public.is_admin()) or (select public.is_teacher()));

-- Chat scope is enforced at the database, not just by client-side navigation.
drop policy if exists common_chat_select_scope on public.common_chat;
create policy common_chat_select_scope on public.common_chat
for select to authenticated
using (
  (select public.is_admin())
  or (
    chat_scope = 'department'
    and ((select public.is_student()) or (select public.is_cr()))
  )
  or (
    chat_scope = 'batch'
    and batch_id = (select public.current_student_batch_id())
    and ((select public.is_student()) or (select public.is_cr()))
  )
  or (
    chat_scope = 'cr'
    and ((select public.is_cr()) or (select public.is_admin()))
  )
);
drop policy if exists common_chat_insert_scope on public.common_chat;
create policy common_chat_insert_scope on public.common_chat
for insert to authenticated
with check (
  sender_id = (select auth.uid())
  and (
    (select public.is_admin())
    or (
      (select public.is_student())
      and chat_scope = 'department'
    )
    or (
      (select public.is_student())
      and chat_scope = 'batch'
      and batch_id = (select public.current_student_batch_id())
    )
    or (
      (select public.is_cr())
      and chat_scope = 'cr'
    )
  )
);
drop policy if exists common_chat_update_visible on public.common_chat;
create policy common_chat_update_visible on public.common_chat
for update to authenticated
using (
  (select public.is_admin())
  or sender_id = (select auth.uid())
  or (
    chat_scope = 'department'
    and ((select public.is_student()) or (select public.is_cr()))
  )
  or (
    chat_scope = 'batch'
    and batch_id = (select public.current_student_batch_id())
    and ((select public.is_student()) or (select public.is_cr()))
  )
  or (chat_scope = 'cr' and (select public.is_cr()))
)
with check (
  (select public.is_admin())
  or sender_id = (select auth.uid())
  or (
    chat_scope = 'department'
    and ((select public.is_student()) or (select public.is_cr()))
  )
  or (
    chat_scope = 'batch'
    and batch_id = (select public.current_student_batch_id())
    and ((select public.is_student()) or (select public.is_cr()))
  )
  or (chat_scope = 'cr' and (select public.is_cr()))
);
drop policy if exists common_chat_delete_sender_or_admin on public.common_chat;
create policy common_chat_delete_sender_or_admin on public.common_chat
for delete to authenticated
using (sender_id = (select auth.uid()) or (select public.is_admin()));

-- Table privileges are necessary in addition to RLS policies.
grant usage on schema public to authenticated;
grant select, update, delete on public.users to authenticated;
grant select, insert, update, delete on public.batches to authenticated;
grant select, insert, update, delete on public.student_profiles to authenticated;
grant select, insert, update, delete on public.faculty_directory to authenticated;
grant select, insert, update, delete on public.class_routine to authenticated;
grant select, insert, update, delete on public.department_routines to authenticated;
grant select, insert, delete on public.notices to authenticated;
grant select, insert, update, delete on public.department_notices to authenticated;
grant select, insert, update, delete on public.class_tests to authenticated;
grant select, insert, update, delete on public.academic_resources to authenticated;
grant select, insert, update on public.attendance to authenticated;
grant select, insert, update, delete on public.attendance_sessions to authenticated;
grant select, insert, update, delete on public.attendance_records to authenticated;
grant select, insert, delete on public.common_chat to authenticated;
grant update (message, is_edited, reactions) on public.common_chat to authenticated;

-- Realtime streams in the app require these tables to be in supabase_realtime.
alter table public.common_chat replica identity full;
alter table public.department_routines replica identity full;
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'common_chat'
    ) then
      alter publication supabase_realtime add table public.common_chat;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'department_routines'
    ) then
      alter publication supabase_realtime add table public.department_routines;
    end if;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Storage: chat_attachments
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit)
values ('chat_attachments', 'chat_attachments', true, 52428800)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit;

drop policy if exists chat_attachments_public_read on storage.objects;
create policy chat_attachments_public_read on storage.objects
for select to public
using (bucket_id = 'chat_attachments');

drop policy if exists chat_attachments_authenticated_upload on storage.objects;
create policy chat_attachments_authenticated_upload on storage.objects
for insert to authenticated
with check (
  bucket_id = 'chat_attachments'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or (
      (select public.is_admin())
      and (storage.foldername(name))[1] = 'notices'
    )
  )
);

drop policy if exists chat_attachments_owner_or_admin_update on storage.objects;
create policy chat_attachments_owner_or_admin_update on storage.objects
for update to authenticated
using (
  bucket_id = 'chat_attachments'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or (
      (select public.is_admin())
      and (storage.foldername(name))[1] = 'notices'
    )
  )
)
with check (
  bucket_id = 'chat_attachments'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or (
      (select public.is_admin())
      and (storage.foldername(name))[1] = 'notices'
    )
  )
);

drop policy if exists chat_attachments_owner_or_admin_delete on storage.objects;
create policy chat_attachments_owner_or_admin_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'chat_attachments'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or (
      (select public.is_admin())
      and (storage.foldername(name))[1] = 'notices'
    )
  )
);

-- ---------------------------------------------------------------------------
-- First administrator setup (run manually after creating the Auth user):
--
-- update public.users set role = 'admin' where email = 'your-admin@example.com';
--
-- Auth user creation must happen via the Supabase Dashboard or a trusted
-- server-side Edge Function. Never put the service_role key in the Flutter app.
-- The current client-side signUp onboarding calls cannot safely grant roles or
-- create other users under these RLS policies.
--
-- QR SECURITY WARNING:
-- mark_qr_attendance intentionally matches the current Flutter payload format.
-- QRTokenHelper embeds ICE_SECURE_QR_2026 in the client application, so that
-- value is public and the resulting SHA-256 value is forgeable. Do not treat
-- this compatibility RPC as anti-proxy protection for production attendance.
-- Replace QR signing with a server-generated short-lived challenge or a
-- server-held HMAC secret before relying on it for security-sensitive records.
