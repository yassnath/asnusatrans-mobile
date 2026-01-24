<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Armada;
use Illuminate\Http\Request;

class ArmadaController extends Controller
{
    public function index()
    {
        $today = now()->toDateString();

        $armadas = Armada::with(['invoices:id,armada_id,armada_start_date,armada_end_date'])
            ->orderBy('nama_truk')
            ->get();

        return $armadas->map(function ($armada) use ($today) {
            $isBusy = $armada->invoices->contains(function ($inv) use ($today) {
                if (!$inv->armada_start_date || !$inv->armada_end_date) return false;

                $start = optional($inv->armada_start_date)->toDateString() ?? (string) $inv->armada_start_date;
                $end   = optional($inv->armada_end_date)->toDateString() ?? (string) $inv->armada_end_date;

                return $start <= $today && $end >= $today;
            });

            return [
                'id' => $armada->id,
                'nama_truk' => $armada->nama_truk,
                'plat_nomor' => $armada->plat_nomor,
                'kapasitas' => $armada->kapasitas,
                'status' => $isBusy ? 'Full' : 'Ready',
                'created_at' => $armada->created_at,
                'updated_at' => $armada->updated_at,
            ];
        });
    }

    public function publicIndex()
    {
        $today = now()->toDateString();

        $armadas = Armada::with(['invoices:id,armada_id,armada_start_date,armada_end_date'])
            ->orderBy('nama_truk')
            ->get();

        return $armadas->map(function ($armada) use ($today) {
            $isBusy = $armada->invoices->contains(function ($inv) use ($today) {
                if (!$inv->armada_start_date || !$inv->armada_end_date) return false;

                $start = optional($inv->armada_start_date)->toDateString() ?? (string) $inv->armada_start_date;
                $end   = optional($inv->armada_end_date)->toDateString() ?? (string) $inv->armada_end_date;

                return $start <= $today && $end >= $today;
            });

            return [
                'id' => $armada->id,
                'nama_truk' => $armada->nama_truk,
                'kapasitas' => $armada->kapasitas,
                'status' => $isBusy ? 'Full' : 'Ready',
            ];
        });
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'nama_truk'  => ['required'],
            'plat_nomor' => ['required'],
            'kapasitas'  => ['required'],
            'status'     => ['nullable'],
        ]);

        $armada = Armada::create($data);

        return response()->json($armada);
    }

    public function show($id)
    {
        return Armada::findOrFail($id);
    }

    public function update(Request $request, $id)
    {
        $armada = Armada::findOrFail($id);

        $data = $request->validate([
            'nama_truk'  => ['required'],
            'plat_nomor' => ['required'],
            'kapasitas'  => ['required'],
            'status'     => ['nullable'],
        ]);

        $armada->update($data);

        return response()->json($armada);
    }

    public function destroy($id)
    {
        $armada = Armada::findOrFail($id);
        $armada->delete();

        return response()->json(['message' => 'Armada deleted.']);
    }
}
