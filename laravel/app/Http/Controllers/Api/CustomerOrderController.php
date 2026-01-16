<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CustomerOrder;
use Illuminate\Http\Request;
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
