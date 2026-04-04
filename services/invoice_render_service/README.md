# Invoice Render Service

Service ini merender tabel invoice dari template Excel yang sama dengan desktop, lalu mengembalikan hasilnya sebagai PDF untuk dipakai mobile app.

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

Build APK dengan URL service cloud:

```bash
flutter build apk --dart-define=INVOICE_RENDER_SERVICE_URL=https://your-render-service.example.com
```

Jika `INVOICE_RENDER_SERVICE_URL` diisi, mobile app akan mencoba render tabel invoice lewat service ini sebelum fallback ke renderer template lokal.
