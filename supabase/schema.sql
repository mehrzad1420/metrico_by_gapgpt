-- ═══════════════════════════════════════════════════════════════
-- Metrico — Base schema (profiles, projects, activation)
-- Run FIRST in Supabase SQL Editor, then the other scripts in order.
-- Safe to re-run (uses IF NOT EXISTS / OR REPLACE where possible).
-- ═══════════════════════════════════════════════════════════════

-- ─── 1) Profiles ─────────────────────────────────────────────
create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  activated boolean not null default false,
  plan text not null default 'start',
  plan_expires_at timestamptz,
  plan_updated_at timestamptz default now(),
  role text not null default 'user',
  created_at timestamptz not null default now()
);

alter table public.profiles drop constraint if exists profiles_plan_check;
alter table public.profiles
  add constraint profiles_plan_check
  check (plan in ('start', 'plus', 'pro', 'ark'));

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('user', 'super_admin'));

create index if not exists profiles_plan_idx on public.profiles (plan);

-- ─── 2) Projects ─────────────────────────────────────────────
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null default '',
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.projects
  add column if not exists updated_at timestamptz not null default now();

create index if not exists projects_user_id_idx on public.projects (user_id);
create index if not exists projects_user_created_idx on public.projects (user_id, created_at);

create or replace function public.set_projects_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists projects_set_updated_at on public.projects;
create trigger projects_set_updated_at
  before update on public.projects
  for each row execute function public.set_projects_updated_at();

-- ─── 3) Activation codes ─────────────────────────────────────
create table if not exists public.activation_codes (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  used_by uuid references auth.users(id),
  used_at timestamptz,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists activation_codes_code_idx on public.activation_codes (lower(code));

-- ─── 4) Activate account RPC ─────────────────────────────────
create or replace function public.activate_with_code(code_input text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.activation_codes%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if exists (
    select 1 from public.profiles
    where user_id = v_uid and activated = true
  ) then
    return true;
  end if;

  select * into v_row
  from public.activation_codes
  where lower(trim(code)) = lower(trim(code_input))
  for update;

  if not found then
    return false;
  end if;

  if v_row.used_by is not null then
    return false;
  end if;

  update public.activation_codes
  set used_by = v_uid, used_at = now()
  where id = v_row.id;

  update public.profiles
  set activated = true
  where user_id = v_uid;

  if not found then
    insert into public.profiles (user_id, activated, plan, role)
    values (v_uid, true, 'start', 'user');
  end if;

  return true;
end;
$$;

revoke all on function public.activate_with_code(text) from public;
grant execute on function public.activate_with_code(text) to authenticated;

-- ─── 5) Row Level Security ───────────────────────────────────
alter table public.profiles enable row level security;
alter table public.projects enable row level security;
alter table public.activation_codes enable row level security;

grant select, update on table public.profiles to authenticated;
grant select, insert, update, delete on table public.projects to authenticated;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists projects_owner_all on public.projects;
create policy projects_owner_all on public.projects
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- activation_codes: no direct client access (RPC only)

-- ─── 6) Bootstrap profile on signup (fallback if admin-members not run yet) ───
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (user_id, activated, plan, role)
  values (new.id, false, 'start', 'user')
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ─── 7) Backfill existing auth users without profiles ─────────
insert into public.profiles (user_id, activated, plan, role)
select u.id, false, 'start', 'user'
from auth.users u
left join public.profiles p on p.user_id = u.id
where p.user_id is null;

-- ─── Manual: create first activation code ─────────────────────
-- insert into public.activation_codes (code, note) values
--   ('ACT-DEMO-001', 'کد آزمایشی اول');
