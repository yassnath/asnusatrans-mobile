<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class CustomerAuthController extends Controller
{
    public function register(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'username' => ['required', 'string', 'max:80', 'unique:customers,username'],
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
            'username' => $data['username'],
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
                'username',
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
            'login' => ['nullable', 'string', 'max:255'],
            'email' => ['nullable', 'email', 'max:255'],
            'password' => ['required', 'string'],
        ]);

        $identifier = trim($data['login'] ?? $data['email'] ?? '');
        if ($identifier === '') {
            return response()->json([
                'message' => 'Email atau username wajib diisi.',
            ], 422);
        }

        $customer = Customer::where('email', $identifier)
            ->orWhere('username', $identifier)
            ->first();

        if (!$customer || !Hash::check($data['password'], $customer->password)) {
            return response()->json([
                'message' => 'Email/username atau password tidak sesuai.',
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
                'username',
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
                'username',
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

    public function updateProfile(Request $request)
    {
        $customer = $request->attributes->get('customer');
        if (!$customer) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => [
                'required',
                'email',
                'max:255',
                Rule::unique('customers', 'email')->ignore($customer->id),
            ],
            'username' => [
                'nullable',
                'string',
                'max:80',
                Rule::unique('customers', 'username')->ignore($customer->id),
            ],
            'phone' => ['nullable', 'string', 'max:30'],
            'gender' => ['nullable', 'string', 'max:20'],
            'birth_date' => ['nullable', 'date'],
            'address' => ['nullable', 'string', 'max:255'],
            'city' => ['nullable', 'string', 'max:120'],
            'company' => ['nullable', 'string', 'max:255'],
        ]);

        $customer->update($data);

        return response()->json([
            'customer' => $customer->only([
                'id',
                'name',
                'username',
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

    public function updatePassword(Request $request)
    {
        $customer = $request->attributes->get('customer');
        if (!$customer) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        $data = $request->validate([
            'current_password' => ['required', 'string'],
            'password' => ['required', 'string', 'min:6', 'confirmed'],
        ]);

        if (!Hash::check($data['current_password'], $customer->password)) {
            return response()->json(['message' => 'Password lama tidak sesuai.'], 422);
        }

        $customer->password = Hash::make($data['password']);
        $customer->save();

        return response()->json(['message' => 'Password berhasil diperbarui.']);
    }
}
