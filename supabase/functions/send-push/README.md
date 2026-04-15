## send-push

Edge Function ini mengirim push notification FCM ke token device yang tersimpan
di tabel `public.device_push_tokens`.

### Secrets yang wajib

Set secret berikut di project Supabase:

```bash
supabase secrets set \
  FIREBASE_PROJECT_ID=your-firebase-project-id \
  FIREBASE_CLIENT_EMAIL=your-service-account@your-project.iam.gserviceaccount.com \
  FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, dan `SUPABASE_SERVICE_ROLE_KEY`
dibaca otomatis oleh Edge Function runtime Supabase.

### Deploy

```bash
supabase functions deploy send-push
```

Jika project memakai JWT Signing Keys baru dan request ke function sempat gagal
`Invalid JWT`, deploy dengan konfigurasi `verify_jwt = false` pada
`supabase/config.toml`. Function ini sudah memverifikasi bearer token sendiri di
dalam handler.

### Catatan

- Flutter app juga butuh file Firebase platform:
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`
- Alternatif tanpa file native, app sekarang juga bisa diinisialisasi
  lewat `--dart-define` berikut:
  - `FIREBASE_API_KEY`
  - `FIREBASE_PROJECT_ID`
  - `FIREBASE_MESSAGING_SENDER_ID`
  - `FIREBASE_ANDROID_APP_ID`
  - `FIREBASE_IOS_APP_ID`
  - `FIREBASE_IOS_BUNDLE_ID` (opsional untuk iOS)
  - `FIREBASE_STORAGE_BUCKET` (opsional)
- Android membutuhkan plugin Google Services aktif.
- iOS membutuhkan capability Push Notifications + Background Modes
  `remote-notification`.
