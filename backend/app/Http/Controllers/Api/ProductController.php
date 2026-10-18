<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        $query = $request->user()->products()->orderBy('name');
        if ($search = trim((string) $request->query('search', ''))) {
            $query->where('name', 'like', "%{$search}%");
        }

        return response()->json(['data' => $query->get()]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:2000'],
            'price' => ['required', 'numeric', 'min:0'],
            'photo_path' => ['nullable', 'string', 'max:2048'],
            'photo' => ['nullable', 'image', 'max:5120'],
        ]);

        unset($data['photo']);
        if ($request->hasFile('photo')) {
            $path = $request->file('photo')->store('products', 'public');
            $data['photo_path'] = $this->absoluteStorageUrl($request, $path);
        } else {
            $data['photo_path'] = null;
        }

        $product = $request->user()->products()->create($data);

        return response()->json(['data' => $product], 201);
    }

    public function update(Request $request, int $id)
    {
        $product = $request->user()->products()->findOrFail($id);
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:2000'],
            'price' => ['required', 'numeric', 'min:0'],
            'photo_path' => ['nullable', 'string', 'max:2048'],
            'photo' => ['nullable', 'image', 'max:5120'],
        ]);

        unset($data['photo']);
        if ($request->hasFile('photo')) {
            $this->deleteStoredImage($product->photo_path);
            $path = $request->file('photo')->store('products', 'public');
            $data['photo_path'] = $this->absoluteStorageUrl($request, $path);
        } elseif (! $request->has('photo_path')) {
            $data['photo_path'] = $product->photo_path;
        }
        $product->update($data);

        return response()->json(['data' => $product->refresh()]);
    }

    public function destroy(Request $request, int $id)
    {
        $product = $request->user()->products()->findOrFail($id);
        $this->deleteStoredImage($product->photo_path);
        $product->delete();

        return response()->json(['message' => 'Produk dihapus.']);
    }

    private function absoluteStorageUrl(Request $request, string $path): string
    {
        return $request->getSchemeAndHttpHost().'/storage/'.ltrim($path, '/');
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