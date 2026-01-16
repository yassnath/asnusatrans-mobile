<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CustomerOrder extends Model
{
    protected $fillable = [
        'customer_id',
        'order_code',
        'pickup',
        'destination',
        'pickup_date',
        'pickup_time',
        'service',
        'fleet',
        'cargo',
        'weight',
        'distance',
        'notes',
        'insurance',
        'estimate',
        'insurance_fee',
        'total',
        'status',
        'payment_method',
        'paid_at',
    ];

    protected $casts = [
        'insurance' => 'boolean',
        'pickup_date' => 'date',
        'paid_at' => 'datetime',
        'weight' => 'decimal:2',
        'distance' => 'decimal:2',
    ];

    public function customer()
    {
        return $this->belongsTo(Customer::class);
    }
}
