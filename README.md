# ICE Department App

A Flutter application for academic and departmental workflows in the Department of Information and Communication Engineering (ICE). It provides separate experiences for students, faculty, and clerks/administrators, backed by Supabase.

## Features

- **Students:** department notices and class tests, batch routines, academic resources, batch/dept/CR chat, and QR attendance check-in.
- **Faculty:** teaching schedule, dynamic QR and manual attendance, attendance history with CSV export, CR inbox, and course resource uploads.
- **Clerks / administrators:** batch lifecycle management, student and faculty records, department notices, and routine uploads.
- **Shared:** Supabase sign-in, mandatory first-login password changes, light/dark/system themes, and Android share-to-chat for shared text and links.
- **Resources:** semester- and subject-based department materials, PDF viewing, pinned quick access, and personal PDF notes stored locally on the device.

Student access to the CR chat depends on the student's CR status. Teachers are directed away from chat routes.

## Technology

- Flutter and Dart (`>=3.2.0 <4.0.0`)
- Supabase Auth, Postgres, Realtime, and Storage
- `go_router` for navigation and role-aware redirects
- Provider for app state, and `shared_preferences` for local preferences and notes

The checked-in project is configured for Android and Flutter web. An iOS project is not included in this repository.

## Prerequisites

- Flutter SDK with Dart 3.2 or later, and a working `flutter` command
- Android SDK/toolchain to run or build the Android app
- Chrome (or another supported browser) to run the web app locally
- A Supabase project configured with the database, Auth, Storage, and access policies described below

## Getting started

1. Get the Flutter dependencies:

   ```sh
   flutter pub get
   ```

2. Create the environment asset from the example file.

   Windows PowerShell:

   ```powershell
   Copy-Item .env.example .env
   ```

   macOS / Linux:

   ```sh
   cp .env.example .env
   ```

3. Edit `.env` and set the Supabase project URL and **publishable/anon key**:

   ```dotenv
   SUPABASE_URL=https://your-project-ref.supabase.co
   SUPABASE_ANON_KEY=your-supabase-anon-key
   ```

   `.env` is git-ignored and bundled as a Flutter asset. Values in a client app are not secret: never put a Supabase `service_role` key in this file. Protect data with correctly configured Supabase Row Level Security (RLS) policies.

4. In a **new Supabase project**, open **SQL Editor**, paste the contents of [`supabase/setup.sql`](./supabase/setup.sql), and run it. It creates the tables used by the app, basic indexes, role-aware Row Level Security policies, the `mark_qr_attendance` RPC, the `chat_attachments` Storage bucket and its policies, and Realtime publication entries. The script seeds Batch 21 and the faculty directory. It is an initial setup script, not a migration for an existing project.

5. Create the first administrator account in Supabase **Authentication**, then promote it in SQL Editor:

   ```sql
   update public.users
   set role = 'admin'
   where email = 'your-admin@example.com';
   ```

   The database creates a basic `public.users` row for new Auth users; new accounts default to the `student` role. Assign roles and create accounts through Supabase's trusted admin tools or a server-side Edge Function. Do not enable public sign-up or put the Supabase `service_role` key in the Flutter app. The current client-side onboarding methods call `auth.signUp` directly, so they cannot safely create other users or assign teacher/admin roles under these policies; onboarding through the app needs a trusted server-side function.

6. Add each student's `student_profiles` row with their Auth user ID, batch ID, roll number, CR status, and current semester. Add batch records as needed. Sign in using a provisioned account after its role and profile are configured.

**QR attendance security:** the SQL RPC is compatible with the current app's QR format, but the signing salt is embedded in the Flutter client. That makes the signature forgeable; this is not production-grade anti-proxy protection. Replace the client-side signature with a short-lived server-generated challenge or server-held secret before relying on QR attendance for security-sensitive records.

## Run and build

Run on a connected Android device or emulator:

```sh
flutter run
```

Run in Chrome:

```sh
flutter run -d chrome
```

Create release builds:

```sh
flutter build apk --release
flutter build web --release
```

The web build is written to `build/web`. The included `vercel.json` configures a web release build and single-page-app routing; its build command expects Flutter at `flutter/bin/flutter`, so adjust it if your deployment environment installs Flutter elsewhere.

## Tests and static analysis

Run the test suite and analyzer from the repository root:

```sh
flutter test
flutter analyze
```

Tests cover QR token generation/parsing, models and helpers, academic progression and routine handling, local preferences, and faculty/teacher UI workflows.

## Project layout

```text
lib/
  core/       App routes, theme, constants, and shared helpers
  features/   Resource library, subject materials, and PDF viewing
  models/     Typed application and Supabase data models
  screens/    Admin, teacher, student, authentication, and chat screens
  services/   Supabase access, authentication, attendance, chat, and local state
  utils/      Routine, academic progression, and platform-specific CSV helpers
  widgets/    Reusable UI components
test/         Unit and widget tests
supabase/     Initial Supabase schema, policies, storage, and RPC setup
android/      Android runner and platform configuration
web/          Flutter web entry point and web app assets
```
