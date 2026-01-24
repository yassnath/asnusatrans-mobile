"use client";

import { useSearchParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { api } from "@/lib/api";
import { formatInvoiceNumber } from "@/lib/invoiceNumber";
import { storeInvoiceNotification } from "@/lib/notificationUtils";
import Image from "next/image";

function useCvAntPageIn() {
  const [pageIn, setPageIn] = useState(false);

  useEffect(() => {
    const t = requestAnimationFrame(() => setPageIn(true));
    return () => cancelAnimationFrame(t);
  }, []);

  return pageIn;
}

export default function InvoicePreviewLayer() {
  const pageIn = useCvAntPageIn();

  const searchParams = useSearchParams();
  const id = searchParams.get("id");

  const [invoice, setInvoice] = useState(null);
  const [armadas, setArmadas] = useState([]);
  const [sending, setSending] = useState(false);
  const [notifying, setNotifying] = useState(false);
  const [notifyMessage, setNotifyMessage] = useState(null);

  // ✅ API base dari env (dibersihkan)
  const apiBase = useMemo(() => {
    let base = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080";
    base = String(base).replace(/\/+$/, "");
    return base;
  }, []);

  // ✅ Public site base: untuk link yang dibuka customer
  const siteBase = useMemo(() => {
    if (typeof window !== "undefined") {
      return (
        (process.env.NEXT_PUBLIC_SITE_URL || window.location.origin).replace(
          /\/+$/,
          ""
        )
      );
    }
    return (process.env.NEXT_PUBLIC_SITE_URL || "").replace(/\/+$/, "");
  }, []);

  useEffect(() => {
    if (id) {
      api
        .get(`/invoices/${id}`)
        .then((res) => setInvoice(res))
        .catch(() => {});
    }
  }, [id]);

  useEffect(() => {
    api
      .get("/armadas")
      .then((res) => setArmadas(Array.isArray(res) ? res : []))
      .catch(() => setArmadas([]));
  }, []);

  const toInt = (val) => Math.round(parseFloat(val) || 0);

  const formatDate = (dateStr) => {
    if (!dateStr) return "-";
    const d = new Date(dateStr);
    if (isNaN(d)) return "-";
    const dd = String(d.getDate()).padStart(2, "0");
    const mm = String(d.getMonth() + 1).padStart(2, "0");
    const yyyy = d.getFullYear();
    return `${dd}-${mm}-${yyyy}`;
  };

  const platById = useMemo(() => {
    const map = new Map();
    for (const a of armadas) {
      if (a?.id != null) map.set(String(a.id), a?.plat_nomor || "");
    }
    return map;
  }, [armadas]);

  const rows = useMemo(() => {
    if (!invoice) return [];

    const rin = Array.isArray(invoice?.rincian) ? invoice.rincian : [];

    const resolvePlatFromRincian = (r) => {
      const direct =
        r?.armada?.plat_nomor ||
        r?.armada_plat ||
        r?.plat ||
        r?.plat_nomor ||
        "";

      if (direct && String(direct).trim()) return String(direct);

      const idKey = r?.armada_id != null ? String(r.armada_id) : "";
      if (idKey && platById.has(idKey)) return platById.get(idKey) || "-";

      return "-";
    };

    if (rin.length > 0) {
      return rin.map((r) => {
        const ton = toInt(r?.tonase);
        const hrg = toInt(r?.harga);
        const rowSubtotal = ton * hrg;

        return {
          lokasi_muat: r?.lokasi_muat || "-",
          lokasi_bongkar: r?.lokasi_bongkar || "-",
          armada_plat: resolvePlatFromRincian(r),
          armada_start_date: r?.armada_start_date || null,
          armada_end_date: r?.armada_end_date || null,
          tonase: ton,
          harga: hrg,
          subtotal: rowSubtotal,
        };
      });
    }

    const ton = toInt(invoice?.tonase);
    const hrg = toInt(invoice?.harga);
    const rowSubtotal = ton * hrg;

    return [
      {
        lokasi_muat: invoice?.lokasi_muat || "-",
        lokasi_bongkar: invoice?.lokasi_bongkar || "-",
        armada_plat: invoice?.armada?.plat_nomor || "-",
        armada_start_date: invoice?.armada_start_date || null,
        armada_end_date: invoice?.armada_end_date || null,
        tonase: ton,
        harga: hrg,
        subtotal: rowSubtotal,
      },
    ];
  }, [invoice, platById]);

  const subtotal = useMemo(() => {
    return rows.reduce((sum, r) => sum + (toInt(r?.subtotal) || 0), 0);
  }, [rows]);

  const pph = useMemo(() => Math.round(subtotal * 0.02), [subtotal]);
  const totalBayar = useMemo(() => subtotal - pph, [subtotal, pph]);

  /**
   * ✅ PRINT CENTER-IN FIX:
   * - invoice benar-benar di tengah halaman (horizontal)
   * - tetap naik (lift) supaya 1 page
   * - zoom dinamis
   */
  useEffect(() => {
    const STYLE_ID = "invoice-print-dynamic";

    const applyPrint = () => {
      const isPortrait = rows.length > 3;

      const baseZoom = isPortrait ? 0.86 : 0.91;
      const extraCut = Math.max(0, rows.length - 4) * 0.03;
      const zoom = Math.max(0.7, baseZoom - extraCut);

      const liftMm = isPortrait ? 8 : 10;
      const lift = Math.min(14, liftMm + Math.max(0, rows.length - 4) * 1);

      let el = document.getElementById(STYLE_ID);
      if (!el) {
        el = document.createElement("style");
        el.id = STYLE_ID;
        document.head.appendChild(el);
      }

      el.textContent = `
        @media print {
          @page { size: A4 ${isPortrait ? "portrait" : "landscape"}; margin: 6mm 6mm; }

          .invoice-paper {
            position: relative !important;
            left: 50% !important;
            transform: translate(-50%, -${lift}mm) scale(${zoom}) !important;
            transform-origin: top center !important;
          }

          .invoice-paper.container {
            padding-top: 0 !important;
            margin-top: 0 !important;
          }

          .invoice-footer-note {
            margin-top: 4px !important;
            line-height: 1.15 !important;
          }

          .invoice-sign {
            margin-top: 8px !important;
          }

          .invoice-sign p.mb-5 {
            margin-bottom: 10px !important;
          }

          .mt-5 { margin-top: 8px !important; }
          .mb-4 { margin-bottom: 6px !important; }
          .pb-3 { padding-bottom: 5px !important; }

          .invoice-watermark {
            position: fixed !important;
            top: 50% !important;
            left: 50% !important;
            transform: translate(-50%, -50%) !important;
            opacity: 0.07 !important;
            z-index: 0 !important;
            pointer-events: none !important;
          }

          html, body {
            height: auto !important;
            overflow: hidden !important;
          }

          .invoice-paper,
          .invoice-paper * {
            page-break-inside: avoid !important;
            break-inside: avoid !important;
          }

          .invoice-detail-table,
          .invoice-detail-table * {
            page-break-inside: auto !important;
            break-inside: auto !important;
          }
        }
      `;
    };

    const cleanup = () => {
      const el = document.getElementById(STYLE_ID);
      if (el) el.remove();
    };

    window.addEventListener("beforeprint", applyPrint);
    window.addEventListener("afterprint", cleanup);

    return () => {
      window.removeEventListener("beforeprint", applyPrint);
      window.removeEventListener("afterprint", cleanup);
      cleanup();
    };
  }, [rows.length]);

  /**
   * ✅ SEKARANG CUSTOMER LANGSUNG BUKA PDF
   * Tidak ada viewer page lagi
   *
   * PENTING:
   * - siteBase = domain Next.js (asnusatrans.online)
   * - pdf public harus lewat route Next:
   *   /invoice/:id/pdf
   * BUKAN /api/public/... (itu ga ada di Next)
   */
  // ✅ Link publik untuk customer (halaman preview + tombol download)
  const getPublicInvoicePublicPageUrl = (invoiceId) => {
    return `${siteBase}/invoice/${invoiceId}`;
  };

  // ✅ Direct PDF (untuk tombol "Open PDF")
  const getPublicInvoicePdfUrl = (invoiceId) => {
    return `${siteBase}/invoice/${invoiceId}/pdf`;
  };

  const handleSendToEmail = async () => {
    if (!invoice) return;
    setSending(true);

    try {
      // ✅ Kirim LINK halaman publik (preview PDF)
      const publicUrl = getPublicInvoicePublicPageUrl(invoice.id);

      const invoiceNumber = formatInvoiceNumber(
        invoice.no_invoice,
        invoice.tanggal
      );
      const subject = encodeURIComponent(`Invoice ${invoiceNumber}`);
      const body = encodeURIComponent(
        `Yth. ${invoice.nama_pelanggan},\n\n` +
          `Silakan klik berikut untuk melihat invoice:\n${publicUrl}\n\n` +
          `Terima kasih,\nCV AS Nusa Trans (CV ANT)`
      );

      const to = encodeURIComponent(invoice.email || "");
      const gmailUrl = `https://mail.google.com/mail/?view=cm&fs=1&to=${to}&su=${subject}&body=${body}`;

      window.open(gmailUrl, "_blank");
    } catch (e) {
      alert(
        `Gagal membuat link PDF publik.\n\n${e?.message || "Unknown error"}`
      );
    } finally {
      setSending(false);
    }
  };

  const handleSendToCustomer = () => {
    if (!invoice) return;
    const customerEmail = invoice.email || "";
    if (!String(customerEmail).trim()) {
      setNotifyMessage({
        type: "error",
        text: "Email customer tidak tersedia.",
      });
      return;
    }

    setNotifying(true);
    const invoiceNumber = formatInvoiceNumber(
      invoice.no_invoice,
      invoice.tanggal
    );
    const stored = storeInvoiceNotification({
      invoiceId: invoice.id,
      customerEmail,
      customerName: invoice.nama_pelanggan,
      invoiceNumber,
      time: new Date().toISOString(),
    });

    setNotifyMessage(
      stored
        ? { type: "success", text: "Invoice terkirim ke notifikasi customer." }
        : { type: "error", text: "Gagal mengirim notifikasi invoice." }
    );
    setNotifying(false);
  };

  const handleOpenPdf = () => {
    if (!invoice) return;

    // ✅ langsung buka PDF public via Next route
    const pdfUrl = getPublicInvoicePdfUrl(invoice.id);
    window.open(pdfUrl, "_blank");
  };

  const cellStyle = {
    fontSize: "15px",
    whiteSpace: "nowrap",
    lineHeight: 1.2,
    verticalAlign: "middle",
  };

  const headStyle = {
    ...cellStyle,
    fontWeight: 700,
  };

  const money = (n) => `Rp ${toInt(n).toLocaleString("id-ID")}`;

  if (!invoice) {
    return (
      <div className="container py-5 text-center text-muted">
        Memuat data invoice...
      </div>
    );
  }

  return (
    <>
      <div className={`cvant-page-in ${pageIn ? "is-in" : ""}`}>
        <div className="d-flex justify-content-end gap-3 no-print">
          <button
            className="btn btn-sm btn-outline-primary"
            onClick={() =>
              (window.location.href = `/invoice-edit?id=${invoice.id}`)
            }
          >
            Edit
          </button>

          <button
            className="btn btn-sm btn-outline-success"
            onClick={handleOpenPdf}
          >
            Open PDF
          </button>

          <button
            className="btn btn-sm btn-outline-info"
            onClick={handleSendToCustomer}
            disabled={notifying}
          >
            {notifying ? "Sending..." : "Send to Customer"}
          </button>

          <button
            className="btn btn-sm btn-outline-secondary"
            onClick={handleSendToEmail}
            disabled={sending}
          >
            {sending ? "Sending..." : "Send to Email"}
          </button>
        </div>

        {notifyMessage ? (
          <div
            className={`alert mt-3 ${
              notifyMessage.type === "success" ? "alert-success" : "alert-danger"
            }`}
          >
            {notifyMessage.text}
          </div>
        ) : null}

        <div className="invoice-screen">
          <div className="container my-3 p-5 bg-white rounded shadow-sm position-relative invoice-paper">
            <div
              className="position-absolute top-50 start-50 translate-middle invoice-watermark"
              style={{ opacity: 0.1, zIndex: 0 }}
            >
              <Image
                src="/assets/images/icon.png"
                alt="CV ANT Logo"
                width={500}
                height={500}
                className="user-select-none"
              />
            </div>

            <div className="position-relative z-1">
              <div className="d-flex justify-content-between align-items-start border-bottom pb-3 mb-4 invoice-header">
                <div className="invoice-header-left">
                  <h4 className="fw-bold mb-1 text-primary invoice-company-title">
                    CV AS Nusa Trans
                  </h4>
                  <div className="text-dark invoice-company-line">
                    Ruko Graha Kota Blok BB-07, Suko, Sidoarjo
                  </div>
                  <div className="text-dark invoice-company-line">
                    Email: asnusa.trans@gmail.com
                  </div>
                  <div className="text-dark invoice-company-line">
                    Telp: 0812-3425-9399
                  </div>
                </div>
                <div className="text-end text-dark invoice-header-right">
                  <h4 className="fw-bold text-dark mb-2 invoice-title">
                    INVOICE
                  </h4>
                  <div className="invoice-info-line">
                    <strong>No. Invoice:</strong>{" "}
                    {formatInvoiceNumber(invoice.no_invoice, invoice.tanggal)}
                  </div>
                  <div className="invoice-info-line">
                    <strong>Tanggal:</strong> {formatDate(invoice.tanggal)}
                  </div>
                  <div className="invoice-info-line">
                    <strong>Jatuh Tempo:</strong>{" "}
                    {invoice.due_date ? formatDate(invoice.due_date) : "-"}
                  </div>
                </div>
              </div>

              <div className="row mb-4 text-dark invoice-customer">
                <div className="col-md-6 invoice-from">
                  <h6 className="fw-bold text-dark invoice-section-title">
                    Dari:
                  </h6>
                  <p className="mb-1">CV. AS Nusa Trans</p>
                  <p className="mb-1">
                    Ruko Graha Kota Blok BB-07, Sidoarjo
                  </p>
                  <p>Telp: 0812-3425-9399 | asnusa.trans@gmail.com</p>
                </div>

                <div className="col-md-6 text-end invoice-to">
                  <h6 className="fw-bold text-dark invoice-section-title">
                    Kepada:
                  </h6>
                  <p className="mb-1">{invoice.nama_pelanggan}</p>
                  <p className="mb-1">{invoice.email}</p>
                  <p>{invoice.no_telp}</p>
                </div>
              </div>

              <div className="px-4 invoice-table-wrap invoice-table-responsive">
                <table className="table table-bordered text-center align-middle bg-white invoice-detail-table">
                  <thead className="table-dark text-center invoice-detail-head">
                    <tr>
                      <th style={headStyle}>Lokasi Muat</th>
                      <th style={headStyle}>Lokasi Bongkar</th>
                      <th style={headStyle}>Armada</th>
                      <th style={headStyle}>Berangkat</th>
                      <th style={headStyle}>Sampai</th>
                      <th style={headStyle}>Tonase</th>
                      <th style={headStyle}>Harga / Ton</th>
                      <th style={headStyle}>Subtotal</th>
                    </tr>
                  </thead>

                  <tbody className="invoice-detail-body">
                    {rows.map((r, idx) => (
                      <tr key={idx}>
                        <td style={cellStyle} title={r.lokasi_muat}>
                          <span className="cell-2line">{r.lokasi_muat}</span>
                        </td>
                        <td style={cellStyle} title={r.lokasi_bongkar}>
                          <span className="cell-2line">{r.lokasi_bongkar}</span>
                        </td>
                        <td style={cellStyle}>
                          <span className="cell-2line">
                            {r.armada_plat || "-"}
                          </span>
                        </td>
                        <td style={cellStyle}>
                          <span className="cell-2line">
                            {r.armada_start_date
                              ? formatDate(r.armada_start_date)
                              : "-"}
                          </span>
                        </td>
                        <td style={cellStyle}>
                          <span className="cell-2line">
                            {r.armada_end_date
                              ? formatDate(r.armada_end_date)
                              : "-"}
                          </span>
                        </td>
                        <td style={cellStyle}>
                          <span className="cell-2line">{toInt(r.tonase)}</span>
                        </td>
                        <td style={cellStyle}>
                          <span className="cell-2line">{money(r.harga)}</span>
                        </td>
                        <td style={cellStyle}>
                          <span className="cell-2line">{money(r.subtotal)}</span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              <div className="d-flex justify-content-between mt-4 invoice-armada-summary">
                <div
                  className="text-dark invoice-armada-left"
                  style={{ maxWidth: "45%" }}
                />
                <table className="table table-sm w-50 invoice-totals">
                  <tbody>
                    <tr>
                      <td className="fw-semibold">Subtotal</td>
                      <td className="text-end">{money(subtotal)}</td>
                    </tr>
                    <tr>
                      <td className="fw-semibold">PPH (2%)</td>
                      <td className="text-end">{money(pph)}</td>
                    </tr>
                    <tr className="fw-bold table-light invoice-totals-bold">
                      <td>Total Bayar</td>
                      <td className="text-end">{money(totalBayar)}</td>
                    </tr>
                  </tbody>
                </table>
              </div>

              <div className="text-dark mt-4 invoice-status">
                <p className="mb-1">
                  <strong>Status:</strong> {invoice.status}
                </p>
                <p className="mb-0">
                  <strong>Diterima oleh:</strong>{" "}
                  {invoice.diterima_oleh || "-"}
                </p>
              </div>

              <div className="mt-5 text-center text-muted small invoice-footer-note">
                Mohon lakukan pembayaran sebelum tanggal jatuh tempo.
                <br />
                Harap konfirmasi pembayaran via WhatsApp: 0812-3425-9399.
              </div>

              <div className="mt-5 text-end text-dark invoice-sign">
                <p className="mb-5">Hormat kami,</p>
                <p className="fw-bold">CV ANT</p>
              </div>
            </div>
          </div>
        </div>

        {/* ✅ STYLE FIX kamu tidak aku ubah sama sekali */}
        <style jsx global>{`
          .invoice-paper {
            overflow-x: hidden;
          }

          .invoice-table-responsive {
            width: 100%;
            overflow-x: auto;
          }

          .invoice-detail-table th,
          .invoice-detail-table td {
            padding: 8px 10px;
            line-height: 1.15;
            vertical-align: middle;
          }

          .cell-2line {
            display: inline;
          }

          @media (max-width: 991.98px) {
            .invoice-paper.container {
              padding: 18px !important;
            }

            .invoice-detail-table th,
            .invoice-detail-table td {
              font-size: 12px !important;
              padding: 6px 6px !important;
              line-height: 1.15 !important;
              white-space: normal !important;
              word-break: break-word !important;
            }

            .cell-2line {
              display: -webkit-box;
              -webkit-line-clamp: 2;
              -webkit-box-orient: vertical;
              overflow: hidden;
              text-overflow: ellipsis;
              white-space: normal;
            }

            .invoice-detail-table th {
              white-space: nowrap !important;
            }

            .invoice-table-wrap {
              padding-left: 0 !important;
              padding-right: 0 !important;
            }
          }

          @media (max-width: 575.98px) {
            .invoice-paper.container {
              padding: 14px !important;
            }

            .invoice-detail-table th,
            .invoice-detail-table td {
              font-size: 11px !important;
              padding: 5px 5px !important;
            }

            .invoice-title {
              font-size: 20px !important;
            }
            .invoice-company-title {
              font-size: 18px !important;
            }
          }

          @media print {
            html,
            body {
              background: #fff !important;
              -webkit-print-color-adjust: exact !important;
              print-color-adjust: exact !important;
            }

            body * {
              visibility: hidden !important;
            }
            .invoice-screen,
            .invoice-screen * {
              visibility: visible !important;
            }

            .invoice-screen {
              position: absolute !important;
              left: 0 !important;
              top: 0 !important;
              width: 100% !important;
            }

            .no-print {
              display: none !important;
            }

            body {
              overflow: hidden !important;
            }
            .invoice-screen,
            .invoice-paper,
            .invoice-paper * {
              page-break-inside: avoid !important;
              break-inside: avoid !important;
            }

            .invoice-paper.container {
              padding-left: 0 !important;
              padding-right: 0 !important;
              margin-left: 0 !important;
              margin-right: 0 !important;
              max-width: 100% !important;
              width: 100% !important;
            }

            .invoice-paper {
              margin: 0 !important;
              padding: 0 !important;
              border: none !important;
              box-shadow: none !important;
              background: #fff !important;
              border-radius: 0 !important;
            }

            .invoice-screen {
              font-family: DejaVu Sans, Arial, sans-serif !important;
              font-size: 12px !important;
              color: #222 !important;
              line-height: 1.5 !important;
            }
            .invoice-screen .text-dark {
              color: #222 !important;
            }

            .invoice-watermark {
              position: fixed !important;
              top: 50% !important;
              left: 50% !important;
              transform: translate(-50%, -50%) !important;
              opacity: 0.07 !important;
              z-index: 0 !important;
              pointer-events: none !important;
            }

            table,
            tr,
            td,
            th {
              page-break-inside: avoid !important;
              break-inside: avoid !important;
            }
          }
        `}</style>
      </div>
    </>
  );
}
