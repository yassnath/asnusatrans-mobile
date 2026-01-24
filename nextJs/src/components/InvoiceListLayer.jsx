"use client";

import { Icon } from "@iconify/react/dist/iconify.js";
import Link from "next/link";
import React, { useEffect, useState, useMemo } from "react";
import { api } from "@/lib/api";
import { formatInvoiceNumber } from "@/lib/invoiceNumber";
import { storeInvoiceNotification } from "@/lib/notificationUtils";

function useCvAntPageIn() {
  const [pageIn, setPageIn] = useState(false);

  useEffect(() => {
    const t = requestAnimationFrame(() => setPageIn(true));
    return () => cancelAnimationFrame(t);
  }, []);

  return pageIn;
}

function isLightModeNow() {
  if (typeof window === "undefined") return false;

  const html = document.documentElement;
  const body = document.body;

  const bs = (
    html.getAttribute("data-bs-theme") ||
    body?.getAttribute("data-bs-theme") ||
    ""
  ).toLowerCase();
  if (bs === "light") return true;
  if (bs === "dark") return false;

  const dt = (
    html.getAttribute("data-theme") ||
    body?.getAttribute("data-theme") ||
    ""
  ).toLowerCase();
  if (dt === "light") return true;
  if (dt === "dark") return false;

  const cls = `${html.className || ""} ${body?.className || ""}`.toLowerCase();
  if (cls.includes("light") || cls.includes("theme-light")) return true;
  if (cls.includes("dark") || cls.includes("theme-dark")) return false;

  return false;
}

export default function InvoiceListLayer() {
  const pageIn = useCvAntPageIn();

  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [limit, setLimit] = useState(10);
  const [q, setQ] = useState("");

  const [userRole, setUserRole] = useState("");
  const [showPrintModal, setShowPrintModal] = useState(false);
  const [printing, setPrinting] = useState(false);
  const [printError, setPrintError] = useState("");
  const [printingRange, setPrintingRange] = useState("");

  const apiBase = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080";

  const [isLightMode, setIsLightMode] = useState(false);

  useEffect(() => {
    const update = () => setIsLightMode(isLightModeNow());
    update();

    const obs = new MutationObserver(update);
    obs.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-bs-theme", "data-theme", "class", "style"],
    });

    if (document.body) {
      obs.observe(document.body, {
        attributes: true,
        attributeFilter: ["data-bs-theme", "data-theme", "class", "style"],
      });
    }

    return () => obs.disconnect();
  }, []);

  const [popup, setPopup] = useState({
    show: false,
    type: "success",
    message: "",
  });

  const showPopup = (type, message, autoCloseMs = 0) => {
    setPopup({ show: true, type, message });
    window.clearTimeout(showPopup._t);

    if (autoCloseMs > 0) {
      showPopup._t = window.setTimeout(() => {
        setPopup((p) => ({ ...p, show: false }));
      }, autoCloseMs);
    }
  };

  const closePopup = () => setPopup((p) => ({ ...p, show: false }));
  const popupAccent = popup.type === "success" ? "#22c55e" : "#ef4444";

  const [deleteConfirm, setDeleteConfirm] = useState({
    show: false,
    item: null,
    deleting: false,
  });

  const openDeleteConfirm = (item) => {
    setDeleteConfirm({ show: true, item, deleting: false });
  };

  const closeDeleteConfirm = () =>
    setDeleteConfirm({ show: false, item: null, deleting: false });

  const normalizeDate = (value) => {
    if (!value) return "";
    const str = String(value).trim();

    if (/^\d{2}-\d{2}-\d{4}$/.test(str)) {
      const [dd, mm, yyyy] = str.split("-");
      return `${yyyy}-${mm}-${dd}`;
    }
    if (/^\d{4}-\d{2}-\d{2}$/.test(str)) return str;

    if (/^\d{4}-\d{2}-\d{2}T/.test(str)) {
      const d = new Date(str);
      if (!isNaN(d)) {
        const y = d.getFullYear();
        const m = String(d.getMonth() + 1).padStart(2, "0");
        const day = String(d.getDate()).padStart(2, "0");
        return `${y}-${m}-${day}`;
      }
      return str.split("T")[0];
    }

    if (/^\d{4}-\d{2}-\d{2}\s/.test(str)) return str.split(" ")[0];
    return "";
  };

  const toDisplay = (value) => {
    const norm = normalizeDate(value);
    if (!norm) return "-";
    const [y, m, d] = norm.split("-");
    return `${d}-${m}-${y}`;
  };

  const toSortable = (value) => normalizeDate(value) || "";

  useEffect(() => {
    if (typeof window !== "undefined") {
      const r = localStorage.getItem("role") || "";
      setUserRole(r);
    }
  }, []);

  useEffect(() => {
    let mounted = true;
    setLoading(true);

    const load = async () => {
      try {
        const [invoices, expenses] = await Promise.all([
          api.get("/invoices"),
          api.get("/expenses"),
        ]);

        const invList = Array.isArray(invoices)
          ? invoices.map((i) => {
              const normTanggal = normalizeDate(i.tanggal);

              return {
                ...i,
                type: "Income",
                no: formatInvoiceNumber(i.no_invoice, i.tanggal),
                tanggal_raw: normTanggal,
                tanggal_display: toDisplay(i.tanggal),
                total: i.total_bayar,
                nama: i.nama_pelanggan,

                // ✅ untuk mobile info
                recorded_by: i.diterima_oleh || "-",
              };
            })
          : [];

        const expList = Array.isArray(expenses)
          ? expenses.map((e) => {
              const normTanggal = normalizeDate(e.tanggal);
              return {
                ...e,
                type: "Expense",
                no: formatInvoiceNumber(e.no_expense, e.tanggal),
                tanggal_raw: normTanggal,
                tanggal_display: toDisplay(e.tanggal),
                total: e.total_pengeluaran,
                nama: "-",

                // ✅ untuk mobile info
                recorded_by: e.dicatat_oleh || "Admin",
              };
            })
          : [];

        if (mounted) {
          setData([...invList, ...expList]);
          setError("");
        }
      } catch (e) {
        const msg = e?.message || "Gagal memuat data invoice & expense";
        setError(msg);
        showPopup("danger", msg, 0);
      } finally {
        setLoading(false);
      }
    };

    load();
    return () => {
      mounted = false;
    };
  }, []);

  const filtered = useMemo(() => {
    const s = q.trim().toLowerCase();
    let list = data;

    if (s) {
      list = data.filter(
        (i) =>
          (i.nama || "").toLowerCase().includes(s) ||
          (i.no || "").toLowerCase().includes(s)
      );
    }

    list = [...list].sort((a, b) =>
      toSortable(b.tanggal_raw).localeCompare(toSortable(a.tanggal_raw))
    );

    if (limit === "all") return list;

    const n = Number(limit);
    if (!Number.isFinite(n) || n <= 0) return list;

    return list.slice(0, n);
  }, [data, q, limit]);

  const formatRupiah = (num) =>
    new Intl.NumberFormat("id-ID", {
      style: "currency",
      currency: "IDR",
      minimumFractionDigits: 0,
    }).format(num || 0);

  const handleSendInvoice = (item) => {
    if (item?.type !== "Income") return;
    const email = String(item?.email || "").trim();
    if (!email) {
      showPopup("danger", "Email customer tidak tersedia.", 2500);
      return;
    }

    const stored = storeInvoiceNotification({
      invoiceId: item.id,
      customerEmail: email,
      customerName: item.nama,
      invoiceNumber: item.no,
      time: new Date().toISOString(),
    });

    showPopup(
      stored ? "success" : "danger",
      stored
        ? "Invoice dikirim ke notifikasi customer."
        : "Gagal mengirim notifikasi invoice.",
      2500
    );
  };

  const handleGenerateReport = async (range) => {
    try {
      setPrinting(true);
      setPrintingRange(range);
      setPrintError("");

      const token =
        typeof window !== "undefined" ? localStorage.getItem("token") : null;

      if (!token) throw new Error("Token tidak ditemukan. Silakan login ulang.");

      const url = `${apiBase}/api/reports/summary?range=${encodeURIComponent(
        range
      )}&token=${encodeURIComponent(token)}`;

      window.open(url, "_blank");
      setShowPrintModal(false);
    } catch (e) {
      setPrintError(e.message || "Gagal mencetak laporan");
    } finally {
      setPrinting(false);
      setPrintingRange("");
    }
  };

  const searchBg = isLightMode ? "#f5f6fa" : "#1b2431";
  const searchText = isLightMode ? "#0b1220" : "#ffffff";
  const searchBorder = isLightMode ? "#c7c8ca" : "#6c757d";
  const searchIcon = isLightMode ? "#0b1220" : "#ffffff";

  const cardBg = isLightMode ? "#ffffff" : "#1b2431";
  const cardBorder = isLightMode ? "rgba(148,163,184,0.35)" : "#273142";
  const textMain = isLightMode ? "#0b1220" : "#ffffff";
  const textSub = isLightMode ? "#64748b" : "#94a3b8";
  const reportAccent = "#2765ec";

  const mobileActionBtnStyle = {
    width: 44,
    height: 38,
    padding: 0,
    display: "inline-flex",
    alignItems: "center",
    justifyContent: "center",
    lineHeight: 1,
  };

  return (
    <>
      <div className={`cvant-page-in ${pageIn ? "is-in" : ""}`}>
        {showPrintModal && (
          <div
            className="position-fixed top-0 start-0 w-100 h-100 d-flex align-items-center justify-content-center"
            style={{
              zIndex: 9999,
              background: "rgba(0,0,0,0.55)",
              padding: "16px",
            }}
            onClick={() => {
              if (!printing) setShowPrintModal(false);
            }}
          >
            <div
              className="radius-12 shadow-sm p-24 cvant-report-modal"
              style={{
                width: "100%",
                maxWidth: "560px",
                backgroundColor: "#1b2431",
                border: `2px solid ${reportAccent}`,
              }}
              onClick={(e) => e.stopPropagation()}
            >
              <div className="d-flex align-items-start justify-content-between gap-2">
                <div className="d-flex align-items-start gap-12">
                  <span style={{ marginTop: "2px" }}>
                    <Icon
                      icon="mdi:file-document-outline"
                      style={{ fontSize: "28px", color: reportAccent }}
                    />
                  </span>

                  <div>
                    <h5 className="mb-8 fw-bold" style={{ color: "#ffffff" }}>
                      Generate Report
                    </h5>
                    <p
                      className="mb-0"
                      style={{ color: "#cbd5e1", fontSize: "15px" }}
                    >
                      Select the type of report you want to print.
                    </p>
                    {printError && (
                      <p
                        className="mb-0 mt-8"
                        style={{ color: "#fca5a5", fontSize: "14px" }}
                      >
                        {printError}
                      </p>
                    )}
                  </div>
                </div>

                <button
                  type="button"
                  className="btn p-0"
                  aria-label="Close"
                  onClick={() => {
                    if (!printing) setShowPrintModal(false);
                  }}
                  style={{
                    border: "none",
                    background: "transparent",
                    lineHeight: 1,
                  }}
                  disabled={printing}
                >
                  <Icon
                    icon="solar:close-circle-linear"
                    style={{ fontSize: 24, color: "#94a3b8" }}
                  />
                </button>
              </div>

              <div className="d-flex justify-content-end mt-20 gap-2 cvant-report-actions">
                <button
                  type="button"
                  className="btn btn-outline-primary radius-12 px-16"
                  onClick={() => handleGenerateReport("month")}
                  disabled={printing}
                >
                  {printing && printingRange === "month"
                    ? "Creating..."
                    : "Monthly Report"}
                </button>

                <button
                  type="button"
                  className="btn btn-outline-success radius-12 px-16"
                  onClick={() => handleGenerateReport("year")}
                  disabled={printing}
                >
                  {printing && printingRange === "year"
                    ? "Creating..."
                    : "Yearly Report"}
                </button>
              </div>
            </div>
          </div>
        )}

        <div className="card armada-card">
          {/* ✅ HEADER — Desktop tetap, Mobile dirapikan via CSS */}
          <div className="card-header d-flex flex-wrap align-items-center justify-content-between gap-3">
            {/* ✅ Show + Search (mobile jadi 1 baris via CSS) */}
            <div className="cvant-filter-wrap d-flex flex-wrap align-items-center gap-3">
              <div className="cvant-show-wrap d-flex align-items-center gap-2">
                <span className="cvant-show-label">Show</span>
                <select
                  className="form-select form-select-sm w-auto"
                  value={String(limit)}
                  onChange={(e) => {
                    const v = e.target.value;
                    setLimit(v === "all" ? "all" : Number(v));
                  }}
                >
                  <option value={10}>10</option>
                  <option value={20}>20</option>
                  <option value={50}>50</option>
                  <option value={100}>100</option>
                  <option value={200}>200</option>
                  <option value={500}>500</option>
                  <option value={1000}>1000</option>
                  <option value="all">All</option>
                </select>
              </div>

              <div className="search-input style-two cvant-search-wrap">
                <input
                  value={q}
                  onChange={(e) => setQ(e.target.value)}
                  type="text"
                  placeholder="Search income or expense..."
                  style={{
                    backgroundColor: searchBg,
                    color: searchText,
                    borderColor: searchBorder,
                  }}
                />
                <span className="icon" style={{ color: searchIcon }}>
                  <Icon icon="ion:search-outline" />
                </span>
              </div>
            </div>

            {/* ✅ Action buttons — Mobile jadi center, icon disembunyikan via CSS */}
            <div className="cvant-action-wrap d-flex align-items-center gap-2">
              {userRole === "owner" && (
                <button
                  className="btn btn-sm btn-outline-success d-inline-flex align-items-center gap-1 cvant-mobile-btn"
                  onClick={() => setShowPrintModal(true)}
                >
                  <span className="cvant-btn-icon">
                    <Icon icon="mdi:printer" />
                  </span>
                  Report PDF
                </button>
              )}

              <Link
                href="/invoice-add"
                className="btn btn-sm btn-outline-primary d-inline-flex align-items-center gap-1 cvant-mobile-btn"
              >
                <span className="cvant-btn-icon">
                  <Icon icon="material-symbols:add-rounded" />
                </span>
                Add Income
              </Link>

              <Link
                href="/invoice-expense"
                className="btn btn-sm btn-outline-warning d-inline-flex align-items-center gap-1 cvant-mobile-btn"
              >
                <span className="cvant-btn-icon">
                  <Icon icon="mdi:cash-minus" />
                </span>
                Add Expense
              </Link>
            </div>
          </div>

          {/* ✅ BODY */}
          <div className="card-body p-0">
            {loading ? (
              <div className="p-4">Loading…</div>
            ) : (
              <>
                {/* ✅ MOBILE CARD LIST (TATANAN TETAP) */}
                <div className="d-md-none p-3 d-flex flex-column gap-12">
                  {filtered.length === 0 ? (
                    <div className="text-center py-4" style={{ color: textSub }}>
                      Tidak ada data
                    </div>
                  ) : (
                    filtered.map((item) => (
                      <div
                        key={`${item.type}-${item.id}`}
                        className="p-16 radius-12"
                        style={{
                          border: `1px solid ${cardBorder}`,
                          backgroundColor: cardBg,
                        }}
                      >
                        <div className="d-flex justify-content-between align-items-start gap-2">
                          <div>
                            <div
                              style={{
                                fontWeight: 800,
                                fontSize: "14px",
                                color:
                                  item.type === "Income"
                                    ? "#2563eb"
                                    : "#dc3545",
                              }}
                            >
                              {item.no}
                            </div>

                            <div style={{ fontSize: "13px", color: textSub }}>
                              {item.type} • {item.tanggal_display}
                            </div>
                          </div>

                          <span
                            className={`badge px-3 py-2 ${
                              item.status === "Paid"
                                ? "bg-success"
                                : item.status === "Unpaid"
                                ? "bg-warning text-dark"
                                : "bg-secondary"
                            }`}
                            style={{ fontSize: "12px", whiteSpace: "nowrap" }}
                          >
                            {item.status}
                          </span>
                        </div>

                        {/* ✅ NAMA + DICATAT OLEH */}
                        <div className="mt-10">
                          <div style={{ fontSize: "13px", color: textSub }}>
                            Nama:{" "}
                            <span style={{ fontWeight: 600, color: textMain }}>
                              {item.type === "Income" ? item.nama || "-" : "-"}
                            </span>
                          </div>

                          <div style={{ fontSize: "13px", color: textSub }}>
                            Dicatat oleh:{" "}
                            <span style={{ fontWeight: 600, color: textMain }}>
                              {item.recorded_by || "-"}
                            </span>
                          </div>

                          <div
                            className="mt-10"
                            style={{
                              fontWeight: 800,
                              fontSize: "14px",
                              color: textMain,
                            }}
                          >
                            {formatRupiah(item.total)}
                          </div>
                        </div>

                        {/* ✅ ACTION BUTTONS */}
                        <div className="d-flex justify-content-end gap-2 mt-12">
                          {item.type === "Income" ? (
                            <>
                              <button
                                className="btn btn-sm btn-outline-primary"
                                style={mobileActionBtnStyle}
                                onClick={() =>
                                  (window.location.href = `/invoice-edit?id=${item.id}`)
                                }
                              >
                                <Icon icon="mdi:pencil" width={18} height={18} />
                              </button>

                              <button
                                className="btn btn-sm btn-outline-warning"
                                style={mobileActionBtnStyle}
                                onClick={() =>
                                  (window.location.href = `/invoice-preview?id=${item.id}`)
                                }
                              >
                                <Icon icon="mdi:eye" width={18} height={18} />
                              </button>

                              <button
                                className="btn btn-sm btn-outline-info"
                                style={mobileActionBtnStyle}
                                onClick={() => handleSendInvoice(item)}
                              >
                                <Icon icon="mdi:send" width={18} height={18} />
                              </button>
                            </>
                          ) : (
                            <>
                              <button
                                className="btn btn-sm btn-outline-primary"
                                style={mobileActionBtnStyle}
                                onClick={() =>
                                  (window.location.href = `/invoice-expense-edit?id=${item.id}`)
                                }
                              >
                                <Icon icon="mdi:pencil" width={18} height={18} />
                              </button>

                              <button
                                className="btn btn-sm btn-outline-warning"
                                style={mobileActionBtnStyle}
                                onClick={() =>
                                  (window.location.href = `/expense-preview?id=${item.id}`)
                                }
                              >
                                <Icon icon="mdi:eye" width={18} height={18} />
                              </button>
                            </>
                          )}
                        </div>
                      </div>
                    ))
                  )}
                </div>

                {/* ✅ DESKTOP TABLE (TIDAK DIUBAH SAMA SEKALI) */}
                <div className="d-none d-md-block card-body table-responsive d-flex">
                  <table className="table bordered-table text-center align-middle">
                    <thead className="table-dark">
                      <tr>
                        <th>No</th>
                        <th>Nomor</th>
                        <th>Type</th>
                        <th>Nama</th>
                        <th>Total</th>
                        <th>Tanggal</th>
                        <th>Status</th>
                        <th>Aksi</th>
                      </tr>
                    </thead>

                    <tbody>
                      {filtered.length === 0 ? (
                        <tr>
                          <td colSpan={9} className="p-4">
                            Tidak ada data
                          </td>
                        </tr>
                      ) : (
                        filtered.map((item, i) => (
                          <tr key={`${item.type}-${item.id}`}>
                            <td>{i + 1}</td>

                            <td
                              style={{
                                color:
                                  item.type === "Income"
                                    ? "#0d6efd"
                                    : "#dc3545",
                              }}
                            >
                              {item.no}
                            </td>

                            <td>
                              <span
                                className={`badge ${
                                  item.type === "Income"
                                    ? "bg-primary"
                                    : "bg-danger text-light"
                                }`}
                              >
                                {item.type}
                              </span>
                            </td>

                            <td>{item.nama}</td>
                            <td>{formatRupiah(item.total)}</td>
                            <td>{item.tanggal_display}</td>

                            <td>
                              <span
                                className={`badge px-3 py-2 ${
                                  item.status === "Paid"
                                    ? "bg-success"
                                    : item.status === "Unpaid"
                                    ? "bg-warning text-dark"
                                    : "bg-secondary"
                                }`}
                              >
                                {item.status}
                              </span>
                            </td>

                            <td className="d-flex justify-content-center gap-2">
                              {item.type === "Income" ? (
                                <>
                                  <button
                                    className="btn btn-xs btn-outline-primary"
                                    style={{
                                      width: 50,
                                      height: 40,
                                      display: "inline-flex",
                                      alignItems: "center",
                                      justifyContent: "center",
                                    }}
                                    onClick={() =>
                                      (window.location.href = `/invoice-edit?id=${item.id}`)
                                    }
                                  >
                                    <Icon icon="mdi:pencil" />
                                  </button>

                                  <button
                                    className="btn btn-xs btn-outline-warning"
                                    style={{
                                      width: 50,
                                      height: 40,
                                      display: "inline-flex",
                                      alignItems: "center",
                                      justifyContent: "center",
                                    }}
                                    onClick={() =>
                                      (window.location.href = `/invoice-preview?id=${item.id}`)
                                    }
                                  >
                                    <Icon icon="mdi:eye" />
                                  </button>

                                  <button
                                    className="btn btn-xs btn-outline-info"
                                    style={{
                                      width: 50,
                                      height: 40,
                                      display: "inline-flex",
                                      alignItems: "center",
                                      justifyContent: "center",
                                    }}
                                    onClick={() => handleSendInvoice(item)}
                                  >
                                    <Icon icon="mdi:send" />
                                  </button>
                                </>
                              ) : (
                                <>
                                  <button
                                    className="btn btn-xs btn-outline-primary"
                                    style={{
                                      width: 50,
                                      height: 40,
                                      display: "inline-flex",
                                      alignItems: "center",
                                      justifyContent: "center",
                                    }}
                                    onClick={() =>
                                      (window.location.href = `/invoice-expense-edit?id=${item.id}`)
                                    }
                                  >
                                    <Icon icon="mdi:pencil" />
                                  </button>

                                  <button
                                    className="btn btn-xs btn-outline-warning"
                                    style={{
                                      width: 50,
                                      height: 40,
                                      display: "inline-flex",
                                      alignItems: "center",
                                      justifyContent: "center",
                                    }}
                                    onClick={() =>
                                      (window.location.href = `/expense-preview?id=${item.id}`)
                                    }
                                  >
                                    <Icon icon="mdi:eye" />
                                  </button>
                                </>
                              )}

                              <button
                                className="btn btn-xs btn-outline-danger"
                                style={{
                                  width: 50,
                                  height: 40,
                                  display: "inline-flex",
                                  alignItems: "center",
                                  justifyContent: "center",
                                }}
                                onClick={() => openDeleteConfirm(item)}
                              >
                                <Icon icon="mdi:trash-can-outline" />
                              </button>
                            </td>
                          </tr>
                        ))
                      )}
                    </tbody>
                  </table>
                </div>
              </>
            )}
          </div>
        </div>

        {/* ✅ MOBILE ONLY CSS FIX (DESKTOP TIDAK TERKENA) */}
        <style jsx global>{`
          @media (min-width: 768px) {
            .cvant-action-wrap .cvant-btn-icon {
              display: inline-flex !important;
              align-items: center !important;
              justify-content: center !important;
              line-height: 1 !important;
            }

            .cvant-action-wrap .cvant-btn-icon svg,
            .cvant-action-wrap .cvant-btn-icon span {
              display: block !important;
            }
          }

          @media (max-width: 767px) {
            /* ✅ action buttons center + lebih kecil */
            .cvant-action-wrap {
              width: 100%;
              justify-content: center !important;
              flex-wrap: nowrap !important;
              gap: 10px !important;
            }

            .cvant-mobile-btn {
              display: inline-flex !important;
              align-items: center !important;
              justify-content: center !important;
              font-size: 12px !important;
              padding: 8px 12px !important;
              line-height: 1 !important;
              white-space: nowrap !important;
            }

            /* ✅ HILANGKAN ICON BUTTON (mobile only) */
            .cvant-mobile-btn .cvant-btn-icon {
              display: none !important;
            }

            /* ✅ Filter wrap = show + search jadi sejajar */
            .cvant-filter-wrap {
              width: 100%;
              display: flex !important;
              flex-wrap: nowrap !important;
              align-items: center !important;
              gap: 10px !important;
              justify-content: space-between !important;
            }

            /* ✅ Show wrap kecil */
            .cvant-show-wrap {
              flex: 0 0 auto !important;
              white-space: nowrap !important;
            }

            .cvant-show-label {
              display: none !important;
            }

            .cvant-show-wrap select {
              width: 70px !important;
              padding-left: 8px !important;
              padding-right: 8px !important;
            }

            /* ✅ Search flex */
            .cvant-search-wrap {
              flex: 1 1 auto !important;
              min-width: 0 !important;
            }

            .cvant-search-wrap input {
              width: 100% !important;
              font-size: 12px !important;
              padding-left: 12px !important;
              padding-right: 32px !important;
            }

            .cvant-search-wrap .icon {
              right: 10px !important;
            }
          }

          @media (max-width: 575px) {
            .cvant-report-actions {
              flex-direction: column !important;
              align-items: stretch !important;
            }

            .cvant-report-actions .btn {
              width: 100% !important;
            }
          }
        `}</style>
      </div>
    </>
  );
}
