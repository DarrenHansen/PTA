<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class BusinessProfileController extends Controller
{
    public function show(Request $request)
    {
        return response()->json(['data' => $request->user()->businessProfile]);
    }

    public function update(Request $request)
    {
        $bankAccounts = $request->input('bank_accounts', []);
        if (is_string($bankAccounts)) {
            $bankAccounts = json_decode($bankAccounts, true) ?: [];
        }

        $data = $request->validate([
            'business_name' => ['nullable', 'string', 'max:255'],
            'business_address' => ['nullable', 'string', 'max:2000'],
            'business_phone' => ['nullable', 'string', 'max:40'],
            'business_email' => ['nullable', 'email', 'max:255'],
            'logo_path' => ['nullable', 'string', 'max:2048'],
            'logo' => ['nullable', 'image', 'max:5120'],
            'notes' => ['nullable', 'string', 'max:5000'],
        ]);

        if (! is_array($bankAccounts)) {
            return response()->json(['message' => 'Format rekening bank tidak valid.'], 422);
        }
        unset($data['logo']);
        $data['bank_accounts'] = $bankAccounts;

        $profile = $request->user()->businessProfile;
        if ($request->hasFile('logo')) {
            $this->deleteStoredImage($profile?->logo_path);
            $path = $request->file('logo')->store('business-logos', 'public');
            $data['logo_path'] = $request->getSchemeAndHttpHost().'/storage/'.ltrim($path, '/');
        } elseif (! $request->has('logo_path') && $profile) {
            $data['logo_path'] = $profile->logo_path;
        }

        $profile = $request->user()->businessProfile()->updateOrCreate([], $data);

        return response()->json(['data' => $profile->refresh()]);
    }

    private function deleteStoredImage(?string $url): void
    {
        if (! $url) {
            return;
        }

        $path = parse_url($url, PHP_URL_PATH) ?: $url;
        if (str_starts_with($path, '/storage/')) {
            Storage::disk('public')->delete(substr($path, strlen('/storage/')));
        }
    }
}