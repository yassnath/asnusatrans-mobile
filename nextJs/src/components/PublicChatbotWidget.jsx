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
    return "Maaf, chatbot ini hanya melayani info armada dan tanggal pengiriman.";
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

  return "Saya hanya bisa bantu info armada dan tanggal pengiriman. Tanyakan armada atau tanggal ya.";
};

const PublicChatbotWidget = () => {
  const [open, setOpen] = useState(false);
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState("");
  const [armadas, setArmadas] = useState([]);
  const listRef = useRef(null);

  useEffect(() => {
    setMessages([
      {
        role: "assistant",
        content:
          "Halo! Saya asisten CV ANT. Saya hanya melayani info armada dan tanggal pengiriman.",
      },
    ]);
  }, []);

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

  const handleKeyDown = (event) => {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      sendMessage();
    }
  };

  return (
    <>
      <style jsx global>{`
        .cvant-public-chatbot {
          position: fixed;
          right: 24px;
          bottom: 24px;
          z-index: 1050;
          display: flex;
          flex-direction: column;
          align-items: flex-end;
          gap: 12px;
        }

        .cvant-chat-toggle {
          width: 54px;
          height: 54px;
          border-radius: 999px;
          border: none;
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

        .cvant-chat-toggle :global(svg) {
          width: 24px;
          height: 24px;
        }

        .cvant-chat-panel {
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

        .cvant-chat-header {
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

        .cvant-chat-title {
          font-weight: 600;
          font-size: 14px;
        }

        .cvant-chat-subtitle {
          font-size: 12px;
          opacity: 0.85;
          margin-top: 2px;
        }

        .cvant-chat-close {
          padding: 4px 8px;
          border-radius: 8px;
          background: rgba(255, 255, 255, 0.18);
          color: #fff;
          font-size: 12px;
          cursor: pointer;
          border: none;
        }

        .cvant-chat-body {
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

        .cvant-chat-body::-webkit-scrollbar {
          width: 3px;
        }

        .cvant-chat-body::-webkit-scrollbar-thumb {
          background: rgba(148, 163, 184, 0.6);
          border-radius: 999px;
        }

        .cvant-chat-body::-webkit-scrollbar-track {
          background: transparent;
        }

        .cvant-chat-bubble {
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

        .cvant-chat-bubble.user {
          align-self: flex-end;
          background: var(--primary-600);
          color: #fff;
        }

        .cvant-chat-footer {
          display: flex;
          align-items: center;
          gap: 8px;
          padding: 12px;
          border-top: 1px solid var(--border-color);
          background: var(--white);
          font-size: 13px;
        }

        .cvant-chat-input {
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

        .cvant-chat-input::-webkit-scrollbar {
          width: 3px;
        }

        .cvant-chat-input::-webkit-scrollbar-thumb {
          background: rgba(148, 163, 184, 0.6);
          border-radius: 999px;
        }

        .cvant-chat-input::-webkit-scrollbar-track {
          background: transparent;
        }

        .cvant-chat-input::placeholder {
          font-size: 13px !important;
          line-height: 1.2;
          opacity: 0.5;
        }

        .cvant-chat-input::-webkit-input-placeholder {
          font-size: 13px !important;
          line-height: 1.2;
          opacity: 0.5;
        }

        .cvant-chat-send {
          width: 38px;
          height: 38px;
          border-radius: 10px;
          background: var(--primary-600);
          color: #fff;
          display: inline-flex;
          align-items: center;
          justify-content: center;
          cursor: pointer;
          border: none;
        }

        .cvant-chat-send:disabled {
          opacity: 0.6;
          cursor: not-allowed;
        }

        .cvant-chat-send :global(svg) {
          width: 18px;
          height: 18px;
        }

        @media (max-width: 576px) {
          .cvant-public-chatbot {
            right: 16px;
            bottom: 16px;
          }

          .cvant-chat-panel {
            width: min(92vw, 360px);
            max-height: 65vh;
          }
        }
      `}</style>

      <div className="cvant-public-chatbot">
        {open && (
          <div className="cvant-chat-panel">
            <div className="cvant-chat-header">
              <div>
                <div className="cvant-chat-title">CV ANT Chatbot</div>
                <div className="cvant-chat-subtitle">Info armada & tanggal</div>
              </div>
              <button type="button" className="cvant-chat-close" onClick={() => setOpen(false)}>
                <Icon icon="radix-icons:cross-2" />
              </button>
            </div>
            <div className="cvant-chat-body" ref={listRef}>
              {messages.map((message, index) => (
                <div
                  key={`${message.role}-${index}`}
                  className={`cvant-chat-bubble ${message.role}`}
                >
                  {message.content}
                </div>
              ))}
            </div>
            <div className="cvant-chat-footer">
              <textarea
                className="cvant-chat-input"
                value={input}
                onChange={(event) => setInput(event.target.value)}
                onKeyDown={handleKeyDown}
                placeholder="Tanya armada atau tanggal..."
              />
              <button
                type="button"
                className="cvant-chat-send"
                onClick={sendMessage}
                disabled={!input.trim()}
              >
                <Icon icon="tabler:send" />
              </button>
            </div>
          </div>
        )}

        <button type="button" className="cvant-chat-toggle" onClick={() => setOpen((v) => !v)}>
          <Icon icon={open ? "solar:close-circle-bold" : "fluent:chat-24-filled"} />
        </button>
      </div>
    </>
  );
};

export default PublicChatbotWidget;
