"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Icon } from "@iconify/react/dist/iconify.js";
import ThemeToggleButton from "@/helper/ThemeToggleButton";
import { customerApi } from "@/lib/customerApi";

const tokenKey = "cvant_customer_token";
const userKey = "cvant_customer_user";

const CustomerPaymentLayer = () => {
  const router = useRouter();
  const [order, setOrder] = useState(null);
  const [customer, setCustomer] = useState(null);
  const [method, setMethod] = useState("");
  const [message, setMessage] = useState(null);
  const [processing, setProcessing] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef(null);

  useEffect(() => {
    const storedUser = localStorage.getItem(userKey);
    if (storedUser) {
      try {
        setCustomer(JSON.parse(storedUser));
      } catch {
        setCustomer(null);
      }
    }

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

    const loadProfile = async () => {
      try {
        const res = await customerApi.get("/customer/me");
        const user = res?.customer;
        if (!user) return;
        setCustomer(user);
        localStorage.setItem(userKey, JSON.stringify(user));
      } catch {
        // ignore
      }
    };

    loadLatest();
    loadProfile();
  }, []);

  useEffect(() => {
    if (!menuOpen) return;
    const handleClick = (event) => {
      if (!menuRef.current || menuRef.current.contains(event.target)) return;
      setMenuOpen(false);
    };
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [menuOpen]);

  const formatCurrency = (value) => {
    const parsed = Number(value);
    const safeValue = Number.isFinite(parsed) ? parsed : 0;
    return `Rp ${safeValue.toLocaleString("id-ID")}`;
  };

  const handleSignOut = () => {
    customerApi.clearToken();
    localStorage.removeItem(tokenKey);
    localStorage.removeItem(userKey);
    router.push("/customer/sign-in");
  };

  const handlePay = async () => {
    if (!method) {
      setMessage({ type: "error", text: "Pilih metode pembayaran terlebih dulu." });
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
  const customerInitial = useMemo(() => {
    const name = customer?.name || "";
    return name ? name.trim().charAt(0).toUpperCase() : "C";
  }, [customer]);
  const customerRole = customer?.role || "Customer";

  return (
    <>
      <style jsx global>{`
        .cvant-payment {
          --cvant-payment-text: #e2e8f0;
          --cvant-payment-muted: #94a3b8;
          --cvant-payment-border: rgba(148, 163, 184, 0.16);
          --cvant-payment-border-strong: rgba(148, 163, 184, 0.3);
          --cvant-payment-card-bg: rgba(15, 23, 42, 0.7);
          --cvant-payment-input-bg: rgba(15, 23, 42, 0.55);
          --cvant-payment-nav-bg: rgba(12, 17, 27, 0.8);
          --cvant-payment-pill-bg: rgba(15, 23, 42, 0.35);
          --cvant-payment-user-bg: rgba(15, 23, 42, 0.35);
          --cvant-payment-danger-text: #fecaca;
          --cvant-payment-danger-bg: rgba(239, 68, 68, 0.15);
          --cvant-payment-danger-border: rgba(239, 68, 68, 0.6);
          --cvant-payment-success-text: #bbf7d0;
          --cvant-payment-success-bg: rgba(34, 197, 94, 0.12);
          --cvant-payment-success-border: rgba(34, 197, 94, 0.4);
          --cvant-payment-shadow: 0 20px 40px rgba(0, 0, 0, 0.35);
          --cvant-payment-btn: linear-gradient(
            90deg,
            rgba(91, 140, 255, 1),
            rgba(168, 85, 247, 1)
          );
          --cvant-payment-btn-hover: linear-gradient(
            90deg,
            rgba(76, 126, 255, 1),
            rgba(150, 70, 247, 1)
          );
          --cvant-payment-btn-active: linear-gradient(
            90deg,
            rgba(62, 112, 255, 1),
            rgba(132, 54, 235, 1)
          );
          --cvant-payment-btn-shadow: 0 0 0 1px rgba(91, 140, 255, 0.35),
            0 12px 26px rgba(0, 0, 0, 0.3),
            0 0 14px rgba(91, 140, 255, 0.2);
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
          color: var(--cvant-payment-text);
        }

        html[data-theme="light"] .cvant-payment,
        html[data-bs-theme="light"] .cvant-payment {
          --cvant-payment-text: #0f172a;
          --cvant-payment-muted: #475569;
          --cvant-payment-border: rgba(15, 23, 42, 0.12);
          --cvant-payment-border-strong: rgba(15, 23, 42, 0.2);
          --cvant-payment-card-bg: rgba(255, 255, 255, 0.95);
          --cvant-payment-input-bg: rgba(255, 255, 255, 0.9);
          --cvant-payment-nav-bg: rgba(248, 250, 252, 0.92);
          --cvant-payment-pill-bg: rgba(248, 250, 252, 0.9);
          --cvant-payment-user-bg: rgba(241, 245, 249, 0.9);
          --cvant-payment-danger-text: #b91c1c;
          --cvant-payment-danger-bg: rgba(239, 68, 68, 0.12);
          --cvant-payment-danger-border: rgba(239, 68, 68, 0.4);
          --cvant-payment-success-text: #166534;
          --cvant-payment-success-bg: rgba(34, 197, 94, 0.12);
          --cvant-payment-success-border: rgba(34, 197, 94, 0.3);
          --cvant-payment-shadow: 0 20px 40px rgba(15, 23, 42, 0.12);
          --cvant-payment-btn-shadow: 0 0 0 1px rgba(91, 140, 255, 0.25),
            0 12px 24px rgba(15, 23, 42, 0.12),
            0 0 12px rgba(91, 140, 255, 0.16);
          background: radial-gradient(
              900px 500px at 15% 10%,
              rgba(91, 140, 255, 0.12),
              transparent 60%
            ),
            radial-gradient(
              800px 520px at 85% 20%,
              rgba(34, 211, 238, 0.12),
              transparent 60%
            ),
            linear-gradient(180deg, #f8fafc 0%, #e2e8f0 100%);
        }

        .cvant-payment-container {
          width: min(1200px, 92vw);
          margin: 0 auto;
        }

        .cvant-payment-nav {
          position: sticky;
          top: 0;
          z-index: 20;
          background: var(--cvant-payment-nav-bg);
          border-bottom: 1px solid var(--cvant-payment-border);
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
          flex-wrap: wrap;
        }

        .cvant-payment-profile {
          position: relative;
        }

        .cvant-payment-avatar-btn {
          width: 38px;
          height: 38px;
          border-radius: 999px;
          border: 1px solid var(--cvant-payment-border);
          background: rgba(15, 23, 42, 0.2);
          display: inline-flex;
          align-items: center;
          justify-content: center;
          padding: 0;
        }

        html[data-theme="light"] .cvant-payment-avatar-btn,
        html[data-bs-theme="light"] .cvant-payment-avatar-btn {
          background: rgba(241, 245, 249, 0.9);
        }

        .cvant-payment-menu {
          position: absolute;
          top: calc(100% + 12px);
          right: 0;
          min-width: 200px;
          padding: 12px;
          border-radius: 14px;
          background: var(--cvant-payment-card-bg);
          border: 1px solid var(--cvant-payment-border);
          box-shadow: var(--cvant-payment-shadow);
          z-index: 20;
        }

        .cvant-payment-menu-header {
          display: flex;
          align-items: flex-start;
          justify-content: space-between;
          gap: 12px;
          padding: 10px 12px;
          border-radius: 12px;
          background: var(--cvant-payment-pill-bg);
          margin-bottom: 10px;
        }

        .cvant-payment-menu-name {
          font-weight: 600;
          font-size: 14px;
          margin-bottom: 2px;
        }

        .cvant-payment-menu-role {
          font-size: 12px;
          color: var(--cvant-payment-muted);
        }

        .cvant-payment-menu-close {
          border: none;
          background: transparent;
          color: var(--cvant-payment-muted);
          padding: 0;
          line-height: 1;
        }

        .cvant-payment-menu-logout {
          width: 100%;
          border: none;
          border-radius: 10px;
          padding: 8px 10px;
          background: var(--cvant-payment-danger-bg);
          color: var(--cvant-payment-danger-text);
          display: inline-flex;
          align-items: center;
          justify-content: center;
          gap: 8px;
          font-weight: 600;
        }

        .cvant-payment-btn-outline {
          border-radius: 999px;
          padding: 8px 14px;
          border: 1px solid var(--primary-600);
          color: var(--primary-600);
          background: transparent;
        }

        .cvant-payment-btn-outline:hover {
          background: var(--primary-600);
          border-color: var(--primary-600);
          color: #ffffff;
        }

        .cvant-payment-btn-outline:active,
        .cvant-payment-btn-outline:focus {
          background: var(--primary-800);
          border-color: var(--primary-800);
          color: #ffffff;
        }

        .cvant-payment-user {
          display: flex;
          align-items: center;
          gap: 10px;
          padding: 6px 12px;
          border-radius: 999px;
          border: 1px solid var(--cvant-payment-border);
          background: var(--cvant-payment-user-bg);
          color: var(--cvant-payment-text);
        }

        .cvant-payment-avatar {
          width: 32px;
          height: 32px;
          border-radius: 50%;
          background: var(--primary-600);
          color: #fff;
          display: inline-flex;
          align-items: center;
          justify-content: center;
          font-weight: 600;
          font-size: 14px;
        }

        .cvant-payment-user-name {
          font-size: 13px;
          font-weight: 600;
          line-height: 1.2;
        }

        .cvant-payment-user-role {
          font-size: 11px;
          color: var(--cvant-payment-muted);
          line-height: 1.2;
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
          background: var(--cvant-payment-card-bg);
          border: 1px solid var(--cvant-payment-border);
          box-shadow: var(--cvant-payment-shadow);
        }

        .cvant-payment-title {
          font-size: 22px;
          font-weight: 700;
          margin-bottom: 8px;
        }

        .cvant-payment-desc {
          color: var(--cvant-payment-muted);
          font-size: 14px;
        }

        .cvant-payment-summary-item {
          display: flex;
          align-items: center;
          justify-content: space-between;
          padding: 8px 0;
          border-bottom: 1px dashed var(--cvant-payment-border);
          color: var(--cvant-payment-muted);
        }

        .cvant-payment-summary-item:last-child {
          border-bottom: none;
        }

        .cvant-payment-summary-item strong {
          color: var(--cvant-payment-text);
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
          border: 1px solid var(--cvant-payment-border-strong);
          background: var(--cvant-payment-input-bg);
          cursor: pointer;
          transition: border 0.2s ease, box-shadow 0.2s ease;
        }

        .cvant-method-card.active {
          border-color: rgba(91, 140, 255, 0.6);
          box-shadow: 0 0 0 1px rgba(91, 140, 255, 0.4);
        }

        .cvant-method-card input {
          margin: 0;
        }

        .cvant-pay-btn {
          border-radius: 999px;
          padding: 12px 18px;
          border: 1px solid transparent;
          background: var(--cvant-payment-btn);
          color: #ffffff;
          font-weight: 600;
          width: 100%;
          margin-top: 18px;
          box-shadow: var(--cvant-payment-btn-shadow);
        }

        .cvant-pay-btn:hover {
          background: var(--cvant-payment-btn-hover);
          border-color: transparent;
          color: #ffffff;
        }

        .cvant-pay-btn:active,
        .cvant-pay-btn:focus {
          background: var(--cvant-payment-btn-active);
          border-color: transparent;
        }

        .cvant-payment-alert {
          padding: 10px 14px;
          border-radius: 12px;
          font-size: 14px;
          margin-top: 16px;
        }

        .cvant-payment-alert.success {
          background: var(--cvant-payment-success-bg);
          border: 1px solid var(--cvant-payment-success-border);
          color: var(--cvant-payment-success-text);
        }

        .cvant-payment-alert.error {
          background: var(--cvant-payment-danger-bg);
          border: 1px solid var(--cvant-payment-danger-border);
          color: var(--cvant-payment-danger-text);
        }

        @media (max-width: 991px) {
          .cvant-payment-grid {
            grid-template-columns: 1fr;
          }
        }

        @media (max-width: 575px) {
          .cvant-payment-nav-inner {
            padding: 10px 0;
            gap: 8px;
          }

          .cvant-payment-nav img {
            height: 28px !important;
          }

          .cvant-payment-actions {
            gap: 6px;
            flex-wrap: nowrap;
          }

          .cvant-payment-actions [data-theme-toggle] {
            width: 32px;
            height: 32px;
          }

          .cvant-payment-actions [data-theme-toggle]::after {
            font-size: 1rem;
          }

          .cvant-payment-avatar {
            width: 28px;
            height: 28px;
            font-size: 12px;
          }

          .cvant-payment-btn-outline {
            padding: 6px 10px;
            font-size: 12px;
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
              <ThemeToggleButton />
              <Link href="/order" className="cvant-payment-btn-outline">
                Ubah Order
              </Link>
              {customer ? (
                <div className="cvant-payment-profile" ref={menuRef}>
                  <button
                    type="button"
                    className="cvant-payment-avatar-btn"
                    onClick={() => setMenuOpen((value) => !value)}
                    aria-label="Buka menu profil"
                    aria-expanded={menuOpen}
                  >
                    <span className="cvant-payment-avatar">{customerInitial}</span>
                  </button>
                  {menuOpen ? (
                    <div className="cvant-payment-menu">
                      <div className="cvant-payment-menu-header">
                        <div>
                          <div className="cvant-payment-menu-name">
                            {customer.name || "Customer"}
                          </div>
                          <div className="cvant-payment-menu-role">{customerRole}</div>
                        </div>
                        <button
                          type="button"
                          className="cvant-payment-menu-close"
                          onClick={() => setMenuOpen(false)}
                          aria-label="Tutup menu"
                        >
                          <Icon icon="radix-icons:cross-1" />
                        </button>
                      </div>
                      <button
                        type="button"
                        className="cvant-payment-menu-logout"
                        onClick={handleSignOut}
                      >
                        <Icon icon="lucide:power" />
                        Log Out
                      </button>
                    </div>
                  ) : null}
                </div>
              ) : null}
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
                    <strong>{orderCode}</strong>
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
                      {scheduleDate} | {scheduleTime}
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
