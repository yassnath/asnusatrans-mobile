"use client";

import { useEffect, useRef, useState } from "react";
import { Icon } from "@iconify/react/dist/iconify.js";

const armadaOptions = [
  { name: "Box Medium", note: "Cocok retail, max 4 ton" },
  { name: "CDD Long", note: "Muatan tinggi, jarak menengah" },
  { name: "Fuso Box", note: "Muatan 6-8 ton" },
  { name: "Trailer", note: "Project & heavy cargo" },
];

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

const buildArmadaResponse = () => {
  const lines = armadaOptions.map(
    (item) => `- ${item.name}: ${item.note}`
  );
  return `Info armada tersedia:\n${lines.join("\n")}\n\nSebutkan tanggal pengiriman agar kami cek ketersediaan.`;
};

const buildDateResponse = (dateInfo) => {
  if (!dateInfo) {
    return "Silakan sebutkan tanggal pengiriman (contoh: 2026-01-20 atau 20-01-2026).";
  }
  return `Baik, tanggal ${dateInfo.display} dicatat. Armada apa yang kamu butuhkan?`;
};

const getReply = (text) => {
  const lower = String(text || "").toLowerCase();

  if (restrictedKeywords.some((keyword) => lower.includes(keyword))) {
    return "Maaf, chatbot ini hanya melayani info armada dan tanggal pengiriman.";
  }

  if (armadaKeywords.some((keyword) => lower.includes(keyword))) {
    return buildArmadaResponse();
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
    if (!listRef.current) return;
    listRef.current.scrollTop = listRef.current.scrollHeight;
  }, [messages, open]);

  const sendMessage = () => {
    const trimmed = input.trim();
    if (!trimmed) return;

    setMessages((prev) => [...prev, { role: "user", content: trimmed }]);
    setInput("");

    const reply = getReply(trimmed);
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
          z-index: 9999;
          display: flex;
          flex-direction: column;
          align-items: flex-end;
          gap: 12px;
          --cvant-chat-bg: #0f172a;
          --cvant-chat-text: #e2e8f0;
          --cvant-chat-border: rgba(148, 163, 184, 0.2);
          --cvant-chat-header: #111827;
          --cvant-chat-bubble: rgba(30, 41, 59, 0.7);
        }

        .cvant-chat-toggle {
          height: 54px;
          width: 54px;
          border-radius: 50%;
          border: none;
          background: var(--primary-600);
          color: #fff;
          display: flex;
          align-items: center;
          justify-content: center;
          box-shadow: 0 16px 32px rgba(15, 23, 42, 0.35);
        }

        .cvant-chat-panel {
          width: min(360px, 92vw);
          max-height: 520px;
          background: var(--cvant-chat-bg);
          border: 1px solid var(--cvant-chat-border);
          border-radius: 18px;
          box-shadow: 0 30px 60px rgba(0, 0, 0, 0.35);
          display: flex;
          flex-direction: column;
          overflow: hidden;
        }

        .cvant-chat-header {
          padding: 14px 16px;
          display: flex;
          align-items: center;
          justify-content: space-between;
          background: var(--cvant-chat-header);
          color: var(--cvant-chat-text);
        }

        .cvant-chat-title {
          font-weight: 600;
          font-size: 14px;
        }

        .cvant-chat-body {
          padding: 14px 16px;
          overflow-y: auto;
          display: grid;
          gap: 12px;
          flex: 1;
        }

        .cvant-chat-bubble {
          padding: 10px 12px;
          border-radius: 12px;
          font-size: 13px;
          line-height: 1.5;
          white-space: pre-wrap;
        }

        .cvant-chat-bubble.assistant {
          background: var(--cvant-chat-bubble);
          color: var(--cvant-chat-text);
          border: 1px solid var(--cvant-chat-border);
        }

        .cvant-chat-bubble.user {
          background: var(--primary-600);
          color: #fff;
          justify-self: end;
        }

        .cvant-chat-footer {
          border-top: 1px solid var(--cvant-chat-border);
          padding: 12px 14px;
          display: flex;
          gap: 10px;
          background: var(--cvant-chat-header);
        }

        .cvant-chat-input {
          flex: 1;
          border-radius: 10px;
          border: 1px solid var(--cvant-chat-border);
          background: transparent;
          color: var(--cvant-chat-text);
          padding: 8px 10px;
          font-size: 13px;
          resize: none;
          min-height: 38px;
          max-height: 84px;
        }

        .cvant-chat-send {
          height: 38px;
          min-width: 38px;
          border-radius: 10px;
          border: none;
          background: var(--primary-600);
          color: #fff;
          display: inline-flex;
          align-items: center;
          justify-content: center;
        }

        .cvant-chat-close {
          border: none;
          background: transparent;
          color: var(--cvant-chat-text);
        }

        html[data-theme="light"] .cvant-public-chatbot,
        html[data-bs-theme="light"] .cvant-public-chatbot {
          --cvant-chat-bg: #ffffff;
          --cvant-chat-text: #0f172a;
          --cvant-chat-border: rgba(15, 23, 42, 0.12);
          --cvant-chat-header: #f8fafc;
          --cvant-chat-bubble: #f1f5f9;
        }

        html[data-theme="dark"] .cvant-public-chatbot,
        html[data-bs-theme="dark"] .cvant-public-chatbot {
          --cvant-chat-bg: #0f172a;
          --cvant-chat-text: #e2e8f0;
          --cvant-chat-border: rgba(148, 163, 184, 0.2);
          --cvant-chat-header: #111827;
          --cvant-chat-bubble: rgba(30, 41, 59, 0.7);
        }
      `}</style>

      <div className="cvant-public-chatbot">
        {open && (
          <div className="cvant-chat-panel">
            <div className="cvant-chat-header">
              <div>
                <div className="cvant-chat-title">CV ANT Chatbot</div>
                <div style={{ fontSize: "12px", color: "var(--cvant-chat-text)" }}>
                  Info armada & tanggal
                </div>
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
              <button type="button" className="cvant-chat-send" onClick={sendMessage}>
                <Icon icon="solar:plain-linear" />
              </button>
            </div>
          </div>
        )}

        <button type="button" className="cvant-chat-toggle" onClick={() => setOpen((v) => !v)}>
          <Icon icon="solar:chat-round-line-linear" />
        </button>
      </div>
    </>
  );
};

export default PublicChatbotWidget;
