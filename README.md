# stitch_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Supabase image storage

The app keeps Firebase for auth/data and uses Supabase Storage only for user
images. Existing local image paths are still displayed for development, but new
uploads require Supabase to be configured.

1. Create a Supabase project.
2. In Storage, create a public bucket named `user-images`.
3. Copy the Project URL and anon public key from Project Settings > API.
4. Add this Storage policy for development uploads:

```sql
create policy "Allow public image uploads"
on storage.objects
for insert
to anon
with check (
  bucket_id = 'user-images'
  and (storage.foldername(name))[1] = 'users'
);
```

Because the app currently authenticates with Firebase, Supabase cannot enforce
per-user Storage rules from the Firebase user id. This anon upload policy is OK
for local development and early testing, but a production version should upload
through a trusted backend/Edge Function or switch images to Supabase Auth.

5. Run the app with:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY `
  --dart-define=SUPABASE_IMAGE_BUCKET=user-images
```

Images are uploaded under:

```text
users/{firebaseUserId}/character-portraits/
users/{firebaseUserId}/journal-entries/
users/{firebaseUserId}/inventory-items/
```
