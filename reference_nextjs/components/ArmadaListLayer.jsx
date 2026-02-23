"use client";

import { Icon } from "@iconify/react/dist/iconify.js";
import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { api } from "@/lib/api";

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

export default function ArmadaListLayer() {
  const pageIn = useCvAntPageIn();

  const [rows, setRows] = useState([]);
  const [invoices, setInvoices] = useState([]);
  const [q, setQ] = useState("");
  const [limit, setLimit] = useState(10);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");

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
    id: null,
    label: "",
    deleting: false,
  });

  const openDeleteConfirm = (row) => {
    setDeleteConfirm({
      show: true,
      id: row?.id ?? null,
      label: row
        ? `${row.nama_truk || ""} – ${row.plat_nomor || ""}`.trim()
        : "",
      deleting: false,
    });
  };

  const closeDeleteConfirm = () =>
    setDeleteConfirm({ show: false, id: null, label: "", deleting: false });

  const fetchAll = async () => {
    try {
      const [armData, invData] = await Promise.all([
        api.get("/armadas"),
        api.get("/invoices"),
      ]);

      setRows(Array.isArray(armData) ? armData : []);
      setInvoices(Array.isArray(invData) ? invData : []);
      setErr("");
    } catch (e) {
      const msg = e?.message || "Gagal memuat data armada";
      setErr(msg);
      showPopup("danger", msg, 0);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    let mounted = true;
    setLoading(true);

    const run = async () => {
      if (!mounted) return;
      await fetchAll();
    };

    run();
    const t = setInterval(run, 5000);

    return () => {
      mounted = false;
      clearInterval(t);
    };
  }, []);

  const usageCountById = useMemo(() => {
    const map = new Map();

    (Array.isArray(invoices) ? invoices : []).forEach((inv) => {
      const rincian = Array.isArray(inv?.rincian) ? inv.rincian : [];

      if (rincian.length > 0) {
        rincian.forEach((r) => {
          const id =
            r?.armada_id ??
            r?.armada?.id ??
            inv?.armada_id ??
            inv?.armada?.id ??
            null;

          if (id == null) return;

          const key = String(id);
          map.set(key, (map.get(key) || 0) + 1);
        });
      } else {
        const id = inv?.armada_id ?? inv?.armada?.id ?? null;
        if (id == null) return;

        const key = String(id);
        map.set(key, (map.get(key) || 0) + 1);
      }
    });

    return map;
  }, [invoices]);

  const filtered = useMemo(() => {
    const s = q.trim().toLowerCase();

    let list = (Array.isArray(rows) ? rows : []).map((r) => {
      const usedCount =
        r?.id != null ? usageCountById.get(String(r.id)) || 0 : 0;
      return { ...r, __usedCount: usedCount };
    });

    if (s) {
      list = list.filter(
        (r) =>
          (r.nama_truk || "").toLowerCase().includes(s) ||
          (r.plat_nomor || "").toLowerCase().includes(s) ||
          (String(r.kapasitas || "")).toLowerCase().includes(s) ||
          (r.status || "").toLowerCase().includes(s)
      );
    }

    list.sort((a, b) => {
      const diff = (b.__usedCount || 0) - (a.__usedCount || 0);
      if (diff !== 0) return diff;
      return String(a.nama_truk || "").localeCompare(String(b.nama_truk || ""));
    });

    return list.slice(0, limit);
  }, [rows, q, limit, usageCountById]);

  const handleDeleteConfirmed = async () => {
    const id = deleteConfirm.id;
    if (!id) return;

    setDeleteConfirm((p) => ({ ...p, deleting: true }));
    try {
      await api.delete(`/armadas/${id}`);
      setRows((prev) => prev.filter((x) => x.id !== id));

      closeDeleteConfirm();
      showPopup("success", "Armada berhasil dihapus.", 3000);
    } catch (e) {
      const msg = e?.message || "Gagal menghapus armada";
      setErr(msg);
      setDeleteConfirm((p) => ({ ...p, deleting: false }));
      showPopup("danger", msg, 0);
    }
  };

  const actionBtnStyle = {
    width: 50,
    height: 40,
    display: "inline-flex",
    alignItems: "center",
    justifyContent: "center",
    padding: 0,
    lineHeight: 1,
  };

  const mobileActionBtnStyle = {
    width: 44,
    height: 38,
    padding: 0,
    display: "inline-flex",
    alignItems: "center",
    justifyContent: "center",
    lineHeight: 1,
  };

  const searchBg = isLightMode ? "#f5f6fa" : "#1b2431";
  const searchText = isLightMode ? "#0b1220" : "#ffffff";
  const searchBorder = isLightMode ? "#c7c8ca" : "#6c757d";
  const searchIcon = isLightMode ? "#0b1220" : "#ffffff";

  const cardBg = isLightMode ? "#ffffff" : "#1b2431";
  const cardBorder = isLightMode ? "rgba(148,163,184,0.35)" : "#273142";
  const textMain = isLightMode ? "#0b1220" : "#ffffff";
  const textSub = isLightMode ? "#64748b" : "#94a3b8";

  return (
    <>
      <div className={`cvant-page-in ${pageIn ? "is-in" : ""}`}>
        {/* POPUP */}
        {popup.show && (
          <div
            className="position-fixed top-0 start-0 w-100 h-100 d-flex align-items-center justify-content-center"
            style={{
              zIndex: 9999,
              background: "rgba(0,0,0,0.55)",
              padding: "16px",
            }}
            onClick={closePopup}
          >
            <div
              className="radius-12 shadow-sm p-24"
              style={{
                width: "100%",
                maxWidth: "600px",
                backgroundColor: "#1b2431",
                border: `2px solid ${popupAccent}`,
              }}
              onClick={(e) => e.stopPropagation()}
            >
              <div className="d-flex align-items-start justify-content-between gap-2">
                <div className="d-flex align-items-start gap-12">
                  <span style={{ marginTop: "2px" }}>
                    <Icon
                      icon={
                        popup.type === "success"
                          ? "solar:check-circle-linear"
                          : "solar:danger-triangle-linear"
                      }
                      style={{
                        fontSize: "28px",
                        color: popupAccent,
                      }}
                    />
                  </span>

                  <div>
                    <h5 className="mb-8 fw-bold" style={{ color: "#ffffff" }}>
                      {popup.type === "success" ? "Success" : "Error"}
                    </h5>
                    <p
                      className="mb-0"
                      style={{ color: "#cbd5e1", fontSize: "15px" }}
                    >
                      {popup.message}
                    </p>
                  </div>
                </div>

                <button
                  type="button"
                  className="btn p-0"
                  aria-label="Close"
                  onClick={closePopup}
                  style={{
                    border: "none",
                    background: "transparent",
                    lineHeight: 1,
                  }}
                >
                  <Icon
                    icon="solar:close-circle-linear"
                    style={{ fontSize: 24, color: "#94a3b8" }}
                  />
                </button>
              </div>

              <div className="d-flex justify-content-end mt-20">
                <button
                  type="button"
                  className={`btn btn-${
                    popup.type === "success" ? "primary" : "danger"
                  } radius-12 px-16`}
                  onClick={closePopup}
                  style={{
                    border: `2px solid ${popupAccent}`,
                  }}
                >
                  OK
                </button>
              </div>
            </div>
          </div>
        )}

        {/* DELETE CONFIRM */}
        {deleteConfirm.show && (
          <div
            className="position-fixed top-0 start-0 w-100 h-100 d-flex align-items-center justify-content-center"
            style={{
              zIndex: 9999,
              background: "rgba(0,0,0,0.55)",
              padding: "16px",
            }}
            onClick={() => {
              if (!deleteConfirm.deleting) closeDeleteConfirm();
            }}
          >
            <div
              className="radius-12 shadow-sm p-24"
              style={{
                width: "100%",
                maxWidth: "600px",
                backgroundColor: "#1b2431",
                border: `2px solid #ef4444`,
              }}
              onClick={(e) => e.stopPropagation()}
            >
              <div className="d-flex align-items-start justify-content-between gap-2">
                <div className="d-flex align-items-start gap-12">
                  <span style={{ marginTop: "2px" }}>
                    <Icon
                      icon="solar:danger-triangle-linear"
                      style={{
                        fontSize: "28px",
                        color: "#ef4444",
                      }}
                    />
                  </span>

                  <div>
                    <h5 className="mb-8 fw-bold" style={{ color: "#ffffff" }}>
                      Confirm Delete
                    </h5>
                    <p
                      className="mb-0"
                      style={{ color: "#cbd5e1", fontSize: "15px" }}
                    >
                      Are you sure you want to delete{" "}
                      <span style={{ color: "#ffffff", fontWeight: 700 }}>
                        {deleteConfirm.label || "this"}
                      </span>
                      ?
                    </p>
                  </div>
                </div>

                <button
                  type="button"
                  className="btn p-0"
                  aria-label="Close"
                  onClick={() => {
                    if (!deleteConfirm.deleting) closeDeleteConfirm();
                  }}
                  style={{
                    border: "none",
                    background: "transparent",
                    lineHeight: 1,
                  }}
                  disabled={deleteConfirm.deleting}
                >
                  <Icon
                    icon="solar:close-circle-linear"
                    style={{ fontSize: 24, color: "#94a3b8" }}
                  />
                </button>
              </div>

              <div className="d-flex justify-content-end mt-20 gap-2">
                <button
                  type="button"
                  className="btn btn-outline-secondary radius-12 px-16"
                  onClick={closeDeleteConfirm}
                  disabled={deleteConfirm.deleting}
                  style={{ border: "2px solid #64748b", color: "#e2e8f0" }}
                >
                  Cancel
                </button>

                <button
                  type="button"
                  className="btn btn-danger radius-12 px-16"
                  onClick={handleDeleteConfirmed}
                  disabled={deleteConfirm.deleting}
                  style={{ border: "2px solid #ef4444" }}
                >
                  {deleteConfirm.deleting ? "Deleting..." : "Delete"}
                </button>
              </div>
            </div>
          </div>
        )}

        <div className="card armada-card">
          {/* ✅ HEADER */}
          <div className="card-header d-flex flex-wrap align-items-center justify-content-between gap-3">
            {/* ✅ Show + Search */}
            <div className="cvant-filter-wrap d-flex flex-wrap align-items-center gap-3">
              <div className="cvant-show-wrap d-flex align-items-center gap-2">
                <span className="cvant-show-label">Show</span>
                <select
                  className="form-select form-select-sm w-auto"
                  value={limit}
                  onChange={(e) => setLimit(parseInt(e.target.value || "10", 10))}
                >
                  <option value="10">10</option>
                  <option value="15">15</option>
                  <option value="20">20</option>
                </select>
              </div>

              <div className="search-input style-two cvant-search-wrap">
                <input
                  value={q}
                  onChange={(e) => setQ(e.target.value)}
                  type="text"
                  placeholder="Search fleet..."
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

            <div className="cvant-action-wrap d-flex flex-wrap align-items-center gap-2">
              <Link
                href="/armada-add"
                className="btn btn-sm btn-outline-primary-600 d-inline-flex align-items-center gap-1 cvant-mobile-btn"
              >
                <span className="cvant-btn-icon">
                  <Icon icon="material-symbols:add-rounded" className="text-xl" />
                </span>
                Add New
              </Link>
            </div>
          </div>

          <div className="card-body p-0">
            {loading ? (
              <div className="p-4">Loading...</div>
            ) : (
              <>
                {/* ✅ MOBILE CARD VIEW */}
                <div className="d-md-none p-3 d-flex flex-column gap-12">
                  {filtered.length === 0 ? (
                    <div className="text-center py-4" style={{ color: textSub }}>
                      Tidak ada data
                    </div>
                  ) : (
                    filtered.map((r, idx) => (
                      <div
                        key={r.id ?? idx}
                        className="p-16 radius-12"
                        style={{
                          backgroundColor: cardBg,
                          border: `1px solid ${cardBorder}`,
                        }}
                      >
                        <div className="d-flex justify-content-between align-items-start gap-2">
                          <div>
                            <div
                              style={{
                                fontWeight: 800,
                                fontSize: "14px",
                                color: textMain,
                              }}
                            >
                              {r.nama_truk || "-"}
                            </div>

                            <div style={{ fontSize: "13px", color: textSub }}>
                              Plat:{" "}
                              <span style={{ fontWeight: 700, color: textMain }}>
                                {r.plat_nomor || "-"}
                              </span>
                            </div>
                          </div>

                          <span
                            className={`badge ${
                              r.status === "Ready"
                                ? "bg-success"
                                : "bg-warning text-dark"
                            }`}
                            style={{ fontSize: "12px", whiteSpace: "nowrap" }}
                          >
                            {r.status || "-"}
                          </span>
                        </div>

                        <div className="mt-10">
                          <div style={{ fontSize: "13px", color: textSub }}>
                            Kapasitas:{" "}
                            <span style={{ fontWeight: 700, color: textMain }}>
                              {r.kapasitas || 0}
                            </span>
                          </div>

                          <div style={{ fontSize: "13px", color: textSub }}>
                            Penggunaan:{" "}
                            <span style={{ fontWeight: 700, color: textMain }}>
                              {(r.__usedCount || 0) + "x"}
                            </span>
                          </div>
                        </div>

                        <div className="d-flex justify-content-end gap-2 mt-12">
                          <Link
                            href={`/armada-edit/${r.id}`}
                            className="btn btn-sm btn-outline-primary"
                            style={mobileActionBtnStyle}
                            title="Edit"
                            aria-label="Edit"
                          >
                            <Icon icon="mdi:pencil" width={18} height={18} />
                          </Link>

                          <button
                            onClick={() => openDeleteConfirm(r)}
                            className="btn btn-sm btn-outline-danger"
                            style={mobileActionBtnStyle}
                            title="Delete"
                            aria-label="Delete"
                          >
                            <Icon
                              icon="mdi:trash-can-outline"
                              width={18}
                              height={18}
                            />
                          </button>
                        </div>
                      </div>
                    ))
                  )}
                </div>

                {/* ✅ DESKTOP TABLE VIEW (TIDAK DIUBAH) */}
                <div className="d-none d-md-block card-body table-responsive d-flex">
                  <table className="table bordered-table text-center align-middle armada-table">
                    <thead className="table-dark">
                      <tr>
                        <th>No</th>
                        <th>Nama Truk</th>
                        <th>Plat Nomor</th>
                        <th>Kapasitas (Tonase)</th>
                        <th>Status</th>
                        <th>Penggunaan</th>
                        <th>Aksi</th>
                      </tr>
                    </thead>

                    <tbody>
                      {filtered.length === 0 ? (
                        <tr>
                          <td colSpan={7} className="text-center">
                            Tidak ada data
                          </td>
                        </tr>
                      ) : (
                        filtered.map((r, idx) => (
                          <tr key={r.id ?? idx}>
                            <td>{idx + 1}</td>
                            <td>{r.nama_truk}</td>
                            <td>{r.plat_nomor}</td>
                            <td>{r.kapasitas}</td>
                            <td>
                              <span
                                className={`badge ${
                                  r.status === "Ready"
                                    ? "bg-success"
                                    : "bg-warning text-dark"
                                }`}
                              >
                                {r.status}
                              </span>
                            </td>

                            <td>{(r.__usedCount || 0) + "x"}</td>

                            <td className="d-flex justify-content-center gap-3">
                              <Link
                                href={`/armada-edit/${r.id}`}
                                className="btn btn-xs btn-outline-primary"
                                style={actionBtnStyle}
                                title="Edit"
                                aria-label="Edit"
                              >
                                <Icon icon="mdi:pencil" />
                              </Link>

                              <button
                                onClick={() => openDeleteConfirm(r)}
                                className="btn btn-xs btn-outline-danger"
                                style={actionBtnStyle}
                                title="Delete"
                                aria-label="Delete"
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

        {/* ✅ MOBILE ONLY CSS (DESKTOP TIDAK TERKENA) */}
        <style jsx global>{`
          @media (max-width: 767px) {
            .armada-card .card-header {
              flex-wrap: nowrap !important;
              gap: 8px !important;
            }

            .cvant-filter-wrap {
              flex: 1 1 auto !important;
              width: auto !important;
              min-width: 0 !important;
              display: flex !important;
              flex-wrap: nowrap !important;
              gap: 8px !important;
              align-items: center !important;
              justify-content: flex-start !important;
            }

            .cvant-show-wrap {
              flex: 0 0 auto !important;
              white-space: nowrap !important;
            }

            .cvant-show-label {
              display: none !important;
            }

            .cvant-show-wrap select {
              width: 60px !important;
              padding-left: 8px !important;
              padding-right: 8px !important;
            }

            .cvant-search-wrap {
              flex: 1 1 120px !important;
              max-width: 140px !important;
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

            /* ✅ tombol add new di bawah search, nempel kanan */
            .cvant-action-wrap {
              flex: 0 0 auto !important;
              width: auto !important;
              display: flex !important;
              justify-content: center !important;
              flex-wrap: nowrap !important;
              margin-top: 0 !important;
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

            .cvant-mobile-btn .cvant-btn-icon {
              display: none !important;
            }

            .cvant-action-wrap a {
              white-space: nowrap !important;
            }
          }
        `}</style>
      </div>
    </>
  );
}
