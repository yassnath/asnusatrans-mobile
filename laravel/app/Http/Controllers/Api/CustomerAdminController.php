<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use Illuminate\Http\Request;

class CustomerAdminController extends Controller
{
    public function index(Request $request)
    {
        $customers = Customer::orderByDesc('created_at')->get();

        return response()->json($customers);
    }
}
