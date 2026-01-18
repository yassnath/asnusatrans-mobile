"use client";

import Link from "next/link";

const AuthShell = ({ title, subtitle, children }) => {
  return (
    <>
      <style jsx global>{`
        :root {
          --cv-bg: #0f1623;
          --cv-panel: #1b2431;
          --cv-panel2: #273142;
          --cv-text: #e5e7eb;
          --cv-muted: #94a3b8;

          --cv-blue: #5b8cff;
          --cv-purple: #a855f7;
          --cv-cyan: #22d3ee;
        }

        * {
          -webkit-font-smoothing: antialiased;
          -moz-osx-font-smoothing: grayscale;
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
          text-shadow: 0 0 18px rgba(91, 140, 255, 0.18),
            0 0 10px rgba(168, 85, 247, 0.14);
        }

        .cvant-field {
          position: relative !important;
          width: 100% !important;
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
        }

        .cvant-input {
          height: 56px !important;
          padding-left: 52px !important;
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
        }

        .cvant-select {
          appearance: none !important;
          -webkit-appearance: none !important;
          -moz-appearance: none !important;
          background-image: none !important;
          padding-right: 52px !important;
        }

        .cvant-select-caret {
          position: absolute !important;
          right: 14px !important;
          top: 0 !important;
          height: 56px !important;
          width: 24px !important;
          display: flex !important;
          align-items: center !important;
          justify-content: center !important;
          z-index: 6 !important;
          color: #6b7280 !important;
          pointer-events: none !important;
        }

        .cvant-auth-bg {
          position: relative;
          overflow: hidden;
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
        }

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
          position: relative;
          overflow: hidden;
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

        /* ? LEFT BIG ICON - Cinematic Orbit + Smaller Orbit */
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

        /* ? ORBIT 1 (Oval + Spin) */
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

        /* ? ORBIT 2 (Smaller + Different speed) */
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

        .cvant-big-icon-wrap::after {
          content: "";
          position: absolute;
          inset: -3%;
          background: linear-gradient(
            120deg,
            transparent 22%,
            rgba(91, 140, 255, 0.1) 45%,
            rgba(34, 211, 238, 0.08) 55%,
            transparent 78%
          );
          transform: translateX(-130%);
          animation: cvantShimmer 7s ease-in-out infinite;
          pointer-events: none;
          mix-blend-mode: screen;
          border-radius: 18px;
          z-index: 1;
          opacity: 0.8;
        }

        @keyframes cvantShimmer {
          0% {
            transform: translateX(-130%);
            opacity: 0.3;
          }
          35% {
            opacity: 0.55;
          }
          60% {
            opacity: 0.45;
          }
          100% {
            transform: translateX(130%);
            opacity: 0.3;
          }
        }

        @media (max-width: 991.98px) {
          .cvant-glass {
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

          .cvant-icon-wrap {
            height: 52px !important;
          }

          .cvant-input {
            height: 52px !important;
          }

          .cvant-eye-btn {
            height: 52px !important;
          }

          .cvant-select-caret {
            height: 52px !important;
          }
        }
      `}</style>

      <section
        className="auth bg-base d-flex flex-wrap cvant-auth-bg"
        style={{ height: "100vh" }}
      >
        <div className="auth-left d-lg-block d-none" style={{ height: "100%" }}>
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

        <div
          className="auth-right py-32 px-24 d-flex flex-column justify-content-center"
          style={{ backgroundColor: "transparent", height: "100%" }}
        >
          <div
            className="max-w-464-px mx-auto w-100 cvant-glass"
            style={{ padding: "28px" }}
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

              <h4 className="mb-10 text-white cvant-mobile-title cvant-title-glow">
                {title}
              </h4>

              <p className="mb-26 text-neutral-500 text-lg cvant-mobile-desc">
                {subtitle}
              </p>
            </div>

            {children}
          </div>
        </div>
      </section>
    </>
  );
};

export default AuthShell;
