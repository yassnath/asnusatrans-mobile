<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ArmadaController;
use App\Http\Controllers\Api\InvoiceController;
use App\Http\Controllers\Api\ExpenseController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\ChatbotController;

/*
|--------------------------------------------------------------------------
| ✅ PUBLIC ROUTES (NO AUTH)
|--------------------------------------------------------------------------
*/
Route::prefix('public')->group(function () {
    // ✅ Public invoice detail (optional kalau dibutuhkan)
    Route::get('/invoices/{id}', [InvoiceController::class, 'publicShow']);

    // ✅ Public invoice PDF
    Route::get('/invoices/{id}/pdf', [InvoiceController::class, 'publicPdf']);

    // ? Public armada (nama + tonase saja)
    Route::get('/armadas', [ArmadaController::class, 'publicIndex']);
});

/*
|--------------------------------------------------------------------------
| ✅ PUBLIC PDF OLD ROUTES (OPTIONAL)
|--------------------------------------------------------------------------
*/
Route::get('/invoices/{id}/pdf', [InvoiceController::class, 'pdf']);
Route::get('/expenses/{id}/pdf', [ExpenseController::class, 'pdf']);
Route::get('/invoices/{id}/pdf-link', [InvoiceController::class, 'pdfLink']);

// REPORT public tapi auth pakai query token di controller
Route::get('/reports/summary', [ReportController::class, 'summary']);

Route::post('/login', [AuthController::class, 'login']);

/*
|--------------------------------------------------------------------------
| ✅ AUTH API ROUTES
|--------------------------------------------------------------------------
*/
Route::middleware('auth.api')->group(function () {

    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/chat', [ChatbotController::class, 'chat']);

    // ARMADA
    Route::get('/armadas', [ArmadaController::class, 'index']);
    Route::post('/armadas', [ArmadaController::class, 'store']);
    Route::get('/armadas/{id}', [ArmadaController::class, 'show']);
    Route::put('/armadas/{id}', [ArmadaController::class, 'update']);
    Route::delete('/armadas/{id}', [ArmadaController::class, 'destroy']);

    // INVOICE CRUD
    Route::get('/invoices', [InvoiceController::class, 'index']);
    Route::post('/invoices', [InvoiceController::class, 'store']);
    Route::get('/invoices/{id}', [InvoiceController::class, 'show']);
    Route::put('/invoices/{id}', [InvoiceController::class, 'update']);
    Route::delete('/invoices/{id}', [InvoiceController::class, 'destroy']);

    // EXPENSE CRUD
    Route::get('/expenses', [ExpenseController::class, 'index']);
    Route::post('/expenses', [ExpenseController::class, 'store']);
    Route::get('/expenses/{id}', [ExpenseController::class, 'show']);
    Route::put('/expenses/{id}', [ExpenseController::class, 'update']);
    Route::delete('/expenses/{id}', [ExpenseController::class, 'destroy']);
});

