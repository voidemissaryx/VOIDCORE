# VOIDCORE Supabase backend

This directory contains the database migration and Edge Function required by VOIDCORE's
independent user-account system.

## 1. Create a Supabase project

Create a project in the Supabase dashboard. Keep the project URL and publishable/anon key
available for the Flutter app configuration. Never put the service-role key in the app.

## 2. Apply the database migration

Run the SQL in `migrations/202611240001_voidcore_profiles.sql` in the Supabase SQL Editor,
or apply it with the Supabase CLI.

The migration creates:
- `public.profiles` linked to Supabase Auth users
- unique case-insensitive usernames
- row-level security so users can only modify their own profile
- a `profile-avatars` storage bucket with per-user upload permissions

## 3. Configure email verification

In Authentication → Providers → Email, enable email/password sign-in and email confirmation.
Configure the SMTP provider and add `voidcore://auth-callback` to the Redirect URLs allow-list in Authentication → URL Configuration. The Flutter Android app registers this URI scheme and completes the Supabase `token_hash` verification inside the app; do not use `http://localhost:3000` as the redirect target.
The app must not treat a newly registered account as verified until Supabase reports
`email_confirmed_at`.

## 4. Deploy the Cloudflare token verifier

Deploy `functions/validate-cloudflare-token/index.ts` as the
`validate-cloudflare-token` Supabase Edge Function. Keep JWT verification enabled.
The function validates the signed-in user's session and checks the supplied Cloudflare token
against Cloudflare's API. It does not store or log the token.

The Flutter app can then keep the token in Android Keystore via flutter_secure_storage for
the existing on-device Cloudflare operations. Do not store it in profiles or expose it in logs.

## 5. Flutter configuration

Configure the Supabase project URL and publishable/anon key through build-time configuration.
Only the publishable/anon key belongs in the client; never use the service-role key.
