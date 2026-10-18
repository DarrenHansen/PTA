<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use Illuminate\Http\Request;

class CustomerController extends Controller
{
    public function index(Request $request)
    {
        $query = $request->user()->customers()->orderBy('name');
        if ($search = trim((string) $request->query('search', ''))) {
            $query->where(function ($builder) use ($search) {
                $builder->where('name', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%");
            });
        }

        return response()->json(['data' => $query->get()]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:40'],
            'email' => ['nullable', 'email', 'max:255'],
            'address' => ['nullable', 'string', 'max:2000'],
        ]);

        $customer = $request->user()->customers()->create($data);

        return response()->json(['data' => $customer], 201);
    }

    public function update(Request $request, int $id)
    {
        $customer = $request->user()->customers()->findOrFail($id);
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:40'],
            'email' => ['nullable', 'email', 'max:255'],
            'address' => ['nullable', 'string', 'max:2000'],
        ]);
        $customer->update($data);

        return response()->json(['data' => $customer->refresh()]);
    }

    public function destroy(Request $request, int $id)
    {
        $request->user()->customers()->findOrFail($id)->delete();

        return response()->json(['message' => 'Pelanggan dihapus.']);
    }
}
