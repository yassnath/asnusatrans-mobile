<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class PublicDistanceController extends Controller
{
    public function __invoke(Request $request)
    {
        $data = $request->validate([
            'origin' => ['required', 'string'],
            'destination' => ['required', 'string'],
        ]);

        $apiKey = env('GOOGLE_MAPS_API_KEY');
        if (!$apiKey) {
            return response()->json([
                'message' => 'Google Maps API key belum diatur.',
            ], 500);
        }

        $response = Http::timeout(10)->get(
            'https://maps.googleapis.com/maps/api/distancematrix/json',
            [
                'origins' => $data['origin'],
                'destinations' => $data['destination'],
                'language' => 'id',
                'units' => 'metric',
                'key' => $apiKey,
            ]
        );

        if (!$response->ok()) {
            return response()->json([
                'message' => 'Gagal mengambil data jarak dari Google Maps.',
            ], 502);
        }

        $payload = $response->json();
        $element = $payload['rows'][0]['elements'][0] ?? null;
        $status = $element['status'] ?? null;

        if ($status !== 'OK') {
            return response()->json([
                'message' => 'Rute tidak ditemukan. Periksa lokasi muat dan bongkar.',
            ], 422);
        }

        $distanceMeters = $element['distance']['value'] ?? null;
        if ($distanceMeters === null) {
            return response()->json([
                'message' => 'Data jarak tidak tersedia.',
            ], 422);
        }

        return response()->json([
            'distance_km' => round($distanceMeters / 1000, 2),
            'distance_text' => $element['distance']['text'] ?? null,
            'duration_text' => $element['duration']['text'] ?? null,
        ]);
    }
}
