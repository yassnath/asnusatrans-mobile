<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Foundation\Configuration\Exceptions;

// IMPORTANT: ini middleware CORS bawaan Laravel
use Illuminate\Http\Middleware\HandleCors;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {

        /**
         * Pastikan CORS middleware aktif di level global.
         * Ini yang biasanya hilang di Laravel 11 kalau tidak ditambahkan.
         */
        $middleware->use([
            HandleCors::class,
        ]);

        // Alias middleware kamu tetap
        $middleware->alias([
            'auth.api' => \App\Http\Middleware\ApiTokenMiddleware::class,
            'auth.customer' => \App\Http\Middleware\CustomerTokenMiddleware::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        //
    })
    ->create();
