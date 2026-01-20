"use client";

import Link from "next/link";

const CustomerAuthShell = ({ title, subtitle, children, footer, wide = false }) => {
  return (
    <>
      <style jsx global>{`
        .cvant-auth-bg {
          min-height: 100vh;
          background: radial-gradient(
              1200px 600px at 20% 20%,
              rgba(91, 140, 255, 0.18),
              transparent 55%
            ),
            radial-gradient(
              900px 520px at 85% 30%,
              rgba(168, 85, 247, 0.14),
              transparent 55%
            ),
            radial-gradient(
              700px 520px at 60% 90%,
              rgba(34, 211, 238, 0.1),
              transparent 55%
            ),
            linear-gradient(180deg, #0f1623 0%, #0b1220 100%);
          padding: 32px 0;
          position: relative;
          overflow-x: hidden;
        }

        html[data-theme="light"] .cvant-auth-bg,
        html[data-bs-theme="light"] .cvant-auth-bg {
          background: radial-gradient(
              1200px 600px at 20% 20%,
              rgba(91, 140, 255, 0.12),
              transparent 55%
            ),
            radial-gradient(
              900px 520px at 85% 30%,
              rgba(168, 85, 247, 0.1),
              transparent 55%
            ),
            radial-gradient(
              700px 520px at 60% 90%,
              rgba(34, 211, 238, 0.08),
              transparent 55%
            ),
            linear-gradient(180deg, #f8fafc 0%, #e2e8f0 100%);
        }

        .cvant-auth-card,
        .cvant-glass {
          background: linear-gradient(
            180deg,
            rgba(39, 49, 66, 0.78) 0%,
            rgba(27, 36, 49, 0.72) 100%
          );
          border: 1px solid rgba(255, 255, 255, 0.08);
          box-shadow: 0 25px 60px rgba(0, 0, 0, 0.45);
          backdrop-filter: blur(10px);
          -webkit-backdrop-filter: blur(10px);
          border-radius: 18px;
          padding: 28px;
          position: relative;
          overflow: hidden;
        }

        html[data-theme="light"] .cvant-auth-card,
        html[data-bs-theme="light"] .cvant-auth-card,
        html[data-theme="light"] .cvant-glass,
        html[data-bs-theme="light"] .cvant-glass {
          background: linear-gradient(180deg, #ffffff 0%, #f1f5f9 100%);
          border: 1px solid rgba(15, 23, 42, 0.1);
          box-shadow: 0 20px 40px rgba(15, 23, 42, 0.12);
        }

        .cvant-auth-card-wide {
          max-width: 920px;
        }

        .cvant-auth-card-narrow {
          max-width: 520px;
        }

        .cvant-header-center {
          width: 100% !important;
          text-align: center !important;
        }

        .cvant-logo-wrap {
          width: 100% !important;
          display: flex !important;
          justify-content: center !important;
        }

        .cvant-logo-glow {
          filter: drop-shadow(0 10px 14px rgba(0, 0, 0, 0.35))
            drop-shadow(0 0 18px rgba(91, 140, 255, 0.2))
            drop-shadow(0 0 12px rgba(168, 85, 247, 0.16));
        }

        .cvant-title-glow {
          color: #ffffff;
          text-shadow: 0 0 18px rgba(91, 140, 255, 0.18),
            0 0 10px rgba(168, 85, 247, 0.14);
        }

        html[data-theme="light"] .cvant-title-glow,
        html[data-bs-theme="light"] .cvant-title-glow {
          color: #0f172a;
        }

        .cvant-auth-label {
          font-weight: 600;
          font-size: 14px;
          margin-bottom: 6px;
          color: #e5e7eb;
        }

        html[data-theme="light"] .cvant-auth-label,
        html[data-bs-theme="light"] .cvant-auth-label {
          color: #0f172a;
        }

        .cvant-auth-field {
          position: relative;
          width: 100%;
        }

        .cvant-field {
          position: relative !important;
          width: 100% !important;
        }

        .cvant-auth-icon {
          position: absolute;
          left: 16px;
          top: 0;
          height: 56px;
          width: 28px;
          display: flex;
          align-items: center;
          justify-content: center;
          z-index: 5;
          pointer-events: none;
          color: #94a3b8;
        }

        .cvant-icon-wrap {
          position: absolute !important;
          left: 16px !important;
          top: 0 !important;
          height: 56px !important;
          width: 28px !important;
          display: flex !important;
          align-items: center !important;
          justify-content: center !important;
          z-index: 5 !important;
          pointer-events: none !important;
          color: #94a3b8 !important;
        }

        .cvant-auth-input {
          height: 56px;
          width: 100%;
          padding-left: 52px;
          border-radius: 12px;
          background: rgba(15, 23, 42, 0.6);
          border: 1px solid rgba(255, 255, 255, 0.08);
          color: #e5e7eb;
        }

        .cvant-auth-input::placeholder {
          color: #94a3b8;
        }

        html[data-theme="light"] .cvant-auth-input,
        html[data-bs-theme="light"] .cvant-auth-input {
          background: #ffffff;
          border: 1px solid #cbd5e1;
          color: #0f172a;
        }

        html[data-theme="light"] .cvant-auth-input::placeholder,
        html[data-bs-theme="light"] .cvant-auth-input::placeholder {
          color: #94a3b8;
        }

        .cvant-input {
          height: 56px !important;
          padding-left: 52px !important;
        }

        .cvant-auth-eye {
          position: absolute;
          right: 10px;
          top: 0;
          height: 56px;
          width: 44px;
          display: flex;
          align-items: center;
          justify-content: center;
          border: none;
          background: transparent;
          padding: 0;
          z-index: 6;
          color: #94a3b8;
        }

        .cvant-eye-btn {
          position: absolute !important;
          right: 10px !important;
          top: 0 !important;
          height: 56px !important;
          width: 44px !important;
          display: flex !important;
          align-items: center !important;
          justify-content: center !important;
          border: none !important;
          background: transparent !important;
          padding: 0 !important;
          z-index: 6 !important;
          color: #94a3b8 !important;
        }

        .cvant-auth-btn {
          border: none;
          background: linear-gradient(
            90deg,
            rgba(91, 140, 255, 1),
            rgba(168, 85, 247, 1)
          );
          transition: transform 0.15s ease, box-shadow 0.2s ease,
            filter 0.2s ease;
          box-shadow: 0 0 0 1px rgba(91, 140, 255, 0.35),
            0 16px 34px rgba(0, 0, 0, 0.4),
            0 0 16px rgba(91, 140, 255, 0.2);
          border-radius: 12px;
          padding: 12px 18px;
          font-weight: 600;
          color: #ffffff;
          width: 100%;
        }

        .cvant-login-btn {
          border: none !important;
          background: linear-gradient(
            90deg,
            rgba(91, 140, 255, 1),
            rgba(168, 85, 247, 1)
          ) !important;
          transition: transform 0.15s ease, box-shadow 0.2s ease,
            filter 0.2s ease !important;
          box-shadow: 0 0 0 1px rgba(91, 140, 255, 0.35),
            0 16px 34px rgba(0, 0, 0, 0.4),
            0 0 16px rgba(91, 140, 255, 0.2) !important;
        }

        .cvant-auth-form {
          display: grid;
          gap: 14px;
        }

        .cvant-auth-grid {
          display: grid;
          grid-template-columns: repeat(2, minmax(0, 1fr));
          gap: 14px 16px;
        }

        .cvant-auth-full {
          grid-column: 1 / -1;
        }

        .cvant-auth-alert {
          padding: 10px 14px;
          border-radius: 12px;
          font-size: 14px;
          margin-bottom: 12px;
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
          color: #94a3b8;
          font-size: 14px;
          text-align: center;
        }

        .cvant-auth-footer a,
        .cvant-auth-helper a {
          color: var(--primary-600);
          text-decoration: none;
          font-weight: 600;
        }

        .cvant-auth-helper {
          text-align: center;
          font-size: 13px;
          color: #94a3b8;
        }

        .cvant-big-icon-wrap {
          position: relative;
          display: inline-block;
          padding: 10px;
        }

        .cvant-big-icon-wrap::before {
          content: "";
          position: absolute;
          inset: -3%;
          border-radius: 999px;
          background: radial-gradient(
              circle at 30% 30%,
              rgba(91, 140, 255, 0.14),
              transparent 60%
            ),
            radial-gradient(
              circle at 70% 50%,
              rgba(168, 85, 247, 0.1),
              transparent 62%
            ),
            radial-gradient(
              circle at 60% 80%,
              rgba(34, 211, 238, 0.08),
              transparent 65%
            );
          filter: blur(6px);
          opacity: 0.9;
          pointer-events: none;
        }

        .cvant-big-icon-wrap .cvant-icon-ring {
          position: absolute;
          inset: 6px;
          border-radius: 999px;
          border: 1px solid rgba(255, 255, 255, 0.07);
          box-shadow: 0 0 0 1px rgba(91, 140, 255, 0.12),
            0 0 12px rgba(91, 140, 255, 0.07),
            0 0 10px rgba(34, 211, 238, 0.06);
          pointer-events: none;
        }

        .cvant-big-icon-wrap .cvant-orbit {
          position: absolute;
          inset: 10px;
          border-radius: 999px;
          border: 1px dashed rgba(255, 255, 255, 0.045);
          pointer-events: none;
          animation: cvantOrbitSpin 14s linear infinite;
          transform: scaleX(1.12);
          transform-origin: center;
        }

        .cvant-big-icon-wrap .cvant-orbit::after {
          content: "";
          position: absolute;
          top: 50%;
          left: -3px;
          width: 7px;
          height: 7px;
          border-radius: 999px;
          background: radial-gradient(
            circle,
            rgba(34, 211, 238, 0.5),
            rgba(34, 211, 238, 0)
          );
          box-shadow: 0 0 10px rgba(34, 211, 238, 0.2),
            0 0 8px rgba(91, 140, 255, 0.12);
          filter: blur(0.25px);
          opacity: 0.68;
          transform: translateY(-50%);
        }

        .cvant-big-icon-wrap .cvant-orbit2 {
          position: absolute;
          inset: 16px;
          border-radius: 999px;
          border: 1px dashed rgba(255, 255, 255, 0.035);
          pointer-events: none;
          animation: cvantOrbitSpin2 9.5s linear infinite reverse;
          transform: scaleX(1.06);
          transform-origin: center;
        }

        .cvant-big-icon-wrap .cvant-orbit2::after {
          content: "";
          position: absolute;
          top: 50%;
          right: -2px;
          width: 5px;
          height: 5px;
          border-radius: 999px;
          background: radial-gradient(
            circle,
            rgba(168, 85, 247, 0.42),
            rgba(168, 85, 247, 0)
          );
          box-shadow: 0 0 10px rgba(168, 85, 247, 0.18),
            0 0 8px rgba(91, 140, 255, 0.1);
          filter: blur(0.3px);
          opacity: 0.6;
          transform: translateY(-50%);
        }

        @keyframes cvantOrbitSpin {
          from {
            transform: rotate(0deg) scaleX(1.12);
          }
          to {
            transform: rotate(360deg) scaleX(1.12);
          }
        }

        @keyframes cvantOrbitSpin2 {
          from {
            transform: rotate(0deg) scaleX(1.06);
          }
          to {
            transform: rotate(360deg) scaleX(1.06);
          }
        }

        .cvant-big-icon {
          position: relative;
          z-index: 2;
          filter: drop-shadow(0 18px 24px rgba(0, 0, 0, 0.35))
            drop-shadow(0 0 14px rgba(34, 211, 238, 0.1))
            drop-shadow(0 0 16px rgba(91, 140, 255, 0.12));
        }

        @media (max-width: 991.98px) {
          .cvant-auth-card {
            padding: 22px !important;
            border-radius: 16px !important;
          }

          .cvant-mobile-title {
            font-size: 20px !important;
            line-height: 1.25 !important;
            margin-top: 10px !important;
          }

          .cvant-mobile-desc {
            font-size: 14px !important;
            line-height: 1.45 !important;
            margin-bottom: 18px !important;
          }

          .cvant-auth-icon {
            height: 52px !important;
          }

          .cvant-auth-input {
            height: 52px !important;
          }

          .cvant-auth-eye {
            height: 52px !important;
          }

          .cvant-icon-wrap {
            height: 52px !important;
          }

          .cvant-input {
            height: 52px !important;
          }

          .cvant-eye-btn {
            height: 52px !important;
          }

          .cvant-auth-grid {
            grid-template-columns: 1fr;
          }
        }
      `}</style>

      <section className="auth bg-base d-flex flex-wrap cvant-auth-bg">
        <div className="auth-left d-lg-block d-none">
          <div className="d-flex align-items-center flex-column h-100 justify-content-center">
            <div className="cvant-big-icon-wrap">
              <div className="cvant-orbit" />
              <div className="cvant-orbit2" />
              <div className="cvant-icon-ring" />
              <img
                src="/assets/images/big-icon.webp"
                alt=""
                className="cvant-big-icon"
              />
            </div>
          </div>
        </div>

        <div className="auth-right py-32 px-24 d-flex flex-column justify-content-center">
          <div
            className={`mx-auto w-100 cvant-auth-card cvant-glass ${
              wide ? "cvant-auth-card-wide" : "cvant-auth-card-narrow"
            }`}
          >
            <div className="cvant-header-center">
              <div className="cvant-logo-wrap mb-24">
                <Link href="/" className="d-inline-flex">
                  <img
                    src="/assets/images/logo.webp"
                    alt=""
                    className="cvant-logo-glow"
                    style={{ maxWidth: "290px", height: "auto" }}
                  />
                </Link>
              </div>

              <h4 className="mb-10 cvant-mobile-title cvant-title-glow">
                {title}
              </h4>

              <p className="mb-26 text-neutral-500 text-lg cvant-mobile-desc">
                {subtitle}
              </p>
            </div>

            {children}

            {footer ? <div className="cvant-auth-footer">{footer}</div> : null}
          </div>
        </div>
      </section>
    </>
  );
};

export default CustomerAuthShell;
