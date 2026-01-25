<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Invoice;
use Illuminate\Http\Request;
use Barryvdh\DomPDF\Facade\Pdf;

class InvoiceController extends Controller
{
    /**
     * ✅ PRIVATE: List invoice (butuh login)
     */
    public function index()
    {
        return Invoice::with('armada')->latest()->get();
    }

    /**
     * ✅ PRIVATE: Store invoice
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'order_id' => 'nullable|exists:customer_orders,id',
            'no_invoice' => 'required|string|unique:invoices,no_invoice',
            'nama_pelanggan' => 'required|string',
            'email' => 'required|string',
            'no_telp' => 'required|string',
            'tanggal' => 'required|date',
            'due_date' => 'required|date',

            'status' => 'required|string',
            'diterima_oleh' => 'required|string',

            // ✅ rincian wajib
            'rincian' => 'required|array|min:1',
            'rincian.*.lokasi_muat' => 'required|string',
            'rincian.*.lokasi_bongkar' => 'required|string',
            'rincian.*.armada_id' => 'required|exists:armadas,id',
            'rincian.*.armada_start_date' => 'required|date',
            'rincian.*.armada_end_date' => 'required|date',
            'rincian.*.tonase' => 'required|numeric|gt:0',
            'rincian.*.harga' => 'required|numeric|gt:0',

            // total hitungan
            'total_biaya' => 'required|numeric|gte:0',
            'pph' => 'required|numeric|gte:0',
            'total_bayar' => 'required|numeric|gte:0',
        ]);

        // ✅ biar tetap konsisten simpan data utama dari rincian pertama juga
        $first = $validated['rincian'][0];

        $validated['lokasi_muat'] = $first['lokasi_muat'];
        $validated['lokasi_bongkar'] = $first['lokasi_bongkar'];
        $validated['armada_id'] = $first['armada_id'];
        $validated['armada_start_date'] = $first['armada_start_date'];
        $validated['armada_end_date'] = $first['armada_end_date'];
        $validated['tonase'] = $first['tonase'];
        $validated['harga'] = $first['harga'];

        $invoice = Invoice::create($validated);

        return $invoice->load('armada');
    }

    /**
     * ✅ PRIVATE: Show invoice by id (butuh login)
     */
    public function show($id)
    {
        $invoice = Invoice::with('armada')->findOrFail($id);

        if (!is_array($invoice->rincian)) {
            $invoice->rincian = $invoice->rincian ? json_decode($invoice->rincian, true) : [];
        }

        return $invoice;
    }

    /**
     * ✅ PRIVATE: Update invoice
     */
    public function update(Request $request, $id)
    {
        $invoice = Invoice::findOrFail($id);

        $validated = $request->validate([
            'order_id' => 'nullable|exists:customer_orders,id',
            'no_invoice' => 'required|string|unique:invoices,no_invoice,' . $invoice->id,
            'nama_pelanggan' => 'required|string',
            'email' => 'required|string',
            'no_telp' => 'required|string',
            'tanggal' => 'required|date',
            'due_date' => 'required|date',

            'status' => 'required|string',
            'diterima_oleh' => 'required|string',

            // ✅ rincian wajib
            'rincian' => 'required|array|min:1',
            'rincian.*.lokasi_muat' => 'required|string',
            'rincian.*.lokasi_bongkar' => 'required|string',
            'rincian.*.armada_id' => 'required|exists:armadas,id',
            'rincian.*.armada_start_date' => 'required|date',
            'rincian.*.armada_end_date' => 'required|date',
            'rincian.*.tonase' => 'required|numeric|gt:0',
            'rincian.*.harga' => 'required|numeric|gt:0',

            // total hitungan
            'total_biaya' => 'required|numeric|gte:0',
            'pph' => 'required|numeric|gte:0',
            'total_bayar' => 'required|numeric|gte:0',
        ]);

        $first = $validated['rincian'][0];

        $validated['lokasi_muat'] = $first['lokasi_muat'];
        $validated['lokasi_bongkar'] = $first['lokasi_bongkar'];
        $validated['armada_id'] = $first['armada_id'];
        $validated['armada_start_date'] = $first['armada_start_date'];
        $validated['armada_end_date'] = $first['armada_end_date'];
        $validated['tonase'] = $first['tonase'];
        $validated['harga'] = $first['harga'];

        $invoice->update($validated);

        return $invoice->load('armada');
    }

    /**
     * ✅ PRIVATE: Delete invoice
     */
    public function destroy($id)
    {
        $invoice = Invoice::findOrFail($id);
        $invoice->delete();

        return response()->json(['message' => 'Invoice deleted']);
    }

    /**
     * ✅ PRIVATE PDF (untuk internal dashboard)
     * URL: /api/invoices/{id}/pdf (butuh login)
     */
    public function pdf($id)
    {
        $invoice = Invoice::with('armada')->findOrFail($id);

        if (!is_array($invoice->rincian)) {
            $invoice->rincian = $invoice->rincian ? json_decode($invoice->rincian, true) : [];
        }

        if (!view()->exists('invoices.invoice')) {
            return response()->json([
                'message' => 'Template PDF tidak ditemukan: resources/views/invoices/invoice.blade.php'
            ], 500);
        }

        $pdf = Pdf::loadView('invoices.invoice', [
            'invoice' => $invoice
        ]);

        return $pdf->stream("invoice-{$invoice->no_invoice}.pdf");
    }

    /**
     * ✅ ✅ ✅ PUBLIC SHOW (TANPA LOGIN)
     * URL: /api/public/invoices/{id}
     */
    public function publicShow($id)
    {
        $invoice = Invoice::with('armada')->find($id);

        if (!$invoice) {
            return response()->json(['message' => 'Invoice tidak ditemukan'], 404);
        }

        $rin = $invoice->rincian;

        if (!is_array($rin)) {
            $rin = $rin ? json_decode($rin, true) : [];
            if (!is_array($rin)) $rin = [];
        }

        if (is_array($rin) && count($rin) > 0) {
            foreach ($rin as $idx => $r) {
                if (!is_array($r)) continue;

                $hasPlat = isset($r['armada_plat']) && trim((string)$r['armada_plat']) !== '';
                $hasNestedArmadaPlat = isset($r['armada']['plat_nomor']) && trim((string)$r['armada']['plat_nomor']) !== '';

                if (!$hasPlat && !$hasNestedArmadaPlat && isset($r['armada_id'])) {
                    $armada = \App\Models\Armada::find($r['armada_id']);
                    $r['armada_plat'] = $armada ? $armada->plat_nomor : '-';
                }

                $rin[$idx] = $r;
            }
        }

        $invoice->rincian = $rin;

        return response()->json($invoice);
    }

    /**
     * ✅ ✅ ✅ PUBLIC PDF (TANPA LOGIN)
     * URL: /api/public/invoices/{id}/pdf
     */
    public function publicPdf($id)
    {
        try {
            $invoice = Invoice::with('armada')->find($id);

            if (!$invoice) {
                return response()->json(['message' => 'Invoice tidak ditemukan'], 404);
            }

            $rin = $invoice->rincian;

            if (!is_array($rin)) {
                $rin = $rin ? json_decode($rin, true) : [];
                if (!is_array($rin)) $rin = [];
            }

            $invoice->rincian = $rin;

            if (!view()->exists('invoices.invoice')) {
                return response()->json([
                    'message' => 'Template PDF tidak ditemukan: resources/views/invoices/invoice.blade.php'
                ], 500);
            }

            @mkdir(storage_path('app/dompdf'), 0777, true);
            @mkdir(storage_path('app/dompdf/fonts'), 0777, true);

            $pdf = Pdf::loadView('invoices.invoice', [
                'invoice' => $invoice,
            ]);

            $pdf->setOption('isRemoteEnabled', true);
            $pdf->setOption('tempDir', sys_get_temp_dir());
            $pdf->setOption('fontDir', storage_path('app/dompdf/fonts'));
            $pdf->setOption('fontCache', storage_path('app/dompdf/fonts'));
            $pdf->setPaper('a4', 'landscape');

            return $pdf->stream("invoice-{$invoice->no_invoice}.pdf");
        } catch (\Throwable $e) {
            return response()->json([
                'message' => 'Gagal generate PDF',
                'error' => $e->getMessage(),
                'file' => $e->getFile(),
                'line' => $e->getLine(),
            ], 500);
        }
    }

    /**
     * ✅ ✅ ✅ PUBLIC PDF LINK (TANPA LOGIN)
     * URL: /api/public/invoices/{id}/pdf-link
     */
    public function publicPdfLink($id)
    {
        $invoice = Invoice::findOrFail($id);

        $base = rtrim(config('app.url'), '/');

        return response()->json([
            'url' => "{$base}/api/public/invoices/{$invoice->id}/pdf"
        ]);
    }
}
