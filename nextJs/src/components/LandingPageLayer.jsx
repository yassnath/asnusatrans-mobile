"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { Icon } from "@iconify/react/dist/iconify.js";
import ThemeToggleButton from "@/helper/ThemeToggleButton";
import { publicApi } from "@/lib/publicApi";
import PublicChatbotWidget from "@/components/PublicChatbotWidget";

const useCountUp = (target, duration = 2400) => {
  const [value, setValue] = useState(0);

  useEffect(() => {
    if (target <= 0) {
      setValue(0);
      return undefined;
    }

    if (typeof window === "undefined") {
      setValue(target);
      return undefined;
    }

    const prefersReducedMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches;

    if (prefersReducedMotion) {
      setValue(target);
      return undefined;
    }

    setValue(0);

    let startTime;
    let rafId;

    const easeOutCubic = (t) => 1 - Math.pow(1 - t, 3);

    const step = (timestamp) => {
      if (!startTime) startTime = timestamp;
      const progress = Math.min((timestamp - startTime) / duration, 1);
      const eased = easeOutCubic(progress);
      const current = Math.round(target * eased);
      setValue(current);

      if (progress < 1) {
        rafId = window.requestAnimationFrame(step);
      }
    };

    rafId = window.requestAnimationFrame(step);

    return () => {
      if (rafId) window.cancelAnimationFrame(rafId);
    };
  }, [target, duration]);

  return value;
};

const normalizeArmadas = (payload) => {
  if (Array.isArray(payload)) return payload;
  if (Array.isArray(payload?.data)) return payload.data;
  if (Array.isArray(payload?.armadas)) return payload.armadas;
  if (Array.isArray(payload?.items)) return payload.items;
  return [];
};

const clearStoredAuth = () => {
  if (typeof window === "undefined") return;

  localStorage.removeItem("token");
  localStorage.removeItem("user");
  localStorage.removeItem("role");
  localStorage.removeItem("username");
  localStorage.removeItem("cvant_customer_token");
  localStorage.removeItem("cvant_customer_user");

  document.cookie =
    "token=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT; SameSite=Lax;";
  document.cookie =
    "customer_token=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT; SameSite=Lax;";
};

const LandingPageLayer = () => {
  const [menuOpen, setMenuOpen] = useState(false);
  const [armadas, setArmadas] = useState([]);
  const [armadaReady, setArmadaReady] = useState(false);

  const navLinks = [
    { label: "Tentang", href: "/#tentang" },
    { label: "Keunggulan", href: "/#keunggulan" },
    { label: "Armada", href: "/#armada" },
    { label: "Alur", href: "/#alur" },
    { label: "FAQ", href: "/#faq" },
  ];

  const closeMenu = () => setMenuOpen(false);

  useEffect(() => {
    let mounted = true;

    const loadArmadas = async () => {
      try {
        const data = await publicApi.get("/public/armadas");
        if (!mounted) return;
        setArmadas(normalizeArmadas(data));
      } catch {
        if (!mounted) return;
        setArmadas([]);
      } finally {
        if (mounted) setArmadaReady(true);
      }
    };

    loadArmadas();

    return () => {
      mounted = false;
    };
  }, []);

  useEffect(() => {
    if (typeof window === "undefined") return;

    const sections = Array.from(document.querySelectorAll(".cvant-reveal"));
    if (sections.length === 0) return;

    if (!("IntersectionObserver" in window)) {
      sections.forEach((section) => section.classList.add("is-visible"));
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        });
      },
      {
        threshold: 0.2,
        rootMargin: "0px 0px -10% 0px",
      }
    );

    sections.forEach((section) => observer.observe(section));

    return () => observer.disconnect();
  }, []);

  const formatTonnage = (value) => {
    if (value == null || String(value).trim() === "") return "-";
    const raw = String(value).trim();
    if (/ton/i.test(raw)) return raw;
    return `${raw}`;
  };

  const fleetItems = useMemo(() => {
    return (Array.isArray(armadas) ? armadas : [])
      .map((item) => ({
        name: item?.nama_truk || "Armada",
        tonnage: formatTonnage(item?.kapasitas),
      }));
  }, [armadas]);

  const fleetShouldLoop = fleetItems.length > 4;
  const fleetLoopItems = fleetShouldLoop
    ? [...fleetItems, ...fleetItems]
    : fleetItems;
  const fleetSpeed = Math.max(fleetItems.length * 9, 55);

  const onTimeCount = useCountUp(98);
  const cityCount = useCountUp(34);
  const armadaCount = useCountUp(armadaReady ? armadas.length : 0);
  const testimonials = useMemo(
    () => [
      {
        quote:
          "ETA jelas dan update statusnya konsisten. Tim gudang kami lebih tenang.",
        name: "Rina W. - FMCG Distributor",
      },
      {
        quote:
          "Koordinasi cepat dan dokumen pengiriman rapi. Cocok untuk project besar.",
        name: "Arif H. - Project Logistics",
      },
      {
        quote:
          "Armada selalu siap, schedule pickup fleksibel, dan CS responsif.",
        name: "Dimas S. - Retail Chain",
      },
      {
        quote:
          "Pelaporan rute membantu tim kami memantau delivery tanpa bolak-balik tanya.",
        name: "Nadia K. - Distribution Lead",
      },
      {
        quote:
          "Status pembayaran jelas, proses order tidak ribet, dan transparan.",
        name: "Bagus R. - Procurement",
      },
      {
        quote:
          "Driver profesional dan SOP loading rapi, barang sampai aman.",
        name: "Yuli P. - Food Supplier",
      },
      {
        quote:
          "Komunikasi cepat saat ada perubahan jadwal. Sangat membantu.",
        name: "Hendra T. - Manufacturing",
      },
      {
        quote:
          "Sistemnya mudah dipakai, update order langsung masuk dashboard.",
        name: "Vina A. - Operations",
      },
      {
        quote:
          "Customer service sigap, dokumen POD lengkap, dan proses jelas.",
        name: "Fajar M. - Project Coordinator",
      },
      {
        quote:
          "Kapasitas armada sesuai kebutuhan dan konsisten on-time.",
        name: "Sari L. - Distribution Manager",
      },
    ],
    []
  );
  const testimonialSlides = useMemo(() => {
    const slides = [];
    for (let i = 0; i < testimonials.length; i += 2) {
      slides.push(testimonials.slice(i, i + 2));
    }
    return slides;
  }, [testimonials]);
  const [testimonialIndex, setTestimonialIndex] = useState(0);

  useEffect(() => {
    if (testimonialSlides.length <= 1) return undefined;
    const timer = window.setInterval(() => {
      setTestimonialIndex((prev) => (prev + 1) % testimonialSlides.length);
    }, 6000);
    return () => window.clearInterval(timer);
  }, [testimonialSlides.length]);

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
          --cvant-nav-height: 72px;
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
          --cvant-card-accent-1: rgba(91, 140, 255, 0.22);
          --cvant-card-accent-2: rgba(34, 211, 238, 0.22);
          --cvant-card-accent-3: rgba(139, 92, 246, 0.22);
          --cvant-card-accent-4: rgba(34, 197, 94, 0.2);
          --cvant-card-accent-5: rgba(249, 115, 22, 0.2);
          --cvant-btn-fill: linear-gradient(
            90deg,
            rgba(91, 140, 255, 1),
            rgba(168, 85, 247, 1)
          );
          --cvant-btn-fill-hover: linear-gradient(
            90deg,
            rgba(76, 126, 255, 1),
            rgba(150, 70, 247, 1)
          );
          --cvant-btn-fill-active: linear-gradient(
            90deg,
            rgba(62, 112, 255, 1),
            rgba(132, 54, 235, 1)
          );
          --cvant-btn-shadow: 0 0 0 1px rgba(91, 140, 255, 0.35),
            0 12px 28px rgba(0, 0, 0, 0.3),
            0 0 16px rgba(91, 140, 255, 0.2);
        }

        html[data-theme="light"] .cvant-landing,
        html[data-bs-theme="light"] .cvant-landing {
          --cvant-text: #0b1220;
          --cvant-muted: #475569;
          --cvant-border: rgba(15, 23, 42, 0.14);
          --cvant-border-soft: rgba(15, 23, 42, 0.1);
          --cvant-border-strong: rgba(15, 23, 42, 0.28);
          --cvant-bg: radial-gradient(
              900px 520px at 12% 10%,
              rgba(91, 140, 255, 0.2),
              transparent 60%
            ),
            radial-gradient(
              820px 480px at 85% 12%,
              rgba(34, 211, 238, 0.18),
              transparent 58%
            ),
            radial-gradient(
              740px 520px at 60% 85%,
              rgba(139, 92, 246, 0.16),
              transparent 60%
            ),
            radial-gradient(
              680px 420px at 18% 85%,
              rgba(34, 197, 94, 0.12),
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
          --cvant-card-accent-1: rgba(91, 140, 255, 0.2);
          --cvant-card-accent-2: rgba(34, 211, 238, 0.18);
          --cvant-card-accent-3: rgba(139, 92, 246, 0.18);
          --cvant-card-accent-4: rgba(34, 197, 94, 0.18);
          --cvant-card-accent-5: rgba(249, 115, 22, 0.18);
          --cvant-btn-shadow: 0 0 0 1px rgba(91, 140, 255, 0.25),
            0 12px 24px rgba(15, 23, 42, 0.12),
            0 0 12px rgba(91, 140, 255, 0.16);
        }

        .cvant-landing {
          min-height: 100vh;
          color: var(--cvant-text);
          background: var(--cvant-bg);
          position: relative;
          overflow: hidden;
          padding-top: var(--cvant-nav-height);
        }

        .cvant-reveal {
          opacity: 0;
          transform: translateY(24px);
          transition: opacity 0.7s ease, transform 0.7s ease;
          will-change: opacity, transform;
        }

        .cvant-reveal.is-visible {
          opacity: 1;
          transform: translateY(0);
        }

        @media (prefers-reduced-motion: reduce) {
          .cvant-reveal {
            opacity: 1;
            transform: none;
            transition: none;
          }
        }

        .cvant-container {
          width: min(1200px, 92vw);
          margin: 0 auto;
        }

        .cvant-nav {
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          width: 100%;
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
          gap: 22px;
        }

        .cvant-nav-items {
          display: flex;
          align-items: center;
          gap: 20px;
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

        .cvant-nav-tools {
          display: none;
          align-items: center;
          gap: 12px;
        }

        .cvant-theme-mobile {
          display: none;
        }

        .cvant-theme-desktop {
          display: inline-flex;
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
          background: var(--cvant-btn-fill);
          border-color: transparent;
          color: #ffffff;
          box-shadow: var(--cvant-btn-shadow);
        }

        .cvant-btn-primary:hover {
          background: var(--cvant-btn-fill-hover);
          border-color: transparent;
          color: #ffffff;
        }

        .cvant-btn-primary:active,
        .cvant-btn-primary:focus {
          background: var(--cvant-btn-fill-active);
          border-color: transparent;
        }

        .cvant-btn-ghost {
          color: var(--primary-600);
          border: 1px solid var(--primary-600);
          background: transparent;
        }

        .cvant-btn-ghost:hover {
          background: var(--primary-600);
          border-color: var(--primary-600);
          color: #ffffff;
        }

        .cvant-btn-ghost:active,
        .cvant-btn-ghost:focus {
          background: var(--primary-800);
          border-color: var(--primary-800);
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
          padding: 48px 0 70px;
        }

        .cvant-hero-grid {
          display: grid;
          grid-template-columns: minmax(0, 1.15fr) minmax(0, 0.85fr);
          gap: 44px;
          align-items: center;
          grid-template-areas: "content visual";
        }

        .cvant-hero-content {
          grid-area: content;
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
          grid-template-columns: repeat(3, minmax(180px, 1fr));
          gap: 16px;
          margin-top: 32px;
          justify-content: start;
        }

        .cvant-badge-card {
          border-radius: 14px;
          padding: 10px;
          background: var(--cvant-badge-bg);
          border: 1px solid var(--cvant-border);
          box-shadow: 0 20px 40px rgba(0, 0, 0, 0.35);
          min-height: 120px;
          display: flex;
          flex-direction: column;
          justify-content: center;
          align-items: center;
          gap: 2px;
          text-align: center;
        }

        .cvant-badge-card h4 {
          font-size: clamp(11px, 1vw, 13px);
          line-height: 1.05;
          margin: 0;
          white-space: nowrap;
        }

        .cvant-badge-card h4:first-child {
          font-size: clamp(15px, 1.6vw, 18px);
        }

        .cvant-badge-card h4 + h4 {
          font-weight: 600;
        }

        .cvant-badge-card p {
          margin: 0;
          color: var(--cvant-muted);
          font-size: 13px;
        }

        .cvant-badge-card p,
        .cvant-feature-card p,
        .cvant-fleet-card p,
        .cvant-step p,
        .cvant-price-card p,
        .cvant-testimonial p,
        .cvant-faq-item p,
        .cvant-glass-card p {
          text-align: justify;
        }

        .cvant-badge-card h4,
        .cvant-feature-card h5,
        .cvant-fleet-card h5,
        .cvant-step h5,
        .cvant-price-card h4,
        .cvant-testimonial strong,
        .cvant-faq-item h6,
        .cvant-glass-card h5 {
          text-align: center;
        }

        .cvant-testimonial,
        .cvant-faq-item {
          text-align: left;
        }

        .cvant-testimonial p,
        .cvant-faq-item p {
          text-align: left;
        }

        .cvant-testimonial strong,
        .cvant-faq-item h6 {
          margin-bottom: 16px;
          display: block;
        }

        #faq .cvant-faq,
        #faq .cvant-faq-item,
        #faq .cvant-faq-item h6,
        #faq .cvant-faq-item p {
          text-align: left;
        }

        .cvant-hero-panel {
          display: flex;
          align-items: center;
          justify-content: center;
          align-self: flex-start;
          grid-area: visual;
        }

        .cvant-glass-card {
          border-radius: 20px;
          padding: 22px;
          background: var(--cvant-card-strong);
          border: 1px solid var(--cvant-border);
          box-shadow: 0 30px 60px rgba(0, 0, 0, 0.4);
        }

        .cvant-hero-icon-wrap {
          position: relative;
          width: clamp(300px, 44vw, 600px);
          height: auto;
          aspect-ratio: 1 / 1;
          max-width: 100%;
          display: inline-flex;
          align-items: center;
          justify-content: center;
        }

        .cvant-hero-icon-wrap::before {
          content: "";
          position: absolute;
          inset: -4%;
          border-radius: 999px;
          background: radial-gradient(
              circle at 30% 30%,
              rgba(91, 140, 255, 0.18),
              transparent 60%
            ),
            radial-gradient(
              circle at 70% 50%,
              rgba(168, 85, 247, 0.14),
              transparent 62%
            ),
            radial-gradient(
              circle at 60% 80%,
              rgba(34, 211, 238, 0.12),
              transparent 65%
            );
          filter: blur(6px);
          opacity: 0.9;
          pointer-events: none;
        }

        .cvant-hero-icon-wrap .cvant-hero-ring {
          position: absolute;
          inset: 8px;
          border-radius: 999px;
          border: 1px solid rgba(255, 255, 255, 0.07);
          box-shadow: 0 0 0 1px rgba(91, 140, 255, 0.12),
            0 0 12px rgba(91, 140, 255, 0.07),
            0 0 10px rgba(34, 211, 238, 0.06);
          pointer-events: none;
        }

        .cvant-hero-icon-wrap .cvant-hero-orbit {
          position: absolute;
          inset: 10px;
          border-radius: 999px;
          border: 1px dashed rgba(255, 255, 255, 0.045);
          pointer-events: none;
          animation: cvantHeroOrbitSpin 14s linear infinite;
        }

        .cvant-hero-icon-wrap .cvant-hero-orbit::after {
          content: "";
          position: absolute;
          top: 50%;
          left: -3px;
          width: 7px;
          height: 7px;
          border-radius: 999px;
          background: radial-gradient(
            circle,
            rgba(34, 211, 238, 0.55),
            rgba(34, 211, 238, 0)
          );
          box-shadow: 0 0 10px rgba(34, 211, 238, 0.2),
            0 0 8px rgba(91, 140, 255, 0.12);
          filter: blur(0.25px);
          opacity: 0.68;
          transform: translateY(-50%);
        }

        .cvant-hero-icon-wrap .cvant-hero-orbit2 {
          position: absolute;
          inset: 16px;
          border-radius: 999px;
          border: 1px dashed rgba(255, 255, 255, 0.035);
          pointer-events: none;
          animation: cvantHeroOrbitSpin2 9.5s linear infinite reverse;
        }

        .cvant-hero-icon-wrap .cvant-hero-orbit2::after {
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

        .cvant-hero-icon-wrap::after {
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
          animation: cvantHeroShimmer 7s ease-in-out infinite;
          pointer-events: none;
          mix-blend-mode: screen;
          border-radius: 999px;
          z-index: 1;
          opacity: 0.8;
        }

        .cvant-hero-icon {
          width: min(90%, 520px);
          height: auto;
          max-width: 100%;
          z-index: 2;
          filter: drop-shadow(0 18px 24px rgba(0, 0, 0, 0.35))
            drop-shadow(0 0 14px rgba(34, 211, 238, 0.1))
            drop-shadow(0 0 16px rgba(91, 140, 255, 0.12));
        }

        @keyframes cvantHeroOrbitSpin {
          from {
            transform: rotate(0deg);
          }
          to {
            transform: rotate(360deg);
          }
        }

        @keyframes cvantHeroOrbitSpin2 {
          from {
            transform: rotate(0deg);
          }
          to {
            transform: rotate(360deg);
          }
        }

        @keyframes cvantHeroShimmer {
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

        .cvant-section-heading {
          margin-bottom: 24px;
        }

        .cvant-section-center {
          text-align: center;
        }

        .cvant-section-center .cvant-section-desc {
          margin-left: auto;
          margin-right: auto;
        }

        .cvant-section-meta {
          text-align: center;
          margin-top: 10px;
          font-size: 14px;
          color: var(--cvant-muted);
        }

        .cvant-about-grid {
          display: grid;
          grid-template-columns: minmax(0, 2fr) minmax(0, 1fr);
          gap: 24px;
          align-items: stretch;
        }

        .cvant-about-main {
          padding: 30px;
        }

        .cvant-about-main p {
          font-size: 16px;
          line-height: 1.75;
        }

        .cvant-about-main p + p {
          margin-top: 16px;
        }

        .cvant-about-stack {
          display: grid;
          gap: 24px;
        }

        .cvant-grid {
          display: grid;
          grid-template-columns: repeat(3, minmax(0, 1fr));
          gap: 24px;
          margin-top: 36px;
        }

        .cvant-feature-card,
        .cvant-fleet-card,
        .cvant-step,
        .cvant-price-card,
        .cvant-testimonial,
        .cvant-faq-item,
        .cvant-badge-card,
        .cvant-glass-card {
          position: relative;
          overflow: hidden;
        }

        .cvant-feature-card::before,
        .cvant-fleet-card::before,
        .cvant-step::before,
        .cvant-price-card::before,
        .cvant-testimonial::before,
        .cvant-faq-item::before,
        .cvant-badge-card::before,
        .cvant-glass-card::before {
          content: "";
          position: absolute;
          inset: 0;
          background: radial-gradient(
            140px 140px at 90% 10%,
            var(--cvant-card-accent),
            transparent 65%
          );
          opacity: 0.9;
          pointer-events: none;
        }

        .cvant-feature-card > *,
        .cvant-fleet-card > *,
        .cvant-step > *,
        .cvant-price-card > *,
        .cvant-testimonial > *,
        .cvant-faq-item > *,
        .cvant-badge-card > *,
        .cvant-glass-card > * {
          position: relative;
          z-index: 1;
        }

        .cvant-feature-card {
          --cvant-card-accent: var(--cvant-card-accent-1);
        }

        .cvant-feature-card:nth-child(2) {
          --cvant-card-accent: var(--cvant-card-accent-3);
        }

        .cvant-feature-card:nth-child(3) {
          --cvant-card-accent: var(--cvant-card-accent-2);
        }

        .cvant-fleet-card {
          --cvant-card-accent: var(--cvant-card-accent-2);
        }

        .cvant-fleet-card:nth-child(2n) {
          --cvant-card-accent: var(--cvant-card-accent-1);
        }

        .cvant-fleet-card:nth-child(3n) {
          --cvant-card-accent: var(--cvant-card-accent-3);
        }

        .cvant-step {
          --cvant-card-accent: var(--cvant-card-accent-1);
        }

        .cvant-step:nth-child(2) {
          --cvant-card-accent: var(--cvant-card-accent-4);
        }

        .cvant-step:nth-child(3) {
          --cvant-card-accent: var(--cvant-card-accent-5);
        }

        .cvant-price-card {
          --cvant-card-accent: var(--cvant-card-accent-3);
        }

        .cvant-price-card:nth-child(2) {
          --cvant-card-accent: var(--cvant-card-accent-1);
        }

        .cvant-price-card:nth-child(3) {
          --cvant-card-accent: var(--cvant-card-accent-2);
        }

        .cvant-testimonial {
          --cvant-card-accent: var(--cvant-card-accent-4);
        }

        .cvant-testimonial:nth-child(2) {
          --cvant-card-accent: var(--cvant-card-accent-5);
        }

        .cvant-faq-item {
          --cvant-card-accent: var(--cvant-card-accent-2);
        }

        .cvant-faq-item:nth-child(2) {
          --cvant-card-accent: var(--cvant-card-accent-3);
        }

        .cvant-faq-item:nth-child(3) {
          --cvant-card-accent: var(--cvant-card-accent-1);
        }

        .cvant-badge-card {
          --cvant-card-accent: var(--cvant-card-accent-1);
        }

        .cvant-badge-card:nth-child(2) {
          --cvant-card-accent: var(--cvant-card-accent-2);
        }

        .cvant-badge-card:nth-child(3) {
          --cvant-card-accent: var(--cvant-card-accent-3);
        }

        .cvant-glass-card {
          --cvant-card-accent: var(--cvant-card-accent-2);
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

        .cvant-card-head {
          display: flex;
          align-items: center;
          gap: 12px;
          margin-bottom: 16px;
          flex-wrap: nowrap;
          white-space: nowrap;
          justify-content: center;
        }

        .cvant-card-icon {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          line-height: 1;
        }

        .cvant-card-head h5 {
          white-space: nowrap;
          font-size: clamp(15px, 1.4vw, 18px);
        }

        .cvant-feature-card h5 {
          margin: 0;
          font-weight: 700;
        }

        .cvant-feature-card p {
          color: var(--cvant-muted);
          font-size: 14px;
          line-height: 1.6;
          margin: 0;
        }

        .cvant-fleet-slider {
          margin-top: 32px;
          overflow: hidden;
          position: relative;
          --fleet-gap: 18px;
          --fleet-gap-half: 9px;
        }

        .cvant-fleet-track {
          display: flex;
          gap: var(--fleet-gap);
          align-items: stretch;
          width: max-content;
        }

        .cvant-fleet-track.is-looping {
          animation: cvantFleetScroll var(--fleet-speed, 28s) linear infinite;
        }

        .cvant-fleet-track:not(.is-looping) {
          flex-wrap: wrap;
          justify-content: center;
          width: 100%;
        }

        .cvant-fleet-card {
          padding: 18px;
          border-radius: 16px;
          background: var(--cvant-panel-alt);
          border: 1px solid var(--cvant-border);
          flex: 0 0 auto;
          min-width: 220px;
        }

        @keyframes cvantFleetScroll {
          from {
            transform: translateX(0);
          }
          to {
            transform: translateX(calc(-50% + var(--fleet-gap-half)));
          }
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

        .cvant-step-head {
          display: flex;
          align-items: center;
          gap: 12px;
          margin-bottom: 16px;
          flex-wrap: nowrap;
          white-space: nowrap;
          justify-content: center;
        }

        .cvant-step span {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          height: 40px;
          width: 40px;
          min-width: 40px;
          min-height: 40px;
          flex: 0 0 40px;
          border-radius: 12px;
          background: var(--cvant-step-badge);
          color: var(--cvant-step-text);
          font-weight: 700;
          font-size: 14px;
        }

        .cvant-step h5 {
          margin: 0;
          white-space: nowrap;
          font-size: clamp(13px, 1.05vw, 15px);
          line-height: 1.2;
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
          margin-bottom: 16px;
        }

        .cvant-price-card h4 {
          margin-bottom: 16px;
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

        .cvant-testimonial-slider {
          overflow: hidden;
          margin-top: 28px;
        }

        .cvant-testimonial-track {
          display: flex;
          transition: transform 0.6s ease;
          will-change: transform;
        }

        .cvant-testimonial-slide {
          flex: 0 0 100%;
          display: grid;
          grid-template-columns: repeat(2, minmax(0, 1fr));
          gap: 24px;
        }

        .cvant-testimonial {
          padding: 24px;
          border-radius: 18px;
          background: var(--cvant-panel);
          border: 1px solid var(--cvant-border);
          display: flex;
          flex-direction: column;
          gap: 12px;
        }

        .cvant-testimonial p,
        .cvant-testimonial strong {
          margin: 0;
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
          padding: 24px 0 32px;
          border-top: 1px solid var(--cvant-border-soft);
          color: var(--cvant-muted);
          font-size: 14px;
        }

        .cvant-footer-note {
          margin-top: 0;
          font-size: 12px;
          text-align: center;
          color: var(--cvant-muted);
        }

        .cvant-footer strong {
          font-size: 14px;
          letter-spacing: 0.2px;
        }

        .cvant-footer p {
          margin-top: 4px;
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
            top: var(--cvant-nav-height);
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
            align-items: center;
            gap: 16px;
          }

          .cvant-nav-items a {
            width: 100%;
            text-align: center;
          }

          .cvant-nav-actions {
            flex-direction: column;
            align-items: stretch;
            width: 100%;
          }

          .cvant-nav-tools {
            display: flex;
          }

          .cvant-theme-mobile {
            display: inline-flex;
          }

          .cvant-theme-desktop {
            display: none;
          }

          .cvant-nav-toggle {
            display: inline-flex;
          }

          .cvant-hero-grid,
          .cvant-cta-card {
            grid-template-columns: 1fr;
          }

          .cvant-hero {
            padding: 24px 0 56px;
            text-align: center;
          }

          .cvant-hero-grid {
            grid-template-areas: "visual" "content";
            gap: 24px;
          }

          .cvant-hero-content {
            text-align: center;
          }

          .cvant-hero-panel {
            margin: 0;
          }

          .cvant-eyebrow {
            margin-left: auto;
            margin-right: auto;
          }

          .cvant-hero-desc {
            margin-left: auto;
            margin-right: auto;
          }

          .cvant-hero-cta {
            justify-content: center;
          }

          .cvant-hero-icon-wrap {
            width: clamp(240px, 70vw, 380px);
          }

          .cvant-hero-badges {
            grid-template-columns: 1fr;
            justify-items: center;
          }

          .cvant-card-head,
          .cvant-step-head {
            flex-wrap: wrap;
            white-space: normal;
          }

          .cvant-card-head h5,
          .cvant-step h5 {
            white-space: normal;
            text-align: center;
          }

          .cvant-badge-card {
            aspect-ratio: auto;
            min-height: 120px;
            max-width: 220px;
            width: 100%;
          }

          .cvant-section,
          .cvant-cta,
          .cvant-footer {
            text-align: center;
          }

          .cvant-about-grid {
            grid-template-columns: 1fr;
          }

          .cvant-about-main {
            padding: 26px;
          }

          .cvant-about-main p {
            font-size: 14px;
            line-height: 1.65;
            text-align: justify;
            text-align-last: left;
          }

          .cvant-grid,
          .cvant-step-grid,
          .cvant-price-grid {
            grid-template-columns: 1fr;
          }

          .cvant-fleet-card {
            min-width: 200px;
          }

          .cvant-testimonial-slide {
            grid-template-columns: 1fr;
          }
        }

        @media (max-width: 575px) {
          .cvant-hero-icon-wrap {
            width: clamp(220px, 80vw, 330px);
          }

          .cvant-fleet-slider {
            --fleet-gap: 14px;
            --fleet-gap-half: 7px;
          }

          .cvant-fleet-card {
            min-width: 180px;
          }
        }

        @media (prefers-reduced-motion: reduce) {
          .cvant-hero-icon-wrap::after,
          .cvant-hero-icon-wrap .cvant-hero-orbit,
          .cvant-hero-icon-wrap .cvant-hero-orbit2 {
            animation: none;
          }

          .cvant-testimonial-track {
            transition: none;
          }

          .cvant-fleet-track.is-looping {
            animation: none;
          }
        }
      `}</style>

      <div className="cvant-landing">
        <header className="cvant-nav">
          <div className="cvant-container cvant-nav-inner">
            <Link href="/" className="cvant-brand" onClick={closeMenu}>
              <img
                src="/assets/images/logo.webp"
                alt="CV ANT"
                loading="eager"
                decoding="async"
                fetchPriority="high"
              />
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
                <span className="cvant-theme-desktop">
                  <ThemeToggleButton />
                </span>
                <Link
                  href="/sign-in"
                  className="cvant-btn cvant-btn-ghost"
                  onClick={() => {
                    clearStoredAuth();
                    closeMenu();
                  }}
                >
                  Masuk
                </Link>
                <Link href="/order" className="cvant-btn cvant-btn-primary">
                  Order Sekarang
                </Link>
              </div>
            </nav>

            <div className="cvant-nav-tools">
              <span className="cvant-theme-mobile">
                <ThemeToggleButton />
              </span>
              <button
                type="button"
                className="cvant-nav-toggle"
                onClick={() => setMenuOpen((v) => !v)}
                aria-label="Toggle navigation"
              >
                <Icon icon="heroicons:bars-3-solid" />
              </button>
            </div>
          </div>
        </header>

        <main>
          <section className="cvant-hero cvant-reveal">
            <div className="cvant-container cvant-hero-grid">
              <div className="cvant-animate-up cvant-hero-content">
                <span className="cvant-eyebrow">
                  <Icon icon="solar:shield-check-linear" />
                  Logistik terpercaya untuk bisnis Anda
                </span>
                <h1 className="cvant-hero-title">
                  Kirim barang lebih cepat dan aman bersama CV ANT
                </h1>
                <p className="cvant-hero-desc">
                  Dari pengiriman harian, kami siapkan
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
                    <h4>{onTimeCount}%</h4>
                    <h4>On-time</h4>
                  </div>
                  <div className="cvant-badge-card">
                    <h4>{armadaReady ? armadaCount : "..."}</h4>
                    <h4>Armada</h4>
                  </div>  
                  <div className="cvant-badge-card">
                    <h4>{cityCount}</h4>
                    <h4>Kota</h4>
                  </div>
                </div>
              </div>

              <div
                className="cvant-hero-panel cvant-animate-up cvant-delay-1"
                aria-hidden="true"
              >
                <div className="cvant-hero-icon-wrap">
                  <div className="cvant-hero-orbit" />
                  <div className="cvant-hero-orbit2" />
                  <div className="cvant-hero-ring" />
                  <img
                    src="/assets/images/big-icon.webp"
                    alt="CV ANT hero illustration"
                    className="cvant-hero-icon"
                    loading="eager"
                    decoding="async"
                    fetchPriority="high"
                  />
                </div>
              </div>
            </div>
          </section>

          <section id="tentang" className="cvant-section cvant-reveal">
            <div className="cvant-container">
              <div className="cvant-section-heading cvant-section-center">
                <h2 className="cvant-section-title">Tentang CV ANT</h2>
                <p className="cvant-section-desc">
                  CV AS Nusa Trans (CV ANT) siap menjadi mitra logistik
                  terpercaya untuk kebutuhan bisnis Anda.
                </p>
              </div>
              <div className="cvant-about-grid">
                <div className="cvant-price-card cvant-about-main">
                  <h4>Profil Singkat</h4>
                  <p>
                    CV AS Nusa Trans (CV ANT) merupakan perusahaan yang bergerak
                    di bidang jasa angkutan darat dan telah berpengalaman
                    melayani kebutuhan transportasi selama lebih dari sepuluh
                    tahun. Sejak resmi berbadan hukum sebagai Commanditaire
                    Vennootschap (CV), CV ANT berkomitmen memberikan layanan
                    pengiriman yang aman, tepat waktu, dan dapat diandalkan bagi
                    berbagai mitra bisnis. Didukung oleh armada yang terkelola
                    dengan baik serta tim operasional yang berpengalaman, kami
                    terus berfokus pada efisiensi proses kerja dan peningkatan
                    kualitas layanan. Seiring perkembangan kebutuhan bisnis dan
                    teknologi, CV ANT menerapkan sistem operasional berbasis
                    website untuk mengelola data armada, transaksi, pelanggan,
                    serta jadwal pengiriman secara terintegrasi dalam satu
                    platform, sehingga memungkinkan pemantauan operasional
                    secara real-time, meminimalkan kesalahan pencatatan, dan
                    mempercepat pengambilan keputusan. Dengan mengedepankan
                    profesionalisme, transparansi, dan inovasi berkelanjutan, CV
                    ANT siap menjadi mitra transportasi darat yang terpercaya
                    dan terus berkembang mengikuti kebutuhan industri.
                  </p>
                </div>
                <div className="cvant-about-stack">
                  <div className="cvant-price-card">
                    <h4>Fokus Layanan</h4>
                    <p>
                      Ketepatan jadwal, keamanan barang, dan komunikasi responsif
                      untuk menjaga kelancaran operasional klien.
                    </p>
                  </div>
                  <div className="cvant-price-card">
                    <h4>Nilai Kami</h4>
                    <p>
                      Kolaborasi jangka panjang, kualitas armada, dan laporan yang
                      jelas untuk setiap perjalanan.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </section>

          <section id="keunggulan" className="cvant-section cvant-reveal">
            <div className="cvant-container">
              <div className="cvant-section-heading cvant-section-center">
                <h2 className="cvant-section-title">
                  Keunggulan yang siap tumbuh bersama bisnis Anda
                </h2>
                <p className="cvant-section-desc">
                  Kami bantu operasional logistik lebih stabil dengan proses yang
                  transparan, armada siap, dan komunikasi yang cepat.
                </p>
              </div>
              <div className="cvant-grid">
                <div className="cvant-feature-card cvant-animate-up">
                  <div className="cvant-card-head">
                    <Icon
                      icon="solar:map-point-linear"
                      className="cvant-card-icon"
                      style={{ fontSize: "26px" }}
                    />
                    <h5>Tracking akurat</h5>
                  </div>
                  <p>Update posisi armada dan ETA otomatis untuk tim Anda.</p>
                </div>
                <div className="cvant-feature-card cvant-animate-up cvant-delay-1">
                  <div className="cvant-card-head">
                    <Icon
                      icon="solar:shield-check-linear"
                      className="cvant-card-icon"
                      style={{ fontSize: "26px" }}
                    />
                    <h5>Keamanan barang</h5>
                  </div>
                  <p>Prosedur loading, SOP seal, dan dokumentasi sebelum jalan.</p>
                </div>
                <div className="cvant-feature-card cvant-animate-up cvant-delay-2">
                  <div className="cvant-card-head">
                    <Icon
                      icon="solar:hand-shake-linear"
                      className="cvant-card-icon"
                      style={{ fontSize: "26px" }}
                    />
                    <h5>Support cepat</h5>
                  </div>
                  <p>Tim CS responsif untuk perubahan jadwal atau kebutuhan urgent.</p>
                </div>
              </div>
            </div>
          </section>

          <section id="armada" className="cvant-section cvant-reveal">
            <div className="cvant-container">
              <div className="cvant-section-heading cvant-section-center">
                <h2 className="cvant-section-title">Pilihan armada fleksibel</h2>
                <p className="cvant-section-desc">
                  Dari pengiriman retail hingga project besar, armada kami siap
                  menyesuaikan kebutuhan muatan.
                </p>
                {armadaReady && armadas.length > 0 ? (
                  <div className="cvant-section-meta">
                    Total armada terdaftar: {armadas.length}
                  </div>
                ) : null}
              </div>
              {!armadaReady ? (
                <p className="cvant-section-desc">Memuat data armada...</p>
              ) : fleetItems.length === 0 ? (
                <p className="cvant-section-desc">Data armada belum tersedia.</p>
              ) : (
                <div className="cvant-fleet-slider">
                  <div
                    className={`cvant-fleet-track ${
                      fleetShouldLoop ? "is-looping" : ""
                    }`}
                    style={{ "--fleet-speed": `${fleetSpeed}s` }}
                  >
                    {fleetLoopItems.map((item, index) => {
                      const isDuplicate = fleetShouldLoop && index >= fleetItems.length;
                      return (
                        <div
                          className="cvant-fleet-card"
                          key={`${item.name}-${index}`}
                          aria-hidden={isDuplicate ? "true" : undefined}
                        >
                          <h5>{item.name}</h5>
                          <p className="cvant-section-desc">Kapasitas (Tonase): {item.tonnage}</p>
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}
            </div>
          </section>

          <section id="alur" className="cvant-section cvant-reveal">
            <div className="cvant-container">
              <div className="cvant-section-heading cvant-section-center">
                <h2 className="cvant-section-title">Alur order yang simple</h2>
                <p className="cvant-section-desc">
                  Login, buat order, dan selesaikan pembayaran dalam satu alur
                  yang terstruktur.
                </p>
              </div>
              <div className="cvant-step-grid">
                <div className="cvant-step">
                  <div className="cvant-step-head">
                    <span>1</span>
                    <h5>Daftar atau masuk</h5>
                  </div>
                  <p className="cvant-section-desc">
                    Buat akun customer agar detail order tersimpan rapi.
                  </p>
                </div>
                <div className="cvant-step">
                  <div className="cvant-step-head">
                    <span>2</span>
                    <h5>Isi detail pengiriman</h5>
                  </div>
                  <p className="cvant-section-desc">
                    Pilih armada, rute, dan jadwal pickup sesuai kebutuhan.
                  </p>
                </div>
                <div className="cvant-step">
                  <div className="cvant-step-head">
                    <span>3</span>
                    <h5>Pembayaran gateway</h5>
                  </div>
                  <p className="cvant-section-desc">
                    Selesaikan pembayaran via transfer, VA, atau e-wallet.
                  </p>
                </div>
              </div>
            </div>
          </section>

          <section className="cvant-section cvant-reveal">
            <div className="cvant-container">
              <div className="cvant-section-heading cvant-section-center">
                <h2 className="cvant-section-title">Apa kata customer</h2>
                <p className="cvant-section-desc">
                  Klien kami menjaga jadwal distribusi dengan bantuan monitoring
                  dan support dari tim CV ANT.
                </p>
              </div>
              <div className="cvant-testimonial-slider">
                <div
                  className="cvant-testimonial-track"
                  style={{
                    transform: `translateX(-${testimonialIndex * 100}%)`,
                  }}
                >
                  {testimonialSlides.map((slide, index) => (
                    <div className="cvant-testimonial-slide" key={`slide-${index}`}>
                      {slide.map((item) => (
                        <div className="cvant-testimonial" key={item.name}>
                          <p className="cvant-section-desc">"{item.quote}"</p>
                          <strong>{item.name}</strong>
                        </div>
                      ))}
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </section>

          <section id="faq" className="cvant-section cvant-reveal">
            <div className="cvant-container">
              <div className="cvant-section-heading cvant-section-center">
                <h2 className="cvant-section-title">FAQ singkat</h2>
              </div>
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

          <section className="cvant-cta cvant-reveal">
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
            <div className="cvant-footer-note">
              c 2025 CV ANT. All Rights Reserved.
            </div>
          </div>
        </footer>

        <PublicChatbotWidget />
      </div>
    </>
  );
};

export default LandingPageLayer;
