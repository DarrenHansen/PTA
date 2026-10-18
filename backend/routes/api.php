<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\BusinessProfileController;
use App\Http\Controllers\Api\CustomerController;
use App\Http\Controllers\Api\InvoiceController;
use App\Http\Controllers\Api\ProductController;
use Illuminate\Support\Facades\Route;

Route::get('/health', fn () => response()->json(['status' => 'ok']));

Route::prefix('auth')->group(function () {
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/login', [AuthController::class, 'login']);
});

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/auth/logout', [AuthController::class, 'logout']);

    Route::get('/invoices/stats', [InvoiceController::class, 'stats']);
    Route::get('/invoices/overdue-candidates', [InvoiceController::class, 'overdueCandidates']);
    Route::get('/invoices/approaching-due', [InvoiceController::class, 'approachingDue']);
    Route::get('/invoices/{id}/items', [InvoiceController::class, 'showItems']);
    Route::patch('/invoices/{id}/status', [InvoiceController::class, 'updateStatus']);
    Route::apiResource('invoices', InvoiceController::class)->parameters(['invoices' => 'id']);

    Route::apiResource('customers', CustomerController::class)->except(['show'])->parameters(['customers' => 'id']);
    Route::apiResource('products', ProductController::class)->except(['show'])->parameters(['products' => 'id']);

    Route::get('/business-profile', [BusinessProfileController::class, 'show']);
    Route::put('/business-profile', [BusinessProfileController::class, 'update']);
});