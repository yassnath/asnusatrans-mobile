<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Invoice extends Model
{
    use HasFactory;

    protected $fillable = [
        'order_id',
        'no_invoice',
        'nama_pelanggan',
        'email',
        'no_telp',
        'tanggal',
        'due_date',
        'armada_id',
        'armada_start_date',
        'armada_end_date',
        'lokasi_muat',
        'lokasi_bongkar',
        'tonase',
        'harga',
        'total_biaya',
        'pph',
        'total_bayar',
        'status',
        'diterima_oleh',
        'rincian',
    ];

    protected $casts = [
        'tanggal'           => 'date',
        'due_date'          => 'date',
        'armada_start_date' => 'date',
        'armada_end_date'   => 'date',

        'tonase'            => 'float',
        'harga'             => 'float',
        'total_biaya'       => 'float',
        'pph'               => 'float',
        'total_bayar'       => 'float',

        'rincian'           => 'array',
    ];

    /**
     * ✅ SAFETY: decode jika data lama masih string JSON atau double-encoded
     */
    public function getRincianAttribute($value)
    {
        if ($value === null) return [];

        // kalau sudah array dari cast
        if (is_array($value)) return $value;

        // kalau string json
        if (is_string($value)) {
            $decoded = json_decode($value, true);

            if (is_array($decoded)) {
                // handle double encoded item
                $fixed = [];
                foreach ($decoded as $item) {
                    if (is_string($item)) {
                        $try = json_decode($item, true);
                        $fixed[] = is_array($try) ? $try : $item;
                    } else {
                        $fixed[] = $item;
                    }
                }
                return $fixed;
            }

            return [];
        }

        return [];
    }

    /**
     * ✅ FIX: biarkan Laravel handle array otomatis (NO json_encode lagi)
     */
    public function setRincianAttribute($value)
    {
        if ($value === null) {
            $this->attributes['rincian'] = null;
            return;
        }

        if (is_string($value)) {
            $decoded = json_decode($value, true);
            $this->attributes['rincian'] = is_array($decoded) ? json_encode($decoded) : null;
            return;
        }

        if (is_array($value)) {
            $this->attributes['rincian'] = json_encode($value);
            return;
        }

        $this->attributes['rincian'] = null;
    }

    public function armada()
    {
        return $this->belongsTo(Armada::class);
    }

    public function order()
    {
        return $this->belongsTo(CustomerOrder::class, 'order_id');
    }
}
