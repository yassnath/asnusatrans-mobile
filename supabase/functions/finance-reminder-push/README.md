## finance-reminder-push

Edge Function untuk mengirim ringkasan pemasukkan/pengeluaran CV dan pribadi ke role `owner` dan `admin`.

Jadwal yang dipakai:

- Mingguan: setiap Minggu pukul 17.00 WIB, periode Senin-Minggu.
- Bulanan: setiap hari terakhir bulan pukul 17.00 WIB.

Secrets yang dibutuhkan:

```bash
npx supabase secrets set \
  FINANCE_REMINDER_CRON_SECRET=isi-secret-kuat \
  FIREBASE_PROJECT_ID=your-firebase-project-id \
  FIREBASE_CLIENT_EMAIL=your-firebase-client-email \
  FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

Deploy:

```bash
npx supabase functions deploy finance-reminder-push --project-ref msziutqvkrbwwohcdoou --use-api
```

Pastikan secret cron diset dan nilainya sama dengan yang dipakai di SQL cron:

```bash
npx supabase secrets set FINANCE_REMINDER_CRON_SECRET=isi-secret-kuat --project-ref msziutqvkrbwwohcdoou
```

Manual test dengan user JWT admin/owner:

```bash
curl -X POST "https://msziutqvkrbwwohcdoou.supabase.co/functions/v1/finance-reminder-push" \
  -H "Authorization: Bearer <ADMIN_OR_OWNER_ACCESS_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"type":"monthly","now":"2026-04-30T10:00:00.000Z"}'
```

Untuk mengaktifkan cron, jalankan SQL patch:

`supabase/patch_finance_reminder_push_cron_20260529.sql`

Sebelum run patch, ganti `GANTI_DENGAN_FINANCE_REMINDER_CRON_SECRET` dengan
value `FINANCE_REMINDER_CRON_SECRET` yang sama. Setelah patch berhasil:

```sql
select jobid, jobname, schedule, active
from cron.job
where jobname like 'cvant_finance_reminder_%';

select public.trigger_finance_reminder_push('weekly');
select public.trigger_finance_reminder_push('monthly');
```
