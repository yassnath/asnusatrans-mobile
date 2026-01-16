<?php

namespace App\Http\Middleware;

use App\Models\Customer;
use Closure;
use Illuminate\Http\Request;

class CustomerTokenMiddleware
{
    public function handle(Request $request, Closure $next)
    {
        // Allow customer login/register without token
        if ($request->is('api/customer/login') || $request->is('api/customer/register')) {
            return $next($request);
        }

        $token = $request->bearerToken();

        if (!$token) {
            $token = $request->query('token');
        }

        if (!$token) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        $customer = Customer::where('api_token', $token)->first();

        if (!$customer) {
            return response()->json(['message' => 'Invalid token.'], 401);
        }

        $request->attributes->set('customer', $customer);

        return $next($request);
    }
}
