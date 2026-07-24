# Supabase setup — Metrico

Run these SQL scripts **in order** in Supabase Dashboard → SQL Editor.

| # | File | Purpose |
|---|------|---------|
| 1 | `schema.sql` | Base tables: `profiles`, `projects`, `activation_codes` + RLS + `activate_with_code` |
| 2 | `plans.sql` | Subscription plans, `plan_codes`, `redeem_plan_code`, payment stub |
| 3 | `admin.sql` | Super-admin role + `admin_list_members`, `admin_set_member_plan` |
| 4 | `admin-members-tools.sql` | Activation/plan code generators from app admin panel |
| 5 | `owner-portals.sql` | Owner portal links (`owner_portals`, `get_owner_portal`) |
| 6 | `owner-portal-messages.sql` | Owner ↔ developer messaging |
| — | `projects-updated-at-fix.sql` | **If saves fail** with `record "new" has no field "updated_at"` |

## After running scripts

1. Set `SUPABASE_URL` and anon key in `index.html` (lines 13–15).
2. Promote your account to super-admin (edit email in `admin.sql` if needed, then re-run the UPDATE block).
3. Create an activation code:
   ```sql
   insert into public.activation_codes (code, note)
   values ('ACT-PILOT-01', 'کاربر آزمایشی');
   ```
4. (Optional) Create plan upgrade codes — see comments at bottom of `plans.sql`.

## Data model

| Table | Contents |
|-------|----------|
| `profiles` | `activated`, `plan`, `role`, expiry dates |
| `projects` | One row per project; JSON in `data` column |
| `activation_codes` | One-time signup activation |
| `plan_codes` | One-time plan upgrade codes |
| `owner_portals` | Public owner portal payloads (token URL) |

Company name, contacts, reminders, and inventory are stored in Supabase Auth `user_metadata` (not separate tables).

## Security notes

- Project data is isolated per user via RLS on `projects`.
- `activation_codes` and admin RPCs use `security definer` — users cannot read codes directly.
- Review `owner_portals` policies if you change public portal behavior.
