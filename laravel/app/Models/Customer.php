<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Customer extends Model
{
    protected $fillable = [
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
        'password',
        'api_token',
    ];

    protected $hidden = [
        'password',
        'api_token',
    ];

    protected $casts = [
        'birth_date' => 'date',
    ];

    public function orders()
    {
        return $this->hasMany(CustomerOrder::class);
    }
}
