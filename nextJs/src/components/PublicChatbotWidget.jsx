"use client";

import { useEffect, useRef, useState } from "react";
import { Icon } from "@iconify/react/dist/iconify.js";
import { publicApi } from "@/lib/publicApi";

const restrictedKeywords = [
  "income",
  "expense",
  "invoice",
  "laporan",
  "report",
  "pendapatan",
  "pengeluaran",
  "pemasukan",
];

const aboutKeywords = [
  "tentang",
  "about",
  "profil",
  "perusahaan",
  "website",
  "web",
  "situs",
  "site",
  "ini website apa",
  "website apa",
  "situs apa",
  "web apa",
  "cv ant",
  "cvant",
  "as nusa trans",
  "nama perusahaan",
  "alamat",
  "kontak",
  "contact",
  "lokasi",
  "telepon",
  "telp",
  "email",
];

const signupKeywords = [
  "daftar",
  "registrasi",
  "register",
  "sign up",
  "signup",
  "buat akun",
  "mendaftar",
  "pendaftaran",
  "akun customer",
];

const orderKeywords = [
  "cara order",
  "buat order",
  "order sekarang",
  "pemesanan",
  "pesan order",
  "cara pesan",
];

const infoKeywords = [
  "info",
  "informasi",
  "layanan",
  "keunggulan",
  "alur",
  "faq",
  "harga",
  "service",
];

const armadaKeywords = ["armada", "truk", "truck", "cdd", "fuso", "trailer", "box"];
const armadaCountKeywords = [
  "total armada",
  "jumlah armada",
  "berapa armada",
  "total truk",
  "jumlah truk",
];
const dateKeywords = ["tanggal", "jadwal", "schedule", "pickup", "pick up", "pengiriman"];

const extractDateFromText = (text) => {
  const isoMatch = text.match(/\b(20\d{2})-(\d{2})-(\d{2})\b/);
  if (isoMatch) {
    const [, yyyy, mm, dd] = isoMatch;
    return { iso: `${yyyy}-${mm}-${dd}`, display: `${dd}-${mm}-${yyyy}` };
  }

  const idMatch = text.match(/\b(\d{2})-(\d{2})-(\d{4})\b/);
  if (idMatch) {
    const [, dd, mm, yyyy] = idMatch;
    return { iso: `${yyyy}-${mm}-${dd}`, display: `${dd}-${mm}-${yyyy}` };
  }

  const lower = text.toLowerCase();
  const today = new Date();
  if (lower.includes("hari ini")) {
    return { iso: today.toISOString().slice(0, 10), display: today.toLocaleDateString("id-ID") };
  }
  if (lower.includes("besok")) {
    const t = new Date(today);
    t.setDate(today.getDate() + 1);
    return { iso: t.toISOString().slice(0, 10), display: t.toLocaleDateString("id-ID") };
  }
  if (lower.includes("lusa")) {
    const t = new Date(today);
    t.setDate(today.getDate() + 2);
    return { iso: t.toISOString().slice(0, 10), display: t.toLocaleDateString("id-ID") };
  }

  return null;
};

const formatTonnage = (value) => {
  if (value == null || String(value).trim() === "") return "-";
  const raw = String(value).trim();
  if (/ton/i.test(raw)) return raw;
  return `${raw} ton`;
};

const normalizeArmadas = (payload) => {
  if (Array.isArray(payload)) return payload;
  if (Array.isArray(payload?.data)) return payload.data;
  if (Array.isArray(payload?.armadas)) return payload.armadas;
  if (Array.isArray(payload?.items)) return payload.items;
  return [];
};

const companyProfile = {
  name: "CV AS Nusa Trans (CV ANT)",
};

const buildAboutResponse = () =>
  `Website ini adalah website resmi ${companyProfile.name}.\n\nKami fokus pada pengiriman logistik yang aman, terukur, dan transparan untuk kebutuhan bisnis.`;

const buildSignupResponse = () =>
  "Langkah daftar akun customer:\n1) Buka landing page lalu klik Daftar Customer.\n2) Isi biodata (nama, username, email, HP, gender, tanggal lahir, alamat, kota, perusahaan, password).\n3) Klik Daftar.\n4) Login lewat menu Sign In.";

const buildOrderResponse = () =>
  "Cara order:\n1) Login terlebih dahulu.\n2) Klik Buat Order atau Order Sekarang.\n3) Isi rute, jadwal pickup, armada, dan layanan.\n4) Konfirmasi detail lalu bayar via gateway.\n5) Pantau status di dashboard customer.";

const buildLandingSummary = (armadas) => {
  const total = Array.isArray(armadas) ? armadas.length : 0;
  const armadaInfo =
    total > 0
      ? `Armada terdaftar saat ini: ${total} unit.`
      : "Armada tersedia beragam (box, fuso, trailer, dll).";

  return `Info umum CV ANT:\n- ${companyProfile.name}\n- Keunggulan: tracking akurat, keamanan barang, support cepat.\n- ${armadaInfo}\n- Alur order: daftar/masuk, isi detail pengiriman, pembayaran gateway.\n\nTanya saya untuk detail cara daftar atau cara order.`;
};

const buildArmadaResponse = (armadas) => {
  const list = Array.isArray(armadas) ? armadas : [];
  if (list.length === 0) {
    return "Data armada belum tersedia. Silakan tanyakan tanggal pengiriman dulu.";
  }

  const total = list.length;
  const lines = list.slice(0, 6).map((item) => {
    const name = item?.nama_truk || "Armada";
    const tonnage = formatTonnage(item?.kapasitas);
    return `- ${name} (${tonnage})`;
  });

  return `Total armada tersedia: ${total} unit.\nInfo armada:\n${lines.join(
    "\n"
  )}\n\nSebutkan tanggal pengiriman agar kami cek ketersediaan.`;
};

const buildDateResponse = (dateInfo) => {
  if (!dateInfo) {
    return "Silakan sebutkan tanggal pengiriman (contoh: 2026-01-20 atau 20-01-2026).";
  }
  return `Baik, tanggal ${dateInfo.display} dicatat. Armada apa yang kamu butuhkan?`;
};

const getReply = (text, armadas) => {
  const lower = String(text || "").toLowerCase();

  if (restrictedKeywords.some((keyword) => lower.includes(keyword))) {
    return "Maaf, chatbot ini hanya melayani informasi umum dan pemesanan.";
  }

  if (signupKeywords.some((keyword) => lower.includes(keyword))) {
    return buildSignupResponse();
  }

  if (orderKeywords.some((keyword) => lower.includes(keyword))) {
    return buildOrderResponse();
  }

  if (aboutKeywords.some((keyword) => lower.includes(keyword))) {
    return buildAboutResponse();
  }

  if (armadaCountKeywords.some((keyword) => lower.includes(keyword))) {
    const total = Array.isArray(armadas) ? armadas.length : 0;
    return total > 0
      ? `Total armada tersedia: ${total} unit.`
      : "Data armada belum tersedia.";
  }

  if (armadaKeywords.some((keyword) => lower.includes(keyword))) {
    return buildArmadaResponse(armadas);
  }

  if (dateKeywords.some((keyword) => lower.includes(keyword))) {
    return buildDateResponse(extractDateFromText(lower));
  }

  const dateInfo = extractDateFromText(lower);
  if (dateInfo) {
    return buildDateResponse(dateInfo);
  }

  if (infoKeywords.some((keyword) => lower.includes(keyword))) {
    return buildLandingSummary(armadas);
  }

  return "Saya siap bantu info umum CV ANT, cara daftar akun, cara order, armada, dan jadwal pengiriman. Silakan tanyakan ya.";
};

const PublicChatbotWidget = () => {
  const defaultMessage =
    "Halo! Saya asisten CV ANT. Saya bisa bantu info umum, cara daftar akun, cara order, armada, dan jadwal pengiriman.";
  const [open, setOpen] = useState(false);
  const [messages, setMessages] = useState([
    {
      role: "assistant",
      content: defaultMessage,
    },
  ]);
  const [input, setInput] = useState("");
  const [armadas, setArmadas] = useState([]);
  const listRef = useRef(null);

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
      }
    };

    loadArmadas();

    return () => {
      mounted = false;
    };
  }, []);

  useEffect(() => {
    if (!listRef.current) return;
    listRef.current.scrollTop = listRef.current.scrollHeight;
  }, [messages, open]);

  const sendMessage = () => {
    const trimmed = input.trim();
    if (!trimmed) return;

    setMessages((prev) => [...prev, { role: "user", content: trimmed }]);
    setInput("");

    const reply = getReply(trimmed, armadas);
    setTimeout(() => {
      setMessages((prev) => [...prev, { role: "assistant", content: reply }]);
    }, 300);
  };

  const resetChat = () => {
    setMessages([
      {
        role: "assistant",
        content: defaultMessage,
      },
    ]);
    setInput("");
  };

  const handleSubmit = (event) => {
    event.preventDefault();
    sendMessage();
  };

  const handleKeyDown = (event) => {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      sendMessage();
    }
  };

  return (
    <div className={`cvant-chatbot ${open ? "open" : ""}`}>
      <button
        type="button"
        className="cvant-chatbot__toggle"
        onClick={() => setOpen((prev) => !prev)}
        aria-label={open ? "Tutup chatbot" : "Buka chatbot"}
      >
        <Icon icon={open ? "solar:close-circle-bold" : "fluent:chat-24-filled"} />
      </button>

      {open && (
        <div className="cvant-chatbot__panel">
          <div className="cvant-chatbot__header">
            <div>
              <div className="cvant-chatbot__title">Asisten CV ANT</div>
              <div className="cvant-chatbot__subtitle">Info umum & pemesanan</div>
            </div>
            <button type="button" className="cvant-chatbot__clear" onClick={resetChat}>
              Reset Chat
            </button>
          </div>

          <div className="cvant-chatbot__messages" ref={listRef}>
            {messages.map((message, index) => (
              <div
                key={`${message.role}-${index}`}
                className={`cvant-chatbot__bubble ${message.role}`}
              >
                {message.content}
              </div>
            ))}
          </div>

          <form className="cvant-chatbot__input" onSubmit={handleSubmit}>
            <textarea
              value={input}
              onChange={(event) => setInput(event.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="Tanya tentang CV ANT"
              aria-label="Tulis pesan"
            />
            <button type="submit" disabled={!input.trim()}>
              <Icon icon="tabler:send" />
            </button>
          </form>
        </div>
      )}

      <style jsx>{`
        .cvant-chatbot {
          position: fixed;
          right: 24px;
          bottom: 24px;
          z-index: 1050;
          display: flex;
          flex-direction: column;
          align-items: flex-end;
          gap: 12px;
        }

        .cvant-chatbot__toggle {
          width: 54px;
          height: 54px;
          border-radius: 999px;
          background: linear-gradient(
            90deg,
            rgba(91, 140, 255, 0.94),
            rgba(168, 85, 247, 0.92)
          );
          color: #fff;
          display: inline-flex;
          align-items: center;
          justify-content: center;
          box-shadow: 0 12px 28px rgba(17, 24, 39, 0.25);
          cursor: pointer;
        }

        .cvant-chatbot__toggle :global(svg) {
          width: 24px;
          height: 24px;
        }

        .cvant-chatbot__panel {
          width: 360px;
          max-height: 520px;
          display: flex;
          flex-direction: column;
          background: var(--white);
          color: var(--text-primary-light);
          border: 1px solid var(--border-color);
          border-radius: 16px;
          overflow: hidden;
          box-shadow: 0 18px 40px rgba(17, 24, 39, 0.18);
        }

        .cvant-chatbot__header {
          padding: 12px 16px;
          background: linear-gradient(
            90deg,
            rgba(91, 140, 255, 0.94),
            rgba(168, 85, 247, 0.92)
          );
          color: #fff;
          display: flex;
          align-items: center;
          justify-content: space-between;
        }

        .cvant-chatbot__title {
          font-weight: 600;
          font-size: 14px;
        }

        .cvant-chatbot__subtitle {
          font-size: 12px;
          opacity: 0.85;
          margin-top: 2px;
        }

        .cvant-chatbot__clear {
          padding: 4px 8px;
          border-radius: 8px;
          border: none;
          background: rgba(255, 255, 255, 0.18);
          color: #fff;
          font-size: 12px;
          cursor: pointer;
        }

        .cvant-chatbot__messages {
          padding: 14px;
          display: flex;
          flex-direction: column;
          gap: 10px;
          overflow-y: auto;
          background: var(--bg-color);
          flex: 1;
          scrollbar-width: thin;
          scrollbar-color: rgba(148, 163, 184, 0.6) transparent;
        }

        .cvant-chatbot__messages::-webkit-scrollbar {
          width: 3px;
        }

        .cvant-chatbot__messages::-webkit-scrollbar-thumb {
          background: rgba(148, 163, 184, 0.6);
          border-radius: 999px;
        }

        .cvant-chatbot__messages::-webkit-scrollbar-track {
          background: transparent;
        }

        .cvant-chatbot__bubble {
          max-width: 80%;
          padding: 10px 12px;
          border-radius: 12px;
          font-size: 13px;
          line-height: 1.5;
          background: var(--white);
          color: var(--text-primary-light);
          box-shadow: 0 6px 16px rgba(17, 24, 39, 0.08);
          align-self: flex-start;
          white-space: pre-wrap;
        }

        .cvant-chatbot__bubble.user {
          align-self: flex-end;
          background: var(--primary-600);
          color: #fff;
        }

        .cvant-chatbot__input {
          display: flex;
          align-items: center;
          gap: 8px;
          padding: 12px;
          border-top: 1px solid var(--border-color);
          background: var(--white);
          font-size: 13px;
        }

        .cvant-chatbot__input textarea {
          flex: 1;
          padding: 6px 10px;
          border-radius: 10px;
          border: 1px solid var(--border-color);
          background: var(--bg-color);
          color: var(--text-primary-light);
          font-size: 13px;
          resize: none;
          height: 32px;
          max-height: 52px;
          min-height: 32px;
          line-height: 1.3;
          overflow-y: auto;
          scrollbar-width: thin;
          scrollbar-color: rgba(148, 163, 184, 0.6) transparent;
        }

        .cvant-chatbot__input textarea::-webkit-scrollbar {
          width: 3px;
        }

        .cvant-chatbot__input textarea::-webkit-scrollbar-thumb {
          background: rgba(148, 163, 184, 0.6);
          border-radius: 999px;
        }

        .cvant-chatbot__input textarea::-webkit-scrollbar-track {
          background: transparent;
        }

        .cvant-chatbot__input textarea::placeholder {
          font-size: 13px !important;
          line-height: 1.2;
          opacity: 0.5;
        }

        .cvant-chatbot__input textarea::-webkit-input-placeholder {
          font-size: 13px !important;
          line-height: 1.2;
          opacity: 0.5;
        }

        .cvant-chatbot__input button {
          width: 38px;
          height: 38px;
          border-radius: 10px;
          border: none;
          background: var(--primary-600);
          color: #fff;
          display: inline-flex;
          align-items: center;
          justify-content: center;
          cursor: pointer;
        }

        .cvant-chatbot__input button:disabled {
          opacity: 0.6;
          cursor: not-allowed;
        }

        .cvant-chatbot__input :global(svg) {
          width: 18px;
          height: 18px;
        }

        @media (max-width: 576px) {
          .cvant-chatbot {
            right: 16px;
            bottom: 16px;
          }

          .cvant-chatbot__panel {
            width: min(92vw, 360px);
            max-height: 65vh;
          }
        }
      `}</style>
    </div>
  );
};

export default PublicChatbotWidget;
