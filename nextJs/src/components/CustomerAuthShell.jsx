"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { Icon } from "@iconify/react/dist/iconify.js";
import ThemeToggleButton from "@/helper/ThemeToggleButton";
import PublicChatbotWidget from "@/components/PublicChatbotWidget";

const CustomerAuthShell = ({ title, subtitle, children, footer }) => {
  const [customer, setCustomer] = useState(null);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const token = localStorage.getItem("cvant_customer_token");
    const userRaw = localStorage.getItem("cvant_customer_user");

    if (!token || !userRaw) {
      setCustomer(null);
      return;
    }

    try {
      setCustomer(JSON.parse(userRaw));
    } catch {
      setCustomer(null);
    }
  }, []);

  const customerInitial = useMemo(() => {
    const name = customer?.name || "";
    return name ? name.trim().charAt(0).toUpperCase() : "C";
  }, [customer]);

  const customerRole = customer?.role || "Customer";
  return (
    <>
      <style jsx global>{`
        .cvant-cust-auth {
          --cvant-auth-text: #e2e8f0;
          --cvant-auth-muted: #94a3b8;
          --cvant-auth-border: rgba(148, 163, 184, 0.2);
          --cvant-auth-border-strong: rgba(148, 163, 184, 0.35);
          --cvant-auth-nav-bg: rgba(12, 17, 27, 0.8);
          --cvant-auth-card-bg: linear-gradient(
            180deg,
            rgba(35, 49, 70, 0.8),
            rgba(15, 23, 42, 0.78)
          );
          --cvant-auth-shadow: 0 30px 60px rgba(0, 0, 0, 0.45);
          --cvant-auth-btn: linear-gradient(
            90deg,
            rgba(91, 140, 255, 1),
            rgba(168, 85, 247, 1)
          );
          --cvant-auth-btn-hover: linear-gradient(
            90deg,
            rgba(76, 126, 255, 1),
            rgba(150, 70, 247, 1)
          );
          --cvant-auth-btn-active: linear-gradient(
            90deg,
            rgba(62, 112, 255, 1),
            rgba(132, 54, 235, 1)
          );
          --cvant-auth-btn-shadow: 0 0 0 1px rgba(91, 140, 255, 0.35),
            0 14px 30px rgba(0, 0, 0, 0.3),
            0 0 16px rgba(91, 140, 255, 0.2);
          --cvant-auth-left-bg: linear-gradient(
            180deg,
            rgba(30, 41, 59, 0.7),
            rgba(15, 23, 42, 0.7)
          );
          --cvant-auth-input-bg: rgba(15, 23, 42, 0.7);
          --cvant-auth-bg: radial-gradient(
              1000px 500px at 15% 15%,
              rgba(91, 140, 255, 0.18),
              transparent 60%
            ),
            radial-gradient(
              800px 480px at 85% 10%,
              rgba(34, 211, 238, 0.14),
              transparent 60%
            ),
            linear-gradient(180deg, #0f172a 0%, #0b1220 100%);
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          padding: 110px 20px 40px;
          background: var(--cvant-auth-bg);
          color: var(--cvant-auth-text);
        }

        html[data-theme="light"] .cvant-cust-auth,
        html[data-bs-theme="light"] .cvant-cust-auth {
          --cvant-auth-text: #0f172a;
          --cvant-auth-muted: #475569;
          --cvant-auth-border: rgba(15, 23, 42, 0.14);
          --cvant-auth-border-strong: rgba(15, 23, 42, 0.22);
          --cvant-auth-nav-bg: rgba(248, 250, 252, 0.92);
          --cvant-auth-card-bg: linear-gradient(
            180deg,
            #ffffff 0%,
            #f1f5f9 100%
          );
          --cvant-auth-shadow: 0 30px 60px rgba(15, 23, 42, 0.12);
          --cvant-auth-btn-shadow: 0 0 0 1px rgba(91, 140, 255, 0.25),
            0 14px 26px rgba(15, 23, 42, 0.12),
            0 0 12px rgba(91, 140, 255, 0.16);
          --cvant-auth-left-bg: linear-gradient(
            180deg,
            rgba(255, 255, 255, 0.9),
            rgba(241, 245, 249, 0.9)
          );
          --cvant-auth-input-bg: rgba(255, 255, 255, 0.9);
          --cvant-auth-bg: radial-gradient(
              1000px 500px at 15% 15%,
              rgba(91, 140, 255, 0.12),
              transparent 60%
            ),
            radial-gradient(
              800px 480px at 85% 10%,
              rgba(34, 211, 238, 0.12),
              transparent 60%
            ),
            linear-gradient(180deg, #f8fafc 0%, #e2e8f0 100%);
        }

        .cvant-auth-nav {
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          z-index: 30;
          background: var(--cvant-auth-nav-bg);
          border-bottom: 1px solid var(--cvant-auth-border);
          backdrop-filter: blur(10px);
        }

        .cvant-auth-nav-inner {
          width: min(1100px, 96vw);
          margin: 0 auto;
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 16px;
          padding: 14px 0;
        }

        .cvant-auth-nav-actions {
          display: flex;
          align-items: center;
          gap: 10px;
          flex-wrap: wrap;
        }

        .cvant-auth-nav-link {
          padding: 8px 14px;
          border-radius: 999px;
          border: 1px solid var(--cvant-auth-border-strong);
          color: var(--cvant-auth-text);
          text-decoration: none;
          font-weight: 600;
          font-size: 13px;
        }

        .cvant-auth-user {
          display: flex;
          align-items: center;
          gap: 10px;
          padding: 6px 12px;
          border-radius: 999px;
          border: 1px solid var(--cvant-auth-border);
          background: rgba(15, 23, 42, 0.12);
          color: var(--cvant-auth-text);
        }

        html[data-theme="light"] .cvant-auth-user,
        html[data-bs-theme="light"] .cvant-auth-user {
          background: rgba(241, 245, 249, 0.9);
        }

        .cvant-auth-avatar {
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

        .cvant-auth-user-name {
          font-size: 13px;
          font-weight: 600;
          line-height: 1.2;
        }

        .cvant-auth-user-role {
          font-size: 11px;
          color: var(--cvant-auth-muted);
          line-height: 1.2;
        }

        .cvant-auth-shell {
          width: min(1100px, 96vw);
          display: grid;
          grid-template-columns: repeat(2, minmax(0, 1fr));
          gap: 32px;
          align-items: stretch;
        }

        .cvant-auth-left {
          padding: 28px;
          border-radius: 22px;
          background: var(--cvant-auth-left-bg);
          border: 1px solid var(--cvant-auth-border);
          display: flex;
          flex-direction: column;
          justify-content: space-between;
        }

        .cvant-auth-left h2 {
          font-size: 28px;
          margin-bottom: 10px;
        }

        .cvant-auth-left p {
          color: var(--cvant-auth-muted);
          margin-bottom: 20px;
        }

        .cvant-auth-point {
          display: flex;
          align-items: center;
          gap: 10px;
          padding: 10px 0;
          color: var(--cvant-auth-text);
        }

        .cvant-auth-card {
          border-radius: 22px;
          padding: 30px;
          background: var(--cvant-auth-card-bg);
          border: 1px solid var(--cvant-auth-border);
          box-shadow: var(--cvant-auth-shadow);
          position: relative;
        }

        .cvant-auth-header {
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 12px;
          margin-bottom: 16px;
        }

        .cvant-auth-header button {
          flex-shrink: 0;
        }

        .cvant-auth-logo {
          display: inline-flex;
          align-items: center;
          gap: 10px;
          text-decoration: none;
        }

        .cvant-auth-logo img {
          height: 38px;
        }

        .cvant-auth-title {
          font-size: 26px;
          font-weight: 700;
          margin-bottom: 8px;
        }

        .cvant-auth-subtitle {
          color: var(--cvant-auth-muted);
          margin-bottom: 22px;
        }

        .cvant-auth-form {
          display: grid;
          gap: 14px;
        }

        .cvant-auth-label {
          font-weight: 600;
          font-size: 14px;
          color: var(--cvant-auth-text);
          margin-bottom: 6px;
        }

        .cvant-auth-field {
          position: relative;
        }

        .cvant-auth-input {
          width: 100%;
          background: var(--cvant-auth-input-bg);
          border: 1px solid var(--cvant-auth-border-strong);
          border-radius: 12px;
          padding: 12px 14px 12px 42px;
          color: var(--cvant-auth-text);
          outline: none;
        }

        .cvant-auth-input::placeholder {
          color: var(--cvant-auth-muted);
        }

        .cvant-auth-icon {
          position: absolute;
          left: 14px;
          top: 0;
          bottom: 0;
          display: flex;
          align-items: center;
          color: var(--cvant-auth-muted);
        }

        .cvant-auth-eye {
          position: absolute;
          right: 12px;
          top: 0;
          bottom: 0;
          display: flex;
          align-items: center;
          background: transparent;
          border: none;
          color: var(--cvant-auth-muted);
          padding: 0;
        }

        .cvant-auth-btn {
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 8px;
          border-radius: 999px;
          padding: 12px 18px;
          border: 1px solid transparent;
          background: var(--cvant-auth-btn);
          color: #ffffff;
          font-weight: 600;
          width: 100%;
          box-shadow: var(--cvant-auth-btn-shadow);
        }

        .cvant-auth-btn:hover {
          background: var(--cvant-auth-btn-hover);
          border-color: transparent;
          color: #ffffff;
        }

        .cvant-auth-btn:active,
        .cvant-auth-btn:focus {
          background: var(--cvant-auth-btn-active);
          border-color: transparent;
        }

        .cvant-auth-alert {
          padding: 10px 14px;
          border-radius: 12px;
          font-size: 14px;
        }

        .cvant-auth-alert.success {
          background: rgba(34, 197, 94, 0.15);
          border: 1px solid rgba(34, 197, 94, 0.4);
          color: #86efac;
        }

        .cvant-auth-alert.error {
          background: rgba(239, 68, 68, 0.15);
          border: 1px solid rgba(239, 68, 68, 0.4);
          color: #fecaca;
        }

        html[data-theme="light"] .cvant-auth-alert.success,
        html[data-bs-theme="light"] .cvant-auth-alert.success {
          color: #166534;
        }

        html[data-theme="light"] .cvant-auth-alert.error,
        html[data-bs-theme="light"] .cvant-auth-alert.error {
          color: #7f1d1d;
        }

        .cvant-auth-footer {
          margin-top: 20px;
          color: var(--cvant-auth-muted);
          font-size: 14px;
          text-align: center;
        }

        .cvant-auth-footer a {
          color: var(--primary-600);
          text-decoration: none;
          font-weight: 600;
        }

        .cvant-auth-helper {
          text-align: center;
          font-size: 13px;
          color: var(--cvant-auth-muted);
        }

        .cvant-auth-helper a {
          color: var(--primary-600);
          text-decoration: none;
          font-weight: 600;
        }

        .cvant-auth-grid {
          display: grid;
          grid-template-columns: repeat(2, minmax(0, 1fr));
          gap: 14px 16px;
        }

        .cvant-auth-full {
          grid-column: 1 / -1;
        }

        @media (max-width: 991px) {
          .cvant-auth-shell {
            grid-template-columns: 1fr;
          }

          .cvant-auth-left {
            display: none;
          }

          .cvant-auth-grid {
            grid-template-columns: 1fr;
          }
        }

        @media (max-width: 575px) {
          .cvant-auth-nav-inner {
            padding: 10px 0;
            gap: 8px;
          }

          .cvant-auth-logo img {
            height: 28px;
          }

          .cvant-auth-nav-actions {
            gap: 6px;
            flex-wrap: nowrap;
          }

          .cvant-auth-nav-link {
            padding: 6px 10px;
            font-size: 12px;
          }

          .cvant-auth-user {
            padding: 4px 8px;
          }

          .cvant-auth-user > div {
            display: none;
          }

          .cvant-auth-avatar {
            width: 28px;
            height: 28px;
            font-size: 12px;
          }

          .cvant-auth-nav-actions [data-theme-toggle] {
            width: 32px;
            height: 32px;
          }

          .cvant-auth-nav-actions [data-theme-toggle]::after {
            font-size: 1rem;
          }
        }
      `}</style>

      <section className="cvant-cust-auth">
        <nav className="cvant-auth-nav">
          <div className="cvant-auth-nav-inner">
            <Link href="/" className="cvant-auth-logo">
              <img src="/assets/images/logo.webp" alt="CV ANT" />
            </Link>
            <div className="cvant-auth-nav-actions">
              <ThemeToggleButton />
              {customer ? (
                <div className="cvant-auth-user">
                  <span className="cvant-auth-avatar">{customerInitial}</span>
                  <div>
                    <div className="cvant-auth-user-name">{customer.name || "Customer"}</div>
                    <div className="cvant-auth-user-role">{customerRole}</div>
                  </div>
                </div>
              ) : (
                <>
                  <Link href="/customer/sign-in" className="cvant-auth-nav-link">
                    Masuk
                  </Link>
                  <Link href="/customer/sign-up" className="cvant-auth-nav-link">
                    Daftar
                  </Link>
                </>
              )}
            </div>
          </div>
        </nav>
        <div className="cvant-auth-shell">
          <aside className="cvant-auth-left">
            <div>
              <Link href="/" className="cvant-auth-logo">
                <img src="/assets/images/logo.webp" alt="CV ANT" />
              </Link>
              <h2>Customer Portal</h2>
              <p>Kelola order, pembayaran, dan status pengiriman dari satu dashboard.</p>
            </div>
            <div>
              <div className="cvant-auth-point">
                <Icon icon="solar:map-point-linear" />
                Tracking realtime untuk tiap order
              </div>
              <div className="cvant-auth-point">
                <Icon icon="solar:card-transfer-linear" />
                Pembayaran gateway terintegrasi
              </div>
              <div className="cvant-auth-point">
                <Icon icon="solar:shield-check-linear" />
                SLA dan keamanan barang terjaga
              </div>
            </div>
          </aside>

          <div className="cvant-auth-card">
            <div className="cvant-auth-header">
              <Link href="/" className="cvant-auth-logo">
                <img src="/assets/images/logo.webp" alt="CV ANT" />
              </Link>
            </div>
            <h3 className="cvant-auth-title">{title}</h3>
            <p className="cvant-auth-subtitle">{subtitle}</p>
            {children}
            {footer ? <div className="cvant-auth-footer">{footer}</div> : null}
          </div>
        </div>
        <PublicChatbotWidget />
      </section>
    </>
  );
};

export default CustomerAuthShell;
