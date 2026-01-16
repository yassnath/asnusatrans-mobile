"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Icon } from "@iconify/react/dist/iconify.js";

const ordersKey = "cvant_customer_orders";
const latestOrderKey = "cvant_latest_order";
const tokenKey = "cvant_customer_token";
const userKey = "cvant_customer_user";

const CustomerPaymentLayer = () => {
  const router = useRouter();
  const [order, setOrder] = useState(null);
  const [method, setMethod] = useState("");
  const [message, setMessage] = useState(null);
  const [processing, setProcessing] = useState(false);

  useEffect(() => {
    const stored = localStorage.getItem(latestOrderKey);
    if (!stored) return;
    try {
      setOrder(JSON.parse(stored));
    } catch {
      setOrder(null);
    }
  }, []);

  const formatCurrency = (value) => {
    const safeValue = Number.isFinite(value) ? value : 0;
    return `Rp ${safeValue.toLocaleString("id-ID")}`;
  };

  const handleSignOut = () => {
    localStorage.removeItem(tokenKey);
    localStorage.removeItem(userKey);
    document.cookie =
      "customer_token=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT; SameSite=Lax;";
    router.push("/customer/sign-in");
  };

  const handlePay = () => {
    if (!method) {
      setMessage({ type: "error", text: "Pilih metode pembayaran terlebih dulu." });
      return;
    }

    if (!order) return;
    setProcessing(true);
    setMessage(null);

    const nextOrder = {
      ...order,
      status: "Paid",
      paymentMethod: method,
      paidAt: new Date().toISOString(),
    };

    const orders = JSON.parse(localStorage.getItem(ordersKey) || "[]");
    const nextOrders = orders.map((item) => (item.id === order.id ? nextOrder : item));
    localStorage.setItem(ordersKey, JSON.stringify(nextOrders));
    localStorage.setItem(latestOrderKey, JSON.stringify(nextOrder));
    setOrder(nextOrder);
    setMessage({ type: "success", text: "Pembayaran berhasil. Tim kami akan segera memproses order." });
    setProcessing(false);
  };

  return (
    <>
      <style jsx global>{`
        .cvant-payment {
          min-height: 100vh;
          background: radial-gradient(
              900px 500px at 15% 10%,
              rgba(91, 140, 255, 0.16),
              transparent 60%
            ),
            radial-gradient(
              800px 520px at 85% 20%,
              rgba(34, 211, 238, 0.14),
              transparent 60%
            ),
            linear-gradient(180deg, #0f172a 0%, #0b1220 100%);
          color: #e2e8f0;
        }

        .cvant-payment-container {
          width: min(1200px, 92vw);
          margin: 0 auto;
        }

        .cvant-payment-nav {
          position: sticky;
          top: 0;
          z-index: 20;
          background: rgba(12, 17, 27, 0.8);
          border-bottom: 1px solid rgba(148, 163, 184, 0.12);
          backdrop-filter: blur(10px);
        }

        .cvant-payment-nav-inner {
          display: flex;
          align-items: center;
          justify-content: space-between;
          padding: 16px 0;
          gap: 16px;
          flex-wrap: wrap;
        }

        .cvant-payment-actions {
          display: flex;
          align-items: center;
          gap: 12px;
        }

        .cvant-payment-btn-outline {
          border-radius: 999px;
          padding: 8px 14px;
          border: 1px solid rgba(148, 163, 184, 0.4);
          color: #cbd5f5;
          background: transparent;
        }

        .cvant-payment-logout {
          border-radius: 999px;
          padding: 8px 14px;
          border: 1px solid rgba(239, 68, 68, 0.6);
          background: rgba(239, 68, 68, 0.12);
          color: #fecaca;
        }

        .cvant-payment-main {
          padding: 40px 0 70px;
        }

        .cvant-payment-grid {
          display: grid;
          grid-template-columns: 0.95fr 1.05fr;
          gap: 28px;
        }

        .cvant-payment-card {
          border-radius: 20px;
          padding: 24px;
          background: rgba(15, 23, 42, 0.7);
          border: 1px solid rgba(148, 163, 184, 0.18);
          box-shadow: 0 20px 40px rgba(0, 0, 0, 0.35);
        }

        .cvant-payment-title {
          font-size: 22px;
          font-weight: 700;
          margin-bottom: 8px;
        }

        .cvant-payment-desc {
          color: #94a3b8;
          font-size: 14px;
        }

        .cvant-payment-summary-item {
          display: flex;
          align-items: center;
          justify-content: space-between;
          padding: 8px 0;
          border-bottom: 1px dashed rgba(148, 163, 184, 0.2);
          color: #cbd5f5;
        }

        .cvant-payment-summary-item:last-child {
          border-bottom: none;
        }

        .cvant-method-grid {
          display: grid;
          gap: 14px;
          margin-top: 18px;
        }

        .cvant-method-card {
          display: flex;
          align-items: center;
          gap: 12px;
          padding: 14px;
          border-radius: 14px;
          border: 1px solid rgba(148, 163, 184, 0.25);
          background: rgba(15, 23, 42, 0.55);
          cursor: pointer;
          transition: border 0.2s ease, box-shadow 0.2s ease;
        }

        .cvant-method-card.active {
          border-color: rgba(91, 140, 255, 0.6);
          box-shadow: 0 0 0 1px rgba(91, 140, 255, 0.5);
        }

        .cvant-method-card input {
          margin: 0;
        }

        .cvant-pay-btn {
          border-radius: 999px;
          padding: 12px 18px;
          border: none;
          background: linear-gradient(90deg, #5b8cff, #8b5cf6);
          color: #ffffff;
          font-weight: 600;
          width: 100%;
          margin-top: 18px;
        }

        .cvant-payment-alert {
          padding: 10px 14px;
          border-radius: 12px;
          font-size: 14px;
          margin-top: 16px;
        }

        .cvant-payment-alert.success {
          background: rgba(34, 197, 94, 0.12);
          border: 1px solid rgba(34, 197, 94, 0.4);
          color: #bbf7d0;
        }

        .cvant-payment-alert.error {
          background: rgba(239, 68, 68, 0.12);
          border: 1px solid rgba(239, 68, 68, 0.4);
          color: #fecaca;
        }

        @media (max-width: 991px) {
          .cvant-payment-grid {
            grid-template-columns: 1fr;
          }
        }
      `}</style>

      <div className="cvant-payment">
        <header className="cvant-payment-nav">
          <div className="cvant-payment-container cvant-payment-nav-inner">
            <Link href="/" className="d-inline-flex align-items-center gap-2">
              <img src="/assets/images/logo.webp" alt="CV ANT" style={{ height: "34px" }} />
            </Link>
            <div className="cvant-payment-actions">
              <Link href="/order" className="cvant-payment-btn-outline">
                Ubah Order
              </Link>
              <button type="button" className="cvant-payment-logout" onClick={handleSignOut}>
                Keluar
              </button>
            </div>
          </div>
        </header>

        <main className="cvant-payment-main">
          <div className="cvant-payment-container">
            {!order ? (
              <div className="cvant-payment-card">
                <h2 className="cvant-payment-title">Order belum tersedia</h2>
                <p className="cvant-payment-desc">
                  Buat order terlebih dahulu sebelum melanjutkan pembayaran.
                </p>
                <Link href="/order" className="cvant-payment-btn-outline">
                  Ke Form Order
                </Link>
              </div>
            ) : (
              <div className="cvant-payment-grid">
                <section className="cvant-payment-card">
                  <h2 className="cvant-payment-title">Ringkasan Order</h2>
                  <p className="cvant-payment-desc">
                    Periksa kembali detail order sebelum melakukan pembayaran.
                  </p>
                  <div className="cvant-payment-summary-item">
                    <span>ID Order</span>
                    <strong>{order.id}</strong>
                  </div>
                  <div className="cvant-payment-summary-item">
                    <span>Rute</span>
                    <strong>
                      {order.pickup} - {order.destination}
                    </strong>
                  </div>
                  <div className="cvant-payment-summary-item">
                    <span>Jadwal</span>
                    <strong>
                      {order.date} | {order.time}
                    </strong>
                  </div>
                  <div className="cvant-payment-summary-item">
                    <span>Service</span>
                    <strong>{order.service}</strong>
                  </div>
                  <div className="cvant-payment-summary-item">
                    <span>Total</span>
                    <strong>{formatCurrency(order.total)}</strong>
                  </div>
                  <div className="cvant-payment-summary-item">
                    <span>Status</span>
                    <strong>{order.status}</strong>
                  </div>
                </section>

                <section className="cvant-payment-card">
                  <h2 className="cvant-payment-title">Pilih Metode Pembayaran</h2>
                  <p className="cvant-payment-desc">
                    Semua pembayaran diproses melalui gateway resmi.
                  </p>
                  <div className="cvant-method-grid">
                    {[
                      { id: "va", label: "Virtual Account", icon: "solar:card-transfer-linear" },
                      { id: "transfer", label: "Transfer Bank", icon: "solar:bank-linear" },
                      { id: "qris", label: "QRIS", icon: "solar:qr-code-linear" },
                      { id: "ewallet", label: "E-Wallet", icon: "solar:wallet-linear" },
                    ].map((option) => (
                      <label
                        key={option.id}
                        className={`cvant-method-card ${method === option.id ? "active" : ""}`}
                      >
                        <input
                          type="radio"
                          name="paymentMethod"
                          checked={method === option.id}
                          onChange={() => setMethod(option.id)}
                        />
                        <Icon icon={option.icon} style={{ fontSize: "20px" }} />
                        <span>{option.label}</span>
                      </label>
                    ))}
                  </div>
                  <button
                    type="button"
                    className="cvant-pay-btn"
                    onClick={handlePay}
                    disabled={processing}
                  >
                    {processing ? "Memproses..." : "Bayar Sekarang"}
                  </button>
                  {message && (
                    <div className={`cvant-payment-alert ${message.type}`}>{message.text}</div>
                  )}
                </section>
              </div>
            )}
          </div>
        </main>
      </div>
    </>
  );
};

export default CustomerPaymentLayer;
