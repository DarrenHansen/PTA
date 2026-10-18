<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Invoice;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class InvoiceController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();
        $user->invoices()
            ->where('status', '!=', 'paid')
            ->whereDate('due_date', '<', today())
            ->update(['status' => 'overdue']);

        $query = $user->invoices()->with('items')->orderByDesc('date')->orderByDesc('created_at');
        if ($search = trim((string) $request->query('search', ''))) {
            $query->where(function ($builder) use ($search) {
                $builder->where('customer_name', 'like', "%{$search}%")
                    ->orWhere('invoice_number', 'like', "%{$search}%")
                    ->orWhere('customer_phone', 'like', "%{$search}%");
            });
        }
        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }
        if ($request->filled('start_date')) {
            $query->whereDate('date', '>=', $request->query('start_date'));
        }
        if ($request->filled('end_date')) {
            $query->whereDate('date', '<=', $request->query('end_date'));
        }

        return response()->json(['data' => $query->get()]);
    }

    public function stats(Request $request)
    {
        $invoices = $request->user()->invoices();

        return response()->json(['data' => [
            'total' => (clone $invoices)->count(),
            'paid' => (clone $invoices)->where('status', 'paid')->count(),
            'unpaid' => (clone $invoices)->where('status', 'unpaid')->count(),
            'overdue' => (clone $invoices)->where('status', 'overdue')->count(),
            'revenue' => (clone $invoices)->where('status', 'paid')->sum('total'),
        ]]);
    }

    public function overdueCandidates(Request $request)
    {
        $data = $request->user()->invoices()
            ->where('status', '!=', 'paid')
            ->whereDate('due_date', '<', today())
            ->get(['id', 'status']);

        return response()->json(['data' => $data]);
    }

    public function approachingDue(Request $request)
    {
        $days = max(0, min(365, (int) $request->query('days', 3)));
        $data = $request->user()->invoices()->with('items')
            ->where('status', '!=', 'paid')
            ->whereDate('due_date', today()->addDays($days))
            ->orderBy('due_date')
            ->get();

        return response()->json(['data' => $data]);
    }

    public function store(Request $request)
    {
        $data = $this->validatedInvoice($request);
        $items = $data['items'];
        unset($data['items']);

        $invoice = DB::transaction(function () use ($request, $data, $items) {
            $user = $request->user()->newQuery()->lockForUpdate()->findOrFail($request->user()->id);
            $data['invoice_number'] = $this->nextInvoiceNumber($user->id);
            $data['total'] = $this->calculateTotal($items, (float) ($data['tax'] ?? 0), (float) ($data['discount'] ?? 0));
            $data['status'] = $data['status'] ?? 'unpaid';

            $invoice = $user->invoices()->create($data);
            $invoice->items()->createMany($items);

            return $invoice->load('items');
        });

        return response()->json(['data' => $invoice], 201);
    }

    public function showItems(Request $request, int $id)
    {
        $invoice = $request->user()->invoices()->with('items')->findOrFail($id);

        return response()->json(['data' => $invoice->items]);
    }

    public function show(Request $request, int $id)
    {
        $invoice = $request->user()->invoices()->with('items')->findOrFail($id);

        return response()->json(['data' => $invoice]);
    }

    public function update(Request $request, int $id)
    {
        $invoice = $request->user()->invoices()->with('items')->findOrFail($id);
        $data = $this->validatedInvoice($request);
        $items = $data['items'];
        unset($data['items'], $data['invoice_number']);
        $data['total'] = $this->calculateTotal($items, (float) ($data['tax'] ?? $invoice->tax), (float) ($data['discount'] ?? $invoice->discount));

        DB::transaction(function () use ($invoice, $data, $items) {
            $invoice->update($data);
            $invoice->items()->delete();
            $invoice->items()->createMany($items);
        });

        return response()->json(['data' => $invoice->refresh()->load('items')]);
    }

    public function updateStatus(Request $request, int $id)
    {
        $data = $request->validate([
            'status' => ['required', Rule::in(['paid', 'unpaid', 'overdue'])],
        ]);
        $invoice = $request->user()->invoices()->findOrFail($id);
        $invoice->update($data);

        return response()->json(['data' => $invoice->refresh()->load('items')]);
    }

    public function destroy(Request $request, int $id)
    {
        $request->user()->invoices()->findOrFail($id)->delete();

        return response()->json(['message' => 'Invoice dihapus.']);
    }

    private function validatedInvoice(Request $request): array
    {
        return $request->validate([
            'customer_name' => ['required', 'string', 'max:255'],
            'customer_address' => ['nullable', 'string', 'max:2000'],
            'customer_email' => ['nullable', 'email', 'max:255'],
            'customer_phone' => ['nullable', 'string', 'max:40'],
            'date' => ['required', 'date'],
            'due_date' => ['required', 'date'],
            'tax' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'discount' => ['nullable', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string', 'max:5000'],
            'status' => ['sometimes', Rule::in(['paid', 'unpaid', 'overdue'])],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_name' => ['required', 'string', 'max:255'],
            'items.*.description' => ['nullable', 'string', 'max:2000'],
            'items.*.price' => ['required', 'numeric', 'min:0'],
            'items.*.qty' => ['required', 'integer', 'min:1'],
        ]);
    }

    private function calculateTotal(array $items, float $tax, float $discount): float
    {
        $subtotal = collect($items)->sum(fn ($item) => (float) $item['price'] * (int) $item['qty']);

        return round($subtotal + ($subtotal * $tax / 100) - $discount, 2);
    }

    private function nextInvoiceNumber(int $userId): string
    {
        $prefix = 'INV-'.now()->format('Ymd');
        $last = Invoice::where('user_id', $userId)
            ->where('invoice_number', 'like', $prefix.'-%')
            ->orderByDesc('invoice_number')
            ->value('invoice_number');
        $sequence = $last ? ((int) substr($last, -4)) + 1 : 1;

        return $prefix.'-'.str_pad((string) $sequence, 4, '0', STR_PAD_LEFT);
    }
}