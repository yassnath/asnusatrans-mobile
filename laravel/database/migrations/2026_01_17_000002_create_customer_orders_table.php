<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customer_orders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('customer_id')
                ->constrained('customers')
                ->cascadeOnDelete();
            $table->string('order_code')->unique();
            $table->string('pickup');
            $table->string('destination');
            $table->date('pickup_date');
            $table->time('pickup_time');
            $table->string('service');
            $table->string('fleet');
            $table->string('cargo')->nullable();
            $table->decimal('weight', 10, 2)->nullable();
            $table->decimal('distance', 10, 2)->nullable();
            $table->text('notes')->nullable();
            $table->boolean('insurance')->default(false);
            $table->unsignedBigInteger('estimate')->default(0);
            $table->unsignedBigInteger('insurance_fee')->default(0);
            $table->unsignedBigInteger('total')->default(0);
            $table->string('status')->default('Pending Payment');
            $table->string('payment_method')->nullable();
            $table->timestamp('paid_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_orders');
    }
};
