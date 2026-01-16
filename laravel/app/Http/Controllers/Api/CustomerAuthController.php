<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class CustomerAuthController extends Controller
{
    public function register(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:customers,email'],
            'phone' => ['required', 'string', 'max:30'],
            'gender' => ['required', 'string', 'max:20'],
            'birth_date' => ['required', 'date'],
            'address' => ['required', 'string', 'max:255'],
            'city' => ['required', 'string', 'max:120'],
            'company' => ['nullable', 'string', 'max:255'],
            'password' => ['required', 'string', 'min:6'],
        ]);

        $customer = Customer::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'phone' => $data['phone'],
            'gender' => $data['gender'],
            'birth_date' => $data['birth_date'],
            'address' => $data['address'],
            'city' => $data['city'],
            'company' => $data['company'] ?? null,
            'role' => 'Customer',
            'password' => Hash::make($data['password']),
        ]);

        return response()->json([
            'customer' => $customer->only([
                'id',
                'name',
                'email',
                'phone',
                'gender',
                'birth_date',
                'address',
                'city',
                'company',
                'role',
                'created_at',
            ]),
        ], 201);
    }

    public function login(Request $request)
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $customer = Customer::where('email', $data['email'])->first();

        if (!$customer || !Hash::check($data['password'], $customer->password)) {
            return response()->json([
                'message' => 'Email atau password tidak sesuai.',
            ], 401);
        }

        $token = Str::random(60);
        $customer->api_token = $token;
        $customer->save();

        return response()->json([
            'token' => $token,
            'customer' => $customer->only([
                'id',
                'name',
                'email',
                'phone',
                'role',
            ]),
        ]);
    }

    public function me(Request $request)
    {
        $customer = $request->attributes->get('customer');
        if (!$customer) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        return response()->json([
            'customer' => $customer->only([
                'id',
                'name',
                'email',
                'phone',
                'gender',
                'birth_date',
                'address',
                'city',
                'company',
                'role',
            ]),
        ]);
    }
}
