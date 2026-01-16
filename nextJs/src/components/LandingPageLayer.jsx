"use client";

import { useState } from "react";
import Link from "next/link";
import { Icon } from "@iconify/react/dist/iconify.js";
import ThemeToggleButton from "@/helper/ThemeToggleButton";
import PublicChatbotWidget from "@/components/PublicChatbotWidget";

const LandingPageLayer = () => {
  const [menuOpen, setMenuOpen] = useState(false);

  const navLinks = [
    { label: "Layanan", href: "/#layanan" },
    { label: "Armada", href: "/#armada" },
    { label: "Alur", href: "/#alur" },
    { label: "Harga", href: "/#harga" },
    { label: "FAQ", href: "/#faq" },
  ];

  const closeMenu = () => setMenuOpen(false);

  return (
    <>
      <style jsx global>{`
        :root {
          --cvant-text: #ffffff;
          --cvant-muted: #cbd5f5;
          --cvant-border: rgba(148, 163, 184, 0.2);
          --cvant-border-soft: rgba(148, 163, 184, 0.16);
          --cvant-border-strong: rgba(148, 163, 184, 0.4);
          --cvant-bg: radial-gradient(
              900px 500px at 12% 12%,
              rgba(91, 140, 255, 0.16),
              transparent 60%
            ),
            radial-gradient(
              800px 460px at 85% 8%,
              rgba(34, 211, 238, 0.14),
              transparent 58%
            ),
            radial-gradient(
              700px 480px at 60% 90%,
              rgba(139, 92, 246, 0.16),
              transparent 60%
            ),
            linear-gradient(180deg, #0c111b 0%, #0b1220 100%);
          --cvant-nav-bg: rgba(12, 17, 27, 0.78);
          --cvant-nav-bg-mobile: rgba(12, 17, 27, 0.95);
          --cvant-panel: rgba(15, 23, 42, 0.6);
          --cvant-panel-soft: rgba(15, 23, 42, 0.55);
          --cvant-panel-alt: rgba(30, 41, 59, 0.55);
          --cvant-card-strong: linear-gradient(
            180deg,
            rgba(35, 49, 70, 0.72),
            rgba(15, 23, 42, 0.7)
          );
          --cvant-badge-bg: linear-gradient(
            135deg,
            rgba(30, 41, 59, 0.7),
            rgba(15, 23, 42, 0.5)
          );
          --cvant-cta-bg: linear-gradient(120deg, #1e293b, #0f172a);
          --cvant-btn-ghost-bg: rgba(15, 23, 42, 0.35);
          --cvant-step-badge: rgba(91, 140, 255, 0.2);
          --cvant-step-text: #c7d2fe;
          --cvant-nav-hover: rgba(91, 140, 255, 0.12);
          --cvant-blue: #5b8cff;
          --cvant-cyan: #22d3ee;
          --cvant-purple: #8b5cf6;
          --cvant-green: #22c55e;
          --cvant-orange: #f97316;
        }

        html[data-theme="light"] .cvant-landing,
        html[data-bs-theme="light"] .cvant-landing {
          --cvant-text: #0b1220;
          --cvant-muted: #475569;
          --cvant-border: rgba(15, 23, 42, 0.14);
          --cvant-border-soft: rgba(15, 23, 42, 0.1);
          --cvant-border-strong: rgba(15, 23, 42, 0.28);
          --cvant-bg: radial-gradient(
              900px 500px at 12% 12%,
              rgba(91, 140, 255, 0.12),
              transparent 60%
            ),
            radial-gradient(
              800px 460px at 85% 8%,
              rgba(34, 211, 238, 0.12),
              transparent 58%
            ),
            radial-gradient(
              700px 480px at 60% 90%,
              rgba(139, 92, 246, 0.12),
              transparent 60%
            ),
            linear-gradient(180deg, #f8fafc 0%, #e2e8f0 100%);
          --cvant-nav-bg: rgba(248, 250, 252, 0.92);
          --cvant-nav-bg-mobile: rgba(248, 250, 252, 0.96);
          --cvant-panel: rgba(255, 255, 255, 0.85);
          --cvant-panel-soft: rgba(248, 250, 252, 0.9);
          --cvant-panel-alt: rgba(241, 245, 249, 0.9);
          --cvant-card-strong: linear-gradient(
            180deg,
            #ffffff 0%,
            #f1f5f9 100%
          );
          --cvant-badge-bg: linear-gradient(
            135deg,
            rgba(255, 255, 255, 0.95),
            rgba(241, 245, 249, 0.92)
          );
          --cvant-cta-bg: linear-gradient(120deg, #ffffff, #e2e8f0);
          --cvant-btn-ghost-bg: rgba(255, 255, 255, 0.7);
          --cvant-step-badge: rgba(91, 140, 255, 0.16);
          --cvant-step-text: #1e293b;
          --cvant-nav-hover: rgba(91, 140, 255, 0.18);
        }

        .cvant-landing {
          min-height: 100vh;
          color: var(--cvant-text);
          background: var(--cvant-bg);
          position: relative;
          overflow: hidden;
        }

        .cvant-container {
          width: min(1200px, 92vw);
          margin: 0 auto;
        }

        .cvant-nav {
          position: sticky;
          top: 0;
          z-index: 50;
          border-bottom: 1px solid var(--cvant-border-soft);
          background: var(--cvant-nav-bg);
          backdrop-filter: blur(12px);
        }

        .cvant-nav-inner {
          display: flex;
          align-items: center;
          justify-content: space-between;
          padding: 18px 0;
          position: relative;
        }

        .cvant-brand {
          display: inline-flex;
          align-items: center;
          gap: 10px;
          text-decoration: none;
        }

        .cvant-brand img {
          height: 36px;
          width: auto;
        }

        .cvant-brand span {
          color: var(--cvant-text);
          font-weight: 700;
          letter-spacing: 0.5px;
        }

        .cvant-nav-links {
          display: flex;
          align-items: center;
          gap: 28px;
        }

        .cvant-nav-items {
          display: flex;
          align-items: center;
          gap: 24px;
        }

        .cvant-nav-items a {
          color: var(--cvant-muted);
          font-weight: 500;
          text-decoration: none;
          transition: color 0.2s ease;
          position: relative;
          padding: 6px 10px;
          border-radius: 999px;
        }

        .cvant-nav-items a:hover {
          color: var(--cvant-text);
          background: var(--cvant-nav-hover);
        }

        .cvant-nav-items a::after {
          content: "";
          position: absolute;
          left: 50%;
          bottom: -6px;
          width: 0;
          height: 2px;
          background: linear-gradient(
            90deg,
            var(--cvant-blue),
            var(--cvant-purple)
          );
          border-radius: 999px;
          transition: width 0.25s ease, left 0.25s ease;
        }

        .cvant-nav-items a:hover::after,
        .cvant-nav-items a:focus-visible::after {
          width: 100%;
          left: 0;
        }

        .cvant-nav-actions {
          display: flex;
          align-items: center;
          gap: 12px;
        }

        .cvant-btn {
          display: inline-flex;
          align-items: center;
          gap: 8px;
          border-radius: 999px;
          padding: 10px 18px;
          font-weight: 600;
          line-height: 1;
          min-height: 42px;
          text-decoration: none;
          border: 1px solid transparent;
          transition: background 0.2s ease, color 0.2s ease,
            border-color 0.2s ease;
          justify-content: center;
          text-align: center;
        }

        .cvant-btn-primary {
          background: var(--primary-600);
          border-color: var(--primary-600);
          color: #ffffff;
          box-shadow: none;
        }

        .cvant-btn-primary:hover {
          background: var(--primary-700);
          border-color: var(--primary-700);
          color: #ffffff;
        }

        .cvant-btn-primary:active,
        .cvant-btn-primary:focus {
          background: var(--primary-800);
          border-color: var(--primary-800);
        }

        .cvant-btn-ghost {
          color: var(--primary-600);
          border: 1px solid var(--primary-600);
          background: transparent;
        }

        .cvant-btn-ghost:hover {
          background: var(--primary-700);
          border-color: var(--primary-700);
          color: #ffffff;
        }


        .cvant-nav-toggle {
          display: none;
          background: transparent;
          border: 1px solid var(--cvant-border-strong);
          color: var(--cvant-text);
          border-radius: 10px;
          padding: 8px 10px;
        }

        .cvant-hero {
          padding: 90px 0 70px;
        }

        .cvant-hero-grid {
          display: grid;
          grid-template-columns: repeat(2, minmax(0, 1fr));
          gap: 56px;
          align-items: center;
        }

        .cvant-eyebrow {
          display: inline-flex;
          align-items: center;
          gap: 10px;
          padding: 6px 14px;
          border-radius: 999px;
          border: 1px solid var(--cvant-border-strong);
          color: var(--cvant-muted);
          font-size: 13px;
          letter-spacing: 0.4px;
          text-transform: uppercase;
        }

        .cvant-hero-title {
          font-size: clamp(32px, 4vw, 52px);
          line-height: 1.15;
          margin: 18px 0 14px;
          font-weight: 700;
        }

        .cvant-hero-desc {
          color: var(--cvant-muted);
          font-size: 17px;
          line-height: 1.7;
          max-width: 520px;
        }

        .cvant-hero-cta {
          display: flex;
          align-items: center;
          gap: 16px;
          margin-top: 28px;
          flex-wrap: wrap;
        }

        .cvant-hero-badges {
          display: grid;
          grid-template-columns: repeat(3, minmax(0, 1fr));
          gap: 16px;
          margin-top: 32px;
        }

        .cvant-badge-card {
          border-radius: 16px;
          padding: 14px;
          background: var(--cvant-badge-bg);
          border: 1px solid var(--cvant-border);
          box-shadow: 0 20px 40px rgba(0, 0, 0, 0.35);
        }

        .cvant-badge-card h4 {
          font-size: 18px;
          margin-bottom: 4px;
        }

        .cvant-badge-card p {
          margin: 0;
          color: var(--cvant-muted);
          font-size: 13px;
        }

        .cvant-hero-panel {
          display: grid;
          gap: 20px;
        }

        .cvant-glass-card {
          border-radius: 20px;
          padding: 22px;
          background: var(--cvant-card-strong);
          border: 1px solid var(--cvant-border);
          box-shadow: 0 30px 60px rgba(0, 0, 0, 0.4);
        }

        .cvant-hero-panel h5 {
          margin-bottom: 12px;
          font-weight: 700;
        }

        .cvant-hero-list {
          display: grid;
          gap: 10px;
        }

        .cvant-hero-list div {
          display: flex;
          align-items: center;
          justify-content: space-between;
          padding: 10px 12px;
          border-radius: 12px;
          background: var(--cvant-panel);
          border: 1px solid var(--cvant-border-soft);
          color: var(--cvant-muted);
          font-size: 14px;
        }

        .cvant-section {
          padding: 70px 0;
        }

        .cvant-section-title {
          font-size: clamp(24px, 3vw, 36px);
          font-weight: 700;
          margin-bottom: 12px;
        }

        .cvant-section-desc {
          color: var(--cvant-muted);
          max-width: 640px;
          line-height: 1.6;
        }

        .cvant-grid {
          display: grid;
          grid-template-columns: repeat(3, minmax(0, 1fr));
          gap: 24px;
          margin-top: 36px;
        }

        .cvant-feature-card {
          border-radius: 18px;
          padding: 22px;
          background: var(--cvant-panel-soft);
          border: 1px solid var(--cvant-border);
          box-shadow: inset 0 0 0 1px rgba(15, 23, 42, 0.2);
          transition: transform 0.2s ease, border 0.2s ease;
        }

        .cvant-feature-card:hover {
          transform: translateY(-4px);
          border-color: rgba(91, 140, 255, 0.5);
        }

        .cvant-feature-card h5 {
          margin-top: 12px;
          font-weight: 700;
        }

        .cvant-feature-card p {
          color: var(--cvant-muted);
          font-size: 14px;
          line-height: 1.6;
          margin: 0;
        }

        .cvant-fleet-grid {
          display: grid;
          grid-template-columns: repeat(4, minmax(0, 1fr));
          gap: 18px;
          margin-top: 32px;
        }

        .cvant-fleet-card {
          padding: 18px;
          border-radius: 16px;
          background: var(--cvant-panel-alt);
          border: 1px solid var(--cvant-border);
        }

        .cvant-step-grid {
          display: grid;
          grid-template-columns: repeat(3, minmax(0, 1fr));
          gap: 24px;
          margin-top: 28px;
        }

        .cvant-step {
          padding: 22px;
          border-radius: 18px;
          background: var(--cvant-panel);
          border: 1px solid var(--cvant-border);
        }

        .cvant-step span {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          height: 40px;
          width: 40px;
          border-radius: 12px;
          background: var(--cvant-step-badge);
          color: var(--cvant-step-text);
          font-weight: 700;
        }

        .cvant-price-grid {
          display: grid;
          grid-template-columns: repeat(3, minmax(0, 1fr));
          gap: 24px;
          margin-top: 30px;
        }

        .cvant-price-card {
          padding: 26px;
          border-radius: 20px;
          background: var(--cvant-card-strong);
          border: 1px solid var(--cvant-border);
        }

        .cvant-price-card h4 {
          margin-bottom: 4px;
          font-weight: 700;
        }

        .cvant-price-card p {
          color: var(--cvant-muted);
          margin-bottom: 18px;
        }

        .cvant-price {
          font-size: 28px;
          font-weight: 700;
          margin-bottom: 16px;
        }

        .cvant-testimonial-grid {
          display: grid;
          grid-template-columns: repeat(2, minmax(0, 1fr));
          gap: 24px;
          margin-top: 28px;
        }

        .cvant-testimonial {
          padding: 24px;
          border-radius: 18px;
          background: var(--cvant-panel);
          border: 1px solid var(--cvant-border);
        }

        .cvant-faq {
          display: grid;
          gap: 16px;
          margin-top: 28px;
        }

        .cvant-faq-item {
          padding: 18px 20px;
          border-radius: 16px;
          background: var(--cvant-panel);
          border: 1px solid var(--cvant-border-soft);
        }

        .cvant-cta {
          padding: 70px 0 90px;
        }

        .cvant-cta-card {
          border-radius: 26px;
          padding: 36px;
          background: var(--cvant-cta-bg);
          border: 1px solid var(--cvant-border);
          display: grid;
          grid-template-columns: repeat(2, minmax(0, 1fr));
          gap: 20px;
          align-items: center;
        }

        .cvant-footer {
          padding: 40px 0 60px;
          border-top: 1px solid var(--cvant-border-soft);
          color: var(--cvant-muted);
        }

        .cvant-animate-up {
          animation: cvantRise 0.7s ease forwards;
          opacity: 0;
          transform: translateY(12px);
        }

        .cvant-delay-1 {
          animation-delay: 0.1s;
        }

        .cvant-delay-2 {
          animation-delay: 0.2s;
        }

        .cvant-delay-3 {
          animation-delay: 0.3s;
        }

        @keyframes cvantRise {
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }

        @media (prefers-reduced-motion: reduce) {
          .cvant-animate-up {
            animation: none;
            opacity: 1;
            transform: none;
          }
        }

        @media (max-width: 991px) {
          .cvant-nav-links {
            position: absolute;
            top: 68px;
            right: 0;
            left: 0;
            padding: 20px;
            flex-direction: column;
            align-items: stretch;
            background: var(--cvant-nav-bg-mobile);
            border-bottom: 1px solid var(--cvant-border-soft);
            display: none;
          }

          .cvant-nav-links.is-open {
            display: flex;
          }

          .cvant-nav-items {
            flex-direction: column;
            align-items: flex-start;
            gap: 16px;
          }

          .cvant-nav-actions {
            flex-direction: column;
            align-items: stretch;
            width: 100%;
          }

          .cvant-nav-toggle {
            display: inline-flex;
          }

          .cvant-hero-grid,
          .cvant-cta-card {
            grid-template-columns: 1fr;
          }

          .cvant-hero-badges {
            grid-template-columns: 1fr;
          }

          .cvant-grid,
          .cvant-step-grid,
          .cvant-price-grid {
            grid-template-columns: 1fr;
          }

          .cvant-fleet-grid {
            grid-template-columns: repeat(2, minmax(0, 1fr));
          }

          .cvant-testimonial-grid {
            grid-template-columns: 1fr;
          }
        }

        @media (max-width: 575px) {
          .cvant-fleet-grid {
            grid-template-columns: 1fr;
          }
        }
      `}</style>

      <div className="cvant-landing">
        <header className="cvant-nav">
          <div className="cvant-container cvant-nav-inner">
            <Link href="/" className="cvant-brand" onClick={closeMenu}>
              <img src="/assets/images/logo.webp" alt="CV ANT" />
            </Link>

            <nav className={`cvant-nav-links ${menuOpen ? "is-open" : ""}`}>
              <div className="cvant-nav-items">
                {navLinks.map((item) => (
                  <Link key={item.href} href={item.href} onClick={closeMenu}>
                    {item.label}
                  </Link>
                ))}
              </div>
              <div className="cvant-nav-actions">
                <ThemeToggleButton />
                <Link href="/customer/sign-in" className="cvant-btn cvant-btn-ghost">
                  Masuk
                </Link>
                <Link href="/order" className="cvant-btn cvant-btn-primary">
                  Order Sekarang
                </Link>
              </div>
            </nav>

            <button
              type="button"
              className="cvant-nav-toggle"
              onClick={() => setMenuOpen((v) => !v)}
              aria-label="Toggle navigation"
            >
              <Icon icon="heroicons:bars-3-solid" />
            </button>
          </div>
        </header>

        <main>
          <section className="cvant-hero">
            <div className="cvant-container cvant-hero-grid">
              <div className="cvant-animate-up">
                <span className="cvant-eyebrow">
                  <Icon icon="solar:shield-check-linear" />
                  Logistik terpercaya untuk bisnis Anda
                </span>
                <h1 className="cvant-hero-title">
                  Kirim barang lebih cepat, aman, dan terukur bersama CV ANT
                </h1>
                <p className="cvant-hero-desc">
                  Dari pengiriman harian sampai charter project, kami siapkan
                  armada dan monitoring end-to-end untuk menjaga jadwal dan
                  kualitas layanan Anda.
                </p>
                <div className="cvant-hero-cta">
                  <Link href="/order" className="cvant-btn cvant-btn-primary">
                    Buat Order
                    <Icon icon="solar:arrow-right-linear" />
                  </Link>
                  <Link href="/customer/sign-up" className="cvant-btn cvant-btn-ghost">
                    Daftar Customer
                  </Link>
                </div>
                <div className="cvant-hero-badges">
                  <div className="cvant-badge-card">
                    <h4>98% On-time</h4>
                    <p>Pengiriman sesuai SLA</p>
                  </div>
                  <div className="cvant-badge-card">
                    <h4>80+ Armada</h4>
                    <p>Truk box, CDD, fuso, trailer</p>
                  </div>
                  <div className="cvant-badge-card">
                    <h4>24 Kota</h4>
                    <p>Jaringan operasional utama</p>
                  </div>
                </div>
              </div>

              <div className="cvant-hero-panel cvant-animate-up cvant-delay-1">
                <div className="cvant-glass-card">
                  <h5>Order Snapshot</h5>
                  <div className="cvant-hero-list">
                    <div>
                      <span>Rute</span>
                      <strong>Surabaya - Jakarta</strong>
                    </div>
                    <div>
                      <span>Armada</span>
                      <strong>Fuso Box 6T</strong>
                    </div>
                    <div>
                      <span>Estimasi</span>
                      <strong>24 - 30 jam</strong>
                    </div>
                    <div>
                      <span>Status</span>
                      <strong>Dalam perjalanan</strong>
                    </div>
                  </div>
                </div>
                <div className="cvant-glass-card">
                  <h5>Highlight Layanan</h5>
                  <p className="cvant-section-desc" style={{ marginBottom: "14px" }}>
                    Pemantauan GPS, laporan harian, hingga invoice digital untuk
                    memudahkan tim operasional Anda.
                  </p>
                  <div className="cvant-hero-list">
                    <div>
                      <span>Monitoring</span>
                      <strong>Real-time</strong>
                    </div>
                    <div>
                      <span>Support</span>
                      <strong>24/7</strong>
                    </div>
                    <div>
                      <span>Payment</span>
                      <strong>Gateway siap</strong>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </section>

          <section id="layanan" className="cvant-section">
            <div className="cvant-container">
              <h2 className="cvant-section-title">Layanan yang siap tumbuh bersama bisnis Anda</h2>
              <p className="cvant-section-desc">
                Kami bantu operasional logistik lebih stabil dengan proses yang
                transparan, armada siap, dan komunikasi yang cepat.
              </p>
              <div className="cvant-grid">
                <div className="cvant-feature-card cvant-animate-up">
                  <Icon icon="solar:map-point-linear" style={{ fontSize: "26px" }} />
                  <h5>Tracking akurat</h5>
                  <p>Update posisi armada dan ETA otomatis untuk tim Anda.</p>
                </div>
                <div className="cvant-feature-card cvant-animate-up cvant-delay-1">
                  <Icon icon="solar:shield-check-linear" style={{ fontSize: "26px" }} />
                  <h5>Keamanan barang</h5>
                  <p>Prosedur loading, SOP seal, dan dokumentasi sebelum jalan.</p>
                </div>
                <div className="cvant-feature-card cvant-animate-up cvant-delay-2">
                  <Icon icon="solar:hand-shake-linear" style={{ fontSize: "26px" }} />
                  <h5>Support cepat</h5>
                  <p>Tim CS responsif untuk perubahan jadwal atau kebutuhan urgent.</p>
                </div>
              </div>
            </div>
          </section>

          <section id="armada" className="cvant-section">
            <div className="cvant-container">
              <h2 className="cvant-section-title">Pilihan armada fleksibel</h2>
              <p className="cvant-section-desc">
                Dari pengiriman retail hingga project besar, armada kami siap
                menyesuaikan kebutuhan muatan.
              </p>
              <div className="cvant-fleet-grid">
                <div className="cvant-fleet-card">
                  <h5>Box Medium</h5>
                  <p className="cvant-section-desc">Max 4 ton, cocok retail</p>
                </div>
                <div className="cvant-fleet-card">
                  <h5>CDD Long</h5>
                  <p className="cvant-section-desc">Muatan tinggi, jarak menengah</p>
                </div>
                <div className="cvant-fleet-card">
                  <h5>Fuso Box</h5>
                  <p className="cvant-section-desc">Muatan 6-8 ton</p>
                </div>
                <div className="cvant-fleet-card">
                  <h5>Trailer</h5>
                  <p className="cvant-section-desc">Project dan heavy cargo</p>
                </div>
              </div>
            </div>
          </section>

          <section id="alur" className="cvant-section">
            <div className="cvant-container">
              <h2 className="cvant-section-title">Alur order yang simple</h2>
              <p className="cvant-section-desc">
                Login, buat order, dan selesaikan pembayaran dalam satu alur
                yang terstruktur.
              </p>
              <div className="cvant-step-grid">
                <div className="cvant-step">
                  <span>1</span>
                  <h5 className="mt-16 mb-8">Daftar atau masuk</h5>
                  <p className="cvant-section-desc">
                    Buat akun customer agar detail order tersimpan rapi.
                  </p>
                </div>
                <div className="cvant-step">
                  <span>2</span>
                  <h5 className="mt-16 mb-8">Isi detail pengiriman</h5>
                  <p className="cvant-section-desc">
                    Pilih armada, rute, dan jadwal pickup sesuai kebutuhan.
                  </p>
                </div>
                <div className="cvant-step">
                  <span>3</span>
                  <h5 className="mt-16 mb-8">Pembayaran gateway</h5>
                  <p className="cvant-section-desc">
                    Selesaikan pembayaran via transfer, VA, atau e-wallet.
                  </p>
                </div>
              </div>
            </div>
          </section>

          <section id="harga" className="cvant-section">
            <div className="cvant-container">
              <h2 className="cvant-section-title">Paket layanan fleksibel</h2>
              <p className="cvant-section-desc">
                Tentukan skema layanan yang sesuai dengan ritme bisnis Anda.
              </p>
              <div className="cvant-price-grid">
                <div className="cvant-price-card">
                  <h4>Reguler</h4>
                  <p>Pengiriman harian dengan SLA stabil</p>
                  <div className="cvant-price">Mulai Rp 350k</div>
                  <Link href="/order" className="cvant-btn cvant-btn-ghost">
                    Coba Reguler
                  </Link>
                </div>
                <div className="cvant-price-card">
                  <h4>Express</h4>
                  <p>Prioritas jadwal, rute dipercepat</p>
                  <div className="cvant-price">Mulai Rp 520k</div>
                  <Link href="/order" className="cvant-btn cvant-btn-primary">
                    Pilih Express
                  </Link>
                </div>
                <div className="cvant-price-card">
                  <h4>Charter</h4>
                  <p>Armada dedicated untuk project</p>
                  <div className="cvant-price">Custom</div>
                  <Link href="/order" className="cvant-btn cvant-btn-ghost">
                    Konsultasi
                  </Link>
                </div>
              </div>
            </div>
          </section>

          <section className="cvant-section">
            <div className="cvant-container">
              <h2 className="cvant-section-title">Apa kata customer</h2>
              <p className="cvant-section-desc">
                Klien kami menjaga jadwal distribusi dengan bantuan monitoring
                dan support dari tim CV ANT.
              </p>
              <div className="cvant-testimonial-grid">
                <div className="cvant-testimonial">
                  <p className="cvant-section-desc">
                    "ETA jelas, driver on-time, dan laporan lengkap. Tim gudang
                    kami jadi lebih tenang."
                  </p>
                  <strong>Rina W. - FMCG Distributor</strong>
                </div>
                <div className="cvant-testimonial">
                  <p className="cvant-section-desc">
                    "Kami pakai charter untuk project besar, koordinasinya rapi
                    dan cepat."
                  </p>
                  <strong>Arif H. - Project Logistics</strong>
                </div>
              </div>
            </div>
          </section>

          <section id="faq" className="cvant-section">
            <div className="cvant-container">
              <h2 className="cvant-section-title">FAQ singkat</h2>
              <div className="cvant-faq">
                <div className="cvant-faq-item">
                  <h6>Apakah bisa order untuk jadwal mingguan?</h6>
                  <p className="cvant-section-desc">
                    Bisa. Tim kami akan bantu setup kontrak dan jadwal rutin.
                  </p>
                </div>
                <div className="cvant-faq-item">
                  <h6>Bagaimana sistem pembayarannya?</h6>
                  <p className="cvant-section-desc">
                    Kami sediakan gateway pembayaran, transfer bank, dan VA.
                  </p>
                </div>
                <div className="cvant-faq-item">
                  <h6>Apakah ada laporan pengiriman?</h6>
                  <p className="cvant-section-desc">
                    Ya, laporan digital tersedia dengan status dan dokumen POD.
                  </p>
                </div>
              </div>
            </div>
          </section>

          <section className="cvant-cta">
            <div className="cvant-container">
              <div className="cvant-cta-card">
                <div>
                  <h2 className="cvant-section-title">Siap mulai pengiriman pertama?</h2>
                  <p className="cvant-section-desc">
                    Daftarkan akun customer Anda dan buat order dalam hitungan
                    menit.
                  </p>
                </div>
                <div className="cvant-hero-cta">
                  <Link href="/customer/sign-up" className="cvant-btn cvant-btn-primary">
                    Daftar Sekarang
                  </Link>
                  <Link href="/order" className="cvant-btn cvant-btn-ghost">
                    Lihat Estimasi
                  </Link>
                </div>
              </div>
            </div>
          </section>
        </main>

        <footer className="cvant-footer">
          <div className="cvant-container">
            <div className="d-flex flex-wrap justify-content-between gap-3">
              <div>
                <strong>CV ANT</strong>
                <p className="mb-0">Logistik aman dan terukur.</p>
              </div>
              <div>
                <p className="mb-0">Jl. Logistik Raya No. 12, Surabaya</p>
                <p className="mb-0">cs@cvant.co.id | 031-000-2211</p>
              </div>
            </div>
          </div>
        </footer>

        <PublicChatbotWidget />
      </div>
    </>
  );
};

export default LandingPageLayer;
