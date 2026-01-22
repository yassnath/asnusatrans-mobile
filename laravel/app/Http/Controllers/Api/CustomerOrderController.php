<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CustomerOrder;
use App\Models\Invoice;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

class CustomerOrderController extends Controller
{
    protected function getCustomer(Request $request)
    {
        return $request->attributes->get('customer');
    }

    protected function generateOrderCode(): string
    {
        do {
            $code = 'ORD-' . strtoupper(Str::random(6));
        } while (CustomerOrder::where('order_code', $code)->exists());

        return $code;
    }

    protected function generateInvoiceNumber(): string
    {
        $now = now();
        $prefix = 'INC-' . $now->format('m') . '-' . $now->format('Y') . '-';
        $next = Invoice::where('no_invoice', 'like', $prefix . '%')->count() + 1;

        do {
            $number = str_pad((string) $next, 4, '0', STR_PAD_LEFT);
            $code = $prefix . $number;
            $next++;
        } while (Invoice::where('no_invoice', $code)->exists());

        return $code;
    }

    public function index(Request $request)
    {
        $customer = $this->getCustomer($request);
        if (!$customer) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        $query = CustomerOrder::where('customer_id', $customer->id)
            ->orderByDesc('created_at');

        if ($request->boolean('latest')) {
            $order = $query->first();
            return response()->json($order);
        }

        return response()->json($query->get());
    }

    public function store(Request $request)
    {
        $customer = $this->getCustomer($request);
        if (!$customer) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        $data = $request->validate([
            'pickup' => ['required', 'string', 'max:255'],
            'destination' => ['required', 'string', 'max:255'],
            'pickup_date' => ['required', 'date'],
            'pickup_time' => ['required', 'string', 'max:10'],
            'service' => ['required', 'string', 'max:50'],
            'fleet' => ['required', 'string', 'max:50'],
            'cargo' => ['nullable', 'string', 'max:255'],
            'weight' => ['nullable', 'numeric', 'min:0'],
            'distance' => ['nullable', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string', 'max:500'],
            'insurance' => ['nullable', 'boolean'],
            'estimate' => ['required', 'numeric', 'min:0'],
            'insurance_fee' => ['required', 'numeric', 'min:0'],
            'total' => ['required', 'numeric', 'min:0'],
        ]);

        if ($request->has('rincian')) {
            $invoiceValidator = Validator::make($request->all(), [
                'tanggal' => ['required', 'date'],
                'due_date' => ['required', 'date'],
                'nama_pelanggan' => ['required', 'string'],
                'email' => ['required', 'string'],
                'no_telp' => ['required', 'string'],
                'status' => ['required', 'string'],
                'diterima_oleh' => ['required', 'string'],
                'rincian' => ['required', 'array', 'min:1'],
                'rincian.*.lokasi_muat' => ['required', 'string'],
                'rincian.*.lokasi_bongkar' => ['required', 'string'],
                'rincian.*.armada_id' => ['required', 'exists:armadas,id'],
                'rincian.*.armada_start_date' => ['required', 'date'],
                'rincian.*.armada_end_date' => ['required', 'date'],
                'rincian.*.tonase' => ['required', 'numeric', 'gt:0'],
                'rincian.*.harga' => ['required', 'numeric', 'gt:0'],
                'total_biaya' => ['required', 'numeric', 'gte:0'],
                'pph' => ['required', 'numeric', 'gte:0'],
                'total_bayar' => ['required', 'numeric', 'gte:0'],
            ]);

            if ($invoiceValidator->fails()) {
                return response()->json([
                    'message' => 'Validasi invoice gagal.',
                    'errors' => $invoiceValidator->errors(),
                ], 422);
            }

            $invoiceData = $invoiceValidator->validated();
            $invoiceData['no_invoice'] = $this->generateInvoiceNumber();

            $first = $invoiceData['rincian'][0];
            $invoiceData['lokasi_muat'] = $first['lokasi_muat'];
            $invoiceData['lokasi_bongkar'] = $first['lokasi_bongkar'];
            $invoiceData['armada_id'] = $first['armada_id'];
            $invoiceData['armada_start_date'] = $first['armada_start_date'];
            $invoiceData['armada_end_date'] = $first['armada_end_date'];
            $invoiceData['tonase'] = $first['tonase'];
            $invoiceData['harga'] = $first['harga'];

            $subtotal = collect($invoiceData['rincian'])->reduce(function ($sum, $row) {
                $tonase = (float) ($row['tonase'] ?? 0);
                $harga = (float) ($row['harga'] ?? 0);
                return $sum + ($tonase * $harga);
            }, 0);
            $pph = $subtotal * 0.02;
            $invoiceData['total_biaya'] = $subtotal;
            $invoiceData['pph'] = $pph;
            $invoiceData['total_bayar'] = $subtotal - $pph;

            Invoice::create($invoiceData);
        }

        $order = CustomerOrder::create([
            'customer_id' => $customer->id,
            'order_code' => $this->generateOrderCode(),
            'pickup' => $data['pickup'],
            'destination' => $data['destination'],
            'pickup_date' => $data['pickup_date'],
            'pickup_time' => $data['pickup_time'],
            'service' => $data['service'],
            'fleet' => $data['fleet'],
            'cargo' => $data['cargo'] ?? null,
            'weight' => $data['weight'] ?? null,
            'distance' => $data['distance'] ?? null,
            'notes' => $data['notes'] ?? null,
            'insurance' => $data['insurance'] ?? false,
            'estimate' => $data['estimate'],
            'insurance_fee' => $data['insurance_fee'],
            'total' => $data['total'],
            'status' => 'Pending Payment',
        ]);

        return response()->json($order, 201);
    }

    public function show(Request $request, $id)
    {
        $customer = $this->getCustomer($request);
        if (!$customer) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        $order = CustomerOrder::where('customer_id', $customer->id)
            ->where('id', $id)
            ->firstOrFail();

        return response()->json($order);
    }

    public function pay(Request $request, $id)
    {
        $customer = $this->getCustomer($request);
        if (!$customer) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        $data = $request->validate([
            'payment_method' => ['required', 'string', 'max:50'],
        ]);

        $order = CustomerOrder::where('customer_id', $customer->id)
            ->where('id', $id)
            ->firstOrFail();

        $order->status = 'Paid';
        $order->payment_method = $data['payment_method'];
        $order->paid_at = now();
        $order->save();

        return response()->json($order);
    }
}
