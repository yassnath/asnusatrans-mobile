<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CustomerOrder;
use Illuminate\Http\Request;

class CustomerOrderAdminController extends Controller
{
    public function index(Request $request)
    {
        $orders = CustomerOrder::with(['customer:id,name,email'])
            ->orderByDesc('created_at')
            ->get();

        return response()->json($orders);
    }

    public function updateStatus(Request $request, $id)
    {
        $data = $request->validate([
            'status' => ['required', 'string', 'max:50'],
        ]);

        $allowed = ['Pending Payment', 'Paid', 'Accepted', 'Rejected'];
        if (!in_array($data['status'], $allowed, true)) {
            return response()->json(['message' => 'Status tidak valid.'], 422);
        }

        $order = CustomerOrder::findOrFail($id);
        $order->status = $data['status'];
        $order->save();

        return response()->json($order);
    }
}
