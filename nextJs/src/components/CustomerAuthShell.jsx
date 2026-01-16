"use client";

import Link from "next/link";
import { Icon } from "@iconify/react/dist/iconify.js";
import ThemeToggleButton from "@/helper/ThemeToggleButton";
import PublicChatbotWidget from "@/components/PublicChatbotWidget";

const CustomerAuthShell = ({ title, subtitle, children, footer }) => {
  return (
    <>
      <style jsx global>{`
        .cvant-cust-auth {
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          padding: 40px 20px;
          background: radial-gradient(
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
          color: #e2e8f0;
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
          background: linear-gradient(
            180deg,
            rgba(30, 41, 59, 0.7),
            rgba(15, 23, 42, 0.7)
          );
          border: 1px solid rgba(148, 163, 184, 0.2);
          display: flex;
          flex-direction: column;
          justify-content: space-between;
        }

        .cvant-auth-left h2 {
          font-size: 28px;
          margin-bottom: 10px;
        }

        .cvant-auth-left p {
          color: #94a3b8;
          margin-bottom: 20px;
        }

        .cvant-auth-point {
          display: flex;
          align-items: center;
          gap: 10px;
          padding: 10px 0;
          color: #cbd5f5;
        }

        .cvant-auth-card {
          border-radius: 22px;
          padding: 30px;
          background: linear-gradient(
            180deg,
            rgba(35, 49, 70, 0.8),
            rgba(15, 23, 42, 0.78)
          );
          border: 1px solid rgba(148, 163, 184, 0.2);
          box-shadow: 0 30px 60px rgba(0, 0, 0, 0.45);
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
          color: #94a3b8;
          margin-bottom: 22px;
        }

        .cvant-auth-form {
          display: grid;
          gap: 14px;
        }

        .cvant-auth-label {
          font-weight: 600;
          font-size: 14px;
          color: #cbd5f5;
          margin-bottom: 6px;
        }

        .cvant-auth-field {
          position: relative;
        }

        .cvant-auth-input {
          width: 100%;
          background: rgba(15, 23, 42, 0.7);
          border: 1px solid rgba(148, 163, 184, 0.3);
          border-radius: 12px;
          padding: 12px 14px 12px 42px;
          color: #e2e8f0;
          outline: none;
        }

        .cvant-auth-input::placeholder {
          color: #64748b;
        }

        .cvant-auth-icon {
          position: absolute;
          left: 14px;
          top: 50%;
          transform: translateY(-50%);
          color: #94a3b8;
        }

        .cvant-auth-eye {
          position: absolute;
          right: 12px;
          top: 50%;
          transform: translateY(-50%);
          background: transparent;
          border: none;
          color: #94a3b8;
        }

        .cvant-auth-btn {
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 8px;
          border-radius: 999px;
          padding: 12px 18px;
          border: none;
          background: var(--primary-600);
          border: 1px solid var(--primary-600);
          color: #ffffff;
          font-weight: 600;
          width: 100%;
        }

        .cvant-auth-btn:hover {
          background: var(--primary-700);
          border-color: var(--primary-700);
          color: #ffffff;
        }

        .cvant-auth-btn:active,
        .cvant-auth-btn:focus {
          background: var(--primary-800);
          border-color: var(--primary-800);
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

        .cvant-auth-footer {
          margin-top: 20px;
          color: #94a3b8;
          font-size: 14px;
          text-align: center;
        }

        .cvant-auth-footer a {
          color: #c7d2fe;
          text-decoration: none;
          font-weight: 600;
        }

        @media (max-width: 991px) {
          .cvant-auth-shell {
            grid-template-columns: 1fr;
          }

          .cvant-auth-left {
            display: none;
          }
        }
      `}</style>

      <section className="cvant-cust-auth">
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
              <ThemeToggleButton />
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
