# Making the Nutrition Register sync across devices (Supabase setup)

## Why this is needed
GitHub Pages only serves static files — it has no database of its own. Without a real
backend, the app falls back to your browser's `localStorage`, which is private to one
device/browser. That's why records created on your laptop don't show up on your phone.

Supabase gives the app a free, hosted Postgres database it can talk to directly from the
browser, so every device sees the same facility-wide records — exactly like a real HMIS.

This setup keeps the app's existing sign-up/sign-in flow (it just moves the same data into
a shared cloud table instead of local-only storage). Total time: about 5 minutes.

---

## 1. Create a Supabase project
1. Go to https://supabase.com → **Start your project** → sign in (free tier is enough).
2. **New project** → pick a name (e.g. `nut-register`) and a database password (save it
   somewhere safe — you won't need it for this app, but keep it anyway) → **Create**.
3. Wait ~2 minutes for provisioning.

## 2. Create the storage table
1. In your project, open the **SQL Editor** (left sidebar).
2. Paste and run this:

```sql
create table if not exists public.nutreg_kv (
  key         text primary key,
  value       text not null,
  updated_at  timestamptz default now()
);

-- Row Level Security: required by Supabase before the anon key can read/write.
-- This prototype keeps auth inside the app itself (as before), so we allow the
-- anon key full access to this one table only.
alter table public.nutreg_kv enable row level security;

create policy "Allow anon read" on public.nutreg_kv
  for select using (true);

create policy "Allow anon write" on public.nutreg_kv
  for insert with check (true);

create policy "Allow anon update" on public.nutreg_kv
  for update using (true);

create policy "Allow anon delete" on public.nutreg_kv
  for delete using (true);
```

> **Security note:** these policies make the table world-readable/writable by anyone who
> has your anon key (which is visible in the deployed HTML — that's unavoidable for a pure
> static-site setup). That's an acceptable tradeoff for a prototype/pilot with non-sensitive
> or de-identified test data, but **before handling real patient data**, add a real backend
> (Supabase Edge Functions or your own API) that enforces the role-permission matrix in the
> spec (§4) server-side, and switch to Supabase Auth with row-level policies scoped per
> facility. Flag this to whoever signs off on production readiness.

## 3. Get your API keys
1. **Project Settings** (gear icon) → **API**.
2. Copy the **Project URL** and the **anon public** key.

## 4. Add the keys to the app
Open `nut_register_system.html`, find near the top of the `<script>` block:

```js
const SUPABASE_URL = 'https://whztbwotyxxxevkabawl.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_YFk7dqcUdP8Lqx5FKgS04w_YnMFLMIO';
```

Replace both placeholder strings with the values from step 3, save, and re-deploy
(commit + push to GitHub as usual).

## 5. Confirm it's working
Open the deployed site. A small dot next to the app name in the top bar shows storage
status:
- 🟢 green = connected to Supabase — records sync across devices.
- 🟠 orange = local-only mode — either the keys aren't filled in yet, or the browser
  couldn't reach Supabase (offline, ad-blocker, or wrong keys).

Create a test enrolment on one device/browser, then open the same URL on another device —
it should appear in the Clients list there too.

## If you'd rather use the full relational schema
`nut_register_database_schema.sql` (already in this project) is a properly normalised
Postgres schema — `clients`, `enrolments`, `visits`, `exits`, lookup tables, etc. The setup
above uses one simple key-value table instead, so it could be dropped in **without changing
any of the existing form/validation/report logic**, which is the safest fix given the app
was already written and tested against a key-value storage contract.

If/when you want proper relational tables (for direct SQL reporting, DHIS2/FHIR export
jobs, etc. per §6 of the spec), that's a separate follow-up: it means running
`nut_register_database_schema.sql` in Supabase as-is, then rewriting the app's data-access
functions (`loadAllClients`, `saveDraft`, and the report generators) to read/write those
tables via Supabase's REST API instead of the `client:<id>` JSON blobs. Happy to do that
next if you want it — just say the word.
