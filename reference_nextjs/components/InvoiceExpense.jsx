"use client";

import { useEffect, useMemo, useState } from "react";
import { api } from "@/lib/api";
import { Icon } from "@iconify/react/dist/iconify.js";

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

export default function InvoiceExpensePage() {
  const pageIn = useCvAntPageIn();

  const [saving, setSaving] = useState(false);
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

  const controlBg = isLightMode ? "#ffffff" : "#273142";
  const controlText = isLightMode ? "#0b1220" : "#ffffff";
  const controlBorder = isLightMode ? "#c7c8ca" : "#6c757d";

  const [form, setForm] = useState({
    no_expense: "",
    tanggal: "",
    total_pengeluaran: 0,
    status: "Approved",
    dicatat_oleh: "Admin",
    rincian: [{ nama: "", jumlah: "" }],
  });

  useEffect(() => {
    const generateExpenseNumber = async () => {
      try {
        const expenses = await api.get("/expenses");
        const list = Array.isArray(expenses) ? expenses : [];
        const nextNumber = (list.length + 1).toString().padStart(4, "0");
        const now = new Date();
        const month = String(now.getMonth() + 1).padStart(2, "0");
        const newNumber = `EXP-${month}-${now.getFullYear()}-${nextNumber}`;
        setForm((prev) => ({ ...prev, no_expense: newNumber }));
      } catch {
        const now = new Date();
        const month = String(now.getMonth() + 1).padStart(2, "0");
        const fallbackNumber = `EXP-${month}-${now.getFullYear()}-0001`;
        setForm((prev) => ({ ...prev, no_expense: fallbackNumber }));
      }
    };
    generateExpenseNumber();
  }, []);

  const totalExpense = useMemo(
    () =>
      (form.rincian || []).reduce(
        (sum, r) => sum + (parseFloat(r.jumlah) || 0),
        0
      ),
    [form.rincian]
  );

  useEffect(() => {
    setForm((prev) => ({ ...prev, total_pengeluaran: totalExpense }));
  }, [totalExpense]);

  const onChange = (key) => (e) =>
    setForm((prev) => ({ ...prev, [key]: e.target.value }));

  const updateRincian = (index, key, value) => {
    const updated = [...(form.rincian || [])];
    updated[index] = { ...updated[index], [key]: value };
    setForm((prev) => ({ ...prev, rincian: updated }));
  };

  const addRincian = () => {
    setForm((prev) => ({
      ...prev,
      rincian: [...(prev.rincian || []), { nama: "", jumlah: "" }],
    }));
  };

  const removeRincian = (index) => {
    setForm((prev) => ({
      ...prev,
      rincian: (prev.rincian || []).filter((_, i) => i !== index),
    }));
  };

  const validate = () => {
    const msgGeneral = "Data is still incomplete, please complete it first!";

    if (
      !String(form.no_expense || "").trim() ||
      !String(form.tanggal || "").trim()
    ) {
      setErr("");
      showPopup("danger", msgGeneral, 0);
      return false;
    }

    if (!Array.isArray(form.rincian) || form.rincian.length === 0) {
      setErr("");
      showPopup("danger", msgGeneral, 0);
      return false;
    }

    for (let i = 0; i < form.rincian.length; i++) {
      const r = form.rincian[i] || {};
      const namaOk = String(r.nama || "").trim();
      const jumlahOk = parseFloat(r.jumlah) > 0;

      if (!namaOk || !jumlahOk) {
        setErr("");
        showPopup("danger", msgGeneral, 0);
        return false;
      }
    }

    return true;
  };

  const handleSave = async () => {
    if (!validate()) return;

    setErr("");
    setSaving(true);

    try {
      const payload = {
        no_expense: form.no_expense,
        tanggal: form.tanggal,
        total_pengeluaran: totalExpense,
        status: form.status,
        dicatat_oleh: form.dicatat_oleh,
        rincian: (form.rincian || []).map((r) => ({
          nama: (r.nama || "").trim(),
          jumlah: parseFloat(r.jumlah) || 0,
        })),
      };

      const saved = await api.post("/expenses", payload);

      if (saved?.id) {
        showPopup(
          "success",
          "Expense saved successfully! Redirecting to Invoice List Page...",
          3000
        );
        setTimeout(() => {
          window.location.href = "/invoice-list";
        }, 3000);
      } else {
        setErr("");
        showPopup("danger", "Expense saved, but the ID was not found.", 0);
      }
    } catch (e) {
      const msg = e?.message || "Failed to save expense.";
      setErr(msg);
      showPopup("danger", msg, 0);
    } finally {
      setSaving(false);
    }
  };

  const formatRupiah = (num) =>
    new Intl.NumberFormat("id-ID", {
      style: "currency",
      currency: "IDR",
      minimumFractionDigits: 0,
    }).format(num);

  return (
    <>
      <div className={`cvant-page-in ${pageIn ? "is-in" : ""}`}>
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

        {/* ✅ FORM */}
        <div className="container-fluid py-4">
          <div className="row g-4">
            <div className="col-lg-12">
              <div className="card shadow-sm border-0">
                <div className="card-header bg-transparent d-flex justify-content-end gap-3">
                  <button
                    disabled={saving}
                    onClick={handleSave}
                    className="btn btn-sm btn-primary"
                  >
                    {saving ? "Saving..." : "Save"}
                  </button>
                </div>

                <div className="card-body">
                  {err && <div className="alert alert-danger">{err}</div>}

                  {/* ... isi form expense kamu tetap ... */}
                  <div className="row g-3">
                    <div className="col-md-6">
                      <label className="form-label fw-semibold">
                        Nomor Expense
                      </label>
                      <input
                        className="form-control"
                        value={form.no_expense}
                        readOnly
                      />
                    </div>

                    <div className="col-md-6">
                      <label className="form-label fw-semibold">Tanggal</label>
                      <input
                        type="date"
                        className="form-control"
                        value={form.tanggal}
                        onChange={onChange("tanggal")}
                      />
                    </div>

                    <div className="col-12">
                      <hr className="my-2" />
                    </div>

                    <div className="col-12">
                      <label className="form-label fw-semibold">
                        Rincian Pengeluaran
                      </label>

                      {(form.rincian || []).map((r, i) => (
                        <div
                          key={i}
                          className={`row g-2 align-items-center mb-2 ${
                            i > 0 ? "mt-3" : ""
                          }`}
                        >
                          <div className="col-md-6">
                            <input
                              className="form-control"
                              placeholder="Nama Pengeluaran"
                              value={r.nama}
                              onChange={(e) =>
                                updateRincian(i, "nama", e.target.value)
                              }
                            />
                          </div>

                          <div className="col-md-4">
                            <input
                              type="number"
                              className="form-control"
                              placeholder="Jumlah"
                              value={r.jumlah}
                              onChange={(e) =>
                                updateRincian(i, "jumlah", e.target.value)
                              }
                            />
                          </div>

                          <div className="col-md-2 text-end">
                            {form.rincian.length > 1 && (
                              <button
                                className="btn btn-sm btn-outline-danger"
                                type="button"
                                onClick={() => removeRincian(i)}
                              >
                                Hapus
                              </button>
                            )}
                          </div>
                        </div>
                      ))}

                      <button
                        className="btn btn-sm btn-outline-primary mt-3"
                        type="button"
                        onClick={addRincian}
                      >
                        + Tambah Rincian
                      </button>
                    </div>

                    <div className="col-md-6 mt-4">
                      <label className="form-label fw-semibold">
                        Total Pengeluaran
                      </label>
                      <input
                        className="form-control fw-bold"
                        value={formatRupiah(totalExpense)}
                        readOnly
                        style={{
                          backgroundColor: "#f8f9fa",
                          color: "black",
                          WebkitTextFillColor: "black",
                        }}
                      />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* ✅ FIX BREADCRUMB + DASHBOARD TEXT (EXTRA SMALL MOBILE) */}
        <style jsx global>{`
          @media (max-width: 576px) {
            /* breadcrumb jadi super kecil */
            .breadcrumb,
            .breadcrumb * {
              font-size: 9.5px !important;
              line-height: 1.1 !important;
              white-space: nowrap !important;
              overflow: hidden !important;
              text-overflow: ellipsis !important;
              max-width: 100% !important;
            }

            /* biasanya text dashboard / title */
            h5,
            h6,
            .text-lg,
            .page-title,
            .page-title * {
              font-size: 11px !important;
              line-height: 1.1 !important;
              white-space: nowrap !important;
              overflow: hidden !important;
              text-overflow: ellipsis !important;
            }

            /* paksa flex 1 baris */
            .d-flex.align-items-center.flex-wrap {
              flex-wrap: nowrap !important;
              gap: 6px !important;
            }

            /* kurangi padding & spacing */
            .breadcrumb {
              margin-bottom: 0 !important;
              padding: 0 !important;
            }
          }
        `}</style>
      </div>
    </>
  );
}
