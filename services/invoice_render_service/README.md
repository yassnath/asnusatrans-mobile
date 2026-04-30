# Invoice Render Service

Service ini merender tabel invoice dari template Excel yang sama dengan desktop, lalu mengembalikan hasilnya sebagai PDF untuk dipakai mobile app.

Catatan penting: untuk output invoice mobile yang dikunci 100% sama dengan Windows, gunakan service Windows di `tooling/windows/invoice_render_service.dart`. Service Python/LibreOffice di folder ini hanya renderer kompatibel untuk environment tanpa Excel, sehingga tidak diterima oleh mobile app saat mode exact aktif.

## Endpoint

- `GET /health`
- `POST /render-table`

Payload `POST /render-table`:

```json
{
  "rowCount": 13,
  "renderMode": "table_with_summary",
  "rows": [
    {
      "no": "1",
      "tanggal": "3-Mar-26",
      "plat": "W 8045 UD",
      "muatan": "Batubara",
      "muat": "T. Langon",
      "bongkar": "Pare",
      "tonase": "34.070",
      "harga": "58,0",
      "total": "1.976.060"
    }
  ],
  "summaryValues": {
    "subtotal": "1.976.060",
    "pph": "39.521",
    "total": "1.936.538"
  }
}
```

## Local run

Install dependencies:

```bash
pip install -r services/invoice_render_service/requirements.txt
```

Jalankan:

```bash
uvicorn services.invoice_render_service.app:app --host 0.0.0.0 --port 8080
```

Catatan:
- Service ini membutuhkan `LibreOffice` / `soffice` tersedia di environment.
- Kalau binary berbeda, set env `SOFFICE_BINARY`.

## Docker build

```bash
docker build -f services/invoice_render_service/Dockerfile -t cvant-invoice-render .
docker run -p 8080:8080 cvant-invoice-render
```

## Flutter APK

Build APK dengan URL service Windows Excel atau proxy HTTPS yang tetap memakai renderer Windows Excel:

```bash
flutter build apk --dart-define=INVOICE_RENDER_SERVICE_URL=https://your-render-service.example.com
```

Untuk service LAN Windows berbasis Excel, gunakan URL IP Windows dan aktifkan izin HTTP khusus render invoice:

```bash
flutter build apk --dart-define=INVOICE_RENDER_SERVICE_URL=http://192.168.1.10:8787 --dart-define=INVOICE_RENDER_SERVICE_ALLOW_HTTP=true
```

Catatan penting:
- Output invoice Windows adalah acuan tetap.
- Mobile app tidak lagi fallback ke renderer portable untuk invoice, supaya layout tabel tetap sama dengan Windows.
- Untuk invoice mobile exact, service harus mengembalikan `renderer: windows-excel-com` dan `exactWindowsInvoiceOutput: true` dari `/health`.
- Jika service tidak tersedia atau bukan renderer Windows Excel, print invoice mobile akan berhenti dengan pesan konfigurasi, bukan menghasilkan layout yang berbeda.
- Output laporan dibuat dari PDF app yang sama di semua platform, sehingga tidak memakai renderer alternatif per-platform.
