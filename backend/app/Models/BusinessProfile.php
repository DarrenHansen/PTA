<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class BusinessProfile extends Model
{
    protected $fillable = [
        'business_name', 'business_address', 'business_phone', 'business_email',
        'logo_path', 'bank_accounts', 'notes',
    ];

    protected function casts(): array
    {
        return ['bank_accounts' => 'array'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
