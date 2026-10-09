# Supabase test backend setup

This migration prepares a private test backend for online game submissions.
The local Godot developer dashboard has a test connection panel that uses the
project URL and publishable key; no secret/service-role key belongs in LOOP.

## Apply to the development project

1. In Supabase, open **SQL Editor** and choose **New query**.
2. Open `supabase/migrations/0001_loop_test.sql` from this repository, copy the
   whole file into the editor, and click **Run**.
3. Confirm the migration created `loop_games`, `loop_game_versions`,
   `loop_reviews`, `loop_comments`, `loop_user_roles`, and a private
   `loop-game-packages` Storage bucket.
4. Promote only the reviewer test account. Replace the email below with the
   exact email of your reviewer account, then run this query in SQL Editor:

   ```sql
   insert into public.loop_user_roles(user_id, role)
   select id, 'reviewer' from auth.users where email = 'REVIEWER_EMAIL_HERE'
   on conflict (user_id) do update set role = excluded.role;
   ```

   The developer test account remains `developer`. Assigning roles requires
   the project-owner SQL editor; clients cannot grant themselves roles.
5. In the local Godot build, open **Creator Studio → Developer dashboard →
   Online test server · Supabase**. Enter the Project URL and publishable key,
   test the connection, then sign in with the developer account. Settings are
   saved to `user://loop-supabase.json`; passwords and access tokens are held in
   memory only. Never place a secret/service-role key in the app or in Git.
6. Create a local Arena Studio game, build its `.loopgame` package, and pass
   local Airlock. In the online panel, submit that validated package. Sign out,
   sign in as the reviewer, refresh the queue, approve the version, then publish
   the approved version. Refresh the published catalog to confirm it is visible.

## What this backend schema supports

- User roles default to developer; reviewer/admin roles are assigned by an
  operator.
- Developers can create their own game listings and submit immutable versions
  for review. Packages are stored in a private bucket under the uploader's
  user-ID folder.
- Reviewers can inspect pending versions and approve or reject them through a
  guarded database function. Only approved versions can be published.
- Public catalog reads and package downloads are limited to published versions.
- Comments are shared and require a signed-in user; only visible comments are
  readable publicly.

This is a development schema and test flow, not a production moderation
service. Published records can be read from the online test panel, but they are
not yet merged into the normal Discover feed or launched from server storage.
The local Airlock validates the package before upload; the server does not yet
re-validate ZIP contents. Malware scanning, rate limits, email verification,
appeals, and production audit/incident handling still need implementation
before public submissions.
