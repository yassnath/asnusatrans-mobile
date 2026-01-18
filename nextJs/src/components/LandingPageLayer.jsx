"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { Icon } from "@iconify/react/dist/iconify.js";
import ThemeToggleButton from "@/helper/ThemeToggleButton";
import PublicChatbotWidget from "@/components/PublicChatbotWidget";
import { publicApi } from "@/lib/publicApi";

const LandingPageLayer = () => {
  const [menuOpen, setMenuOpen] = useState(false);
  const [armadas, setArmadas] = useState([]);
  const [armadaReady, setArmadaReady] = useState(false);

  const navLinks = [
    { label: "Keunggulan", href: "/#keunggulan" },
    { label: "Armada", href: "/#armada" },
    { label: "Alur", href: "/#alur" },
    { label: "Harga", href: "/#harga" },
    { label: "FAQ", href: "/#faq" },
  ];

  const closeMenu = () => setMenuOpen(false);

  useEffect(() => {
    let mounted = true;

    const loadArmadas = async () => {
      try {
        const data = await publicApi.get("/public/armadas");
        if (!mounted) return;
        setArmadas(Array.isArray(data) ? data : []);
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

  const armadaCountLabel = armadaReady ? `${armadas.length} Armada` : "Memuat armada";
  const currentYear = new Date().getFullYear();

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
          display: flex;
          align-items: center;
          justify-content: center;
          align-self: flex-start;
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
          padding: 24px 0 32px;
          border-top: 1px solid var(--cvant-border-soft);
          color: var(--cvant-muted);
          font-size: 14px;
        }

        .cvant-footer-note {
          margin-top: 14px;
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

          .cvant-hero-icon-wrap {
            width: clamp(240px, 70vw, 380px);
          }

          .cvant-hero-badges {
            grid-template-columns: 1fr;
          }

          .cvant-grid,
          .cvant-step-grid,
          .cvant-price-grid {
            grid-template-columns: 1fr;
          }

          .cvant-fleet-card {
            min-width: 200px;
          }

          .cvant-testimonial-grid {
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

          .cvant-fleet-track.is-looping {
            animation: none;
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
                <Link href="/sign-in" className="cvant-btn cvant-btn-ghost">
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
          <section className="cvant-hero cvant-reveal">
            <div className="cvant-container cvant-hero-grid">
              <div className="cvant-animate-up">
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
                    <h4>98% On-time</h4>
                    <p>Pengiriman sesuai SLA</p>
                  </div>
                <div className="cvant-badge-card">
                  <h4>{armadaCountLabel}</h4>
                  <p>Armada terdaftar di dashboard</p>
                </div>
                  <div className="cvant-badge-card">
                    <h4>24 Kota</h4>
                    <p>Jaringan operasional utama</p>
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
                    alt=""
                    className="cvant-hero-icon"
                  />
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

          <section id="harga" className="cvant-section cvant-reveal">
            <div className="cvant-container">
              <div className="cvant-section-heading cvant-section-center">
                <h2 className="cvant-section-title">Paket layanan fleksibel</h2>
                <p className="cvant-section-desc">
                  Tentukan skema layanan yang sesuai dengan ritme bisnis Anda.
                </p>
              </div>
              <div className="cvant-price-grid">
                <div className="cvant-price-card">
                  <h4>Harian</h4>
                  <p>Distribusi rutin untuk rute kota ke kota</p>
                  <div className="cvant-price">Mulai Rp 320k</div>
                  <Link href="/order" className="cvant-btn cvant-btn-ghost">
                    Pilih Harian
                  </Link>
                </div>
                <div className="cvant-price-card">
                  <h4>Priority</h4>
                  <p>Slot pickup prioritas dan monitoring intensif</p>
                  <div className="cvant-price">Mulai Rp 480k</div>
                  <Link href="/order" className="cvant-btn cvant-btn-primary">
                    Pilih Priority
                  </Link>
                </div>
                <div className="cvant-price-card">
                  <h4>Project Charter</h4>
                  <p>Armada dedicated untuk kontrak dan proyek besar</p>
                  <div className="cvant-price">Custom</div>
                  <Link href="/order" className="cvant-btn cvant-btn-ghost">
                    Konsultasi Project
                  </Link>
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

        <footer className="cvant-footer cvant-reveal">
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
            <div className="cvant-footer-note">
              Copyright {currentYear} CV ANT. All rights reserved.
            </div>
          </div>
        </footer>

        <PublicChatbotWidget />
      </div>
    </>
  );
};

export default LandingPageLayer;
