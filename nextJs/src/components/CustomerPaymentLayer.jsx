"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Icon } from "@iconify/react/dist/iconify.js";
import { customerApi } from "@/lib/customerApi";

const CustomerPaymentLayer = () => {
  const [order, setOrder] = useState(null);
  const [method, setMethod] = useState("");
  const [message, setMessage] = useState(null);
  const [processing, setProcessing] = useState(false);

  useEffect(() => {
    const loadLatest = async () => {
      try {
        const latest = await customerApi.get("/customer/orders?latest=1");
        if (latest) {
          setOrder(latest);
        }
      } catch {
        setOrder(null);
      }
    };

    loadLatest();
  }, []);

  const formatCurrency = (value) => {
    const parsed = Number(value);
    const safeValue = Number.isFinite(parsed) ? parsed : 0;
    return `Rp ${safeValue.toLocaleString("id-ID")}`;
  };

  const handlePay = async () => {
    if (!method) {
      setMessage({
        type: "error",
        text: "Pilih metode pembayaran terlebih dulu.",
      });
      return;
    }

    if (!order) return;
    setProcessing(true);
    setMessage(null);

    try {
      const updated = await customerApi.post(`/customer/orders/${order.id}/pay`, {
        payment_method: method,
      });
      setOrder(updated);
      setMessage({
        type: "success",
        text: "Pembayaran berhasil. Tim kami akan segera memproses order.",
      });
    } catch (error) {
      setMessage({
        type: "error",
        text: error?.message || "Pembayaran gagal. Coba lagi.",
      });
    } finally {
      setProcessing(false);
    }
  };

  const orderCode = order?.order_code || order?.id || "-";
  const scheduleDate = order?.pickup_date || order?.date || "-";
  const rawTime = order?.pickup_time || order?.time || "";
  const scheduleTime = rawTime ? rawTime.slice(0, 5) : "-";

  const methods = [
    { id: "va", label: "Virtual Account", icon: "solar:card-transfer-linear" },
    { id: "transfer", label: "Transfer Bank", icon: "solar:bank-linear" },
    { id: "qris", label: "QRIS", icon: "solar:qr-code-linear" },
    { id: "ewallet", label: "E-Wallet", icon: "solar:wallet-linear" },
  ];

  return (
    <div className="container-fluid py-4">
      <div className="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-4">
        <div>
          <h4 className="mb-1">Payment</h4>
          <p className="text-secondary-light mb-0">
            Selesaikan pembayaran agar order segera diproses.
          </p>
        </div>
        <Link href="/order" className="btn btn-outline-primary btn-sm">
          Ubah Order
        </Link>
      </div>

      {!order ? (
        <div className="card shadow-none border">
          <div className="card-body">
            <h6 className="mb-2">Order belum tersedia</h6>
            <p className="text-secondary-light mb-0">
              Buat order terlebih dahulu sebelum melanjutkan pembayaran.
            </p>
            <Link href="/order" className="btn btn-primary mt-3">
              Ke Form Order
            </Link>
          </div>
        </div>
      ) : (
        <div className="row g-4">
          <div className="col-lg-5">
            <div className="card shadow-none border h-100">
              <div className="card-header bg-transparent">
                <h6 className="mb-0">Ringkasan Order</h6>
              </div>
              <div className="card-body">
                <table className="table table-borderless mb-0">
                  <tbody>
                    <tr>
                      <td className="text-secondary-light">ID Order</td>
                      <td className="text-end fw-semibold">{orderCode}</td>
                    </tr>
                    <tr>
                      <td className="text-secondary-light">Rute</td>
                      <td className="text-end fw-semibold">
                        {order.pickup} - {order.destination}
                      </td>
                    </tr>
                    <tr>
                      <td className="text-secondary-light">Jadwal</td>
                      <td className="text-end fw-semibold">
                        {scheduleDate} | {scheduleTime}
                      </td>
                    </tr>
                    <tr>
                      <td className="text-secondary-light">PPH (2%)</td>
                      <td className="text-end fw-semibold">
                        {formatCurrency(order.insurance_fee)}
                      </td>
                    </tr>
                    <tr>
                      <td className="text-secondary-light">Total</td>
                      <td className="text-end fw-semibold">
                        {formatCurrency(order.total)}
                      </td>
                    </tr>
                    <tr>
                      <td className="text-secondary-light">Status</td>
                      <td className="text-end fw-semibold">{order.status}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>

          <div className="col-lg-7">
            <div className="card shadow-none border h-100">
              <div className="card-header bg-transparent">
                <h6 className="mb-0">Pilih Metode Pembayaran</h6>
              </div>
              <div className="card-body">
                <div className="d-grid gap-3">
                  {methods.map((option) => (
                    <div key={option.id}>
                      <input
                        className="payment-gateway-input d-none"
                        type="radio"
                        id={`payment-${option.id}`}
                        name="paymentMethod"
                        checked={method === option.id}
                        onChange={() => setMethod(option.id)}
                      />
                      <label
                        htmlFor={`payment-${option.id}`}
                        className="payment-gateway-label border radius-8 p-12 w-100 d-flex align-items-center gap-3"
                      >
                        <Icon icon={option.icon} style={{ fontSize: "20px" }} />
                        <span className="fw-semibold">{option.label}</span>
                      </label>
                    </div>
                  ))}
                </div>

                <button
                  type="button"
                  className="btn btn-primary w-100 mt-4"
                  onClick={handlePay}
                  disabled={processing}
                >
                  {processing ? "Memproses..." : "Bayar Sekarang"}
                </button>

                {message && (
                  <div
                    className={`alert mt-3 ${
                      message.type === "success" ? "alert-success" : "alert-danger"
                    }`}
                  >
                    {message.text}
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default CustomerPaymentLayer;
