"use client";

import { useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
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

export default function InvoiceAddPage() {
  const pageIn = useCvAntPageIn();
  const searchParams = useSearchParams();

  const [armadas, setArmadas] = useState([]);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState("");
  const [prefillArmadaName, setPrefillArmadaName] = useState("");

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

  // ✅ STATE BARU UNTUK CONFIRM ARMADA FULL
  const [waitConfirm, setWaitConfirm] = useState({
    show: false,
    armadaLabel: "",
  });

  // ✅ payload sementara kalau user klik YES baru disave
  const [pendingSave, setPendingSave] = useState(null);

  const closeWaitConfirm = () =>
    setWaitConfirm({ show: false, armadaLabel: "" });

  const [form, setForm] = useState({
    order_id: "",
    no_invoice: "",
    tanggal: "",
    due_date: "",
    nama_pelanggan: "",
    email: "",
    no_telp: "",

    armada_id: "",
    armada_start_date: "",
    armada_end_date: "",
    lokasi_muat: "",
    lokasi_bongkar: "",
    tonase: "",
    harga: "",

    total_biaya: 0,
    pph: 0,
    total_bayar: 0,
    status: "Unpaid",
    diterima_oleh: "Admin",

    rincian: [
      {
        lokasi_muat: "",
        lokasi_bongkar: "",
        armada_id: "",
        armada_start_date: "",
        armada_end_date: "",
        tonase: "",
        harga: "",
      },
    ],
  });

  useEffect(() => {
    api
      .get("/armadas")
      .then((res) => setArmadas(Array.isArray(res) ? res : []))
      .catch(() => setArmadas([]));
  }, []);

  const generateFallbackInvoiceNumber = () => {
    const nextNumber = "0001";
    const now = new Date();
    const month = String(now.getMonth() + 1).padStart(2, "0");
    return `INC-${month}-${now.getFullYear()}-${nextNumber}`;
  };

  useEffect(() => {
    api
      .get("/invoices")
      .then((invoices) => {
        const list = Array.isArray(invoices) ? invoices : [];
        const next = list.length + 1;
        const nextNumber = next.toString().padStart(4, "0");
        const now = new Date();
        const month = String(now.getMonth() + 1).padStart(2, "0");
        setForm((prev) => ({
          ...prev,
          no_invoice: `INC-${month}-${now.getFullYear()}-${nextNumber}`,
        }));
      })
      .catch(() => {
        setForm((prev) => ({
          ...prev,
          no_invoice: generateFallbackInvoiceNumber(),
        }));
      });
  }, []);

  const toInputDate = (raw) => {
    if (!raw) return "";
    const str = String(raw).trim();

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

  useEffect(() => {
    if (!searchParams) return;
    const orderId = searchParams.get("orderId") || "";
    const customerName = searchParams.get("customerName") || "";
    const customerEmail = searchParams.get("customerEmail") || "";
    const customerPhone = searchParams.get("customerPhone") || "";
    const pickup = searchParams.get("pickup") || "";
    const destination = searchParams.get("destination") || "";
    const pickupDate = searchParams.get("pickupDate") || "";
    const armadaName = searchParams.get("armadaName") || "";

    if (
      !orderId &&
      !customerName &&
      !customerEmail &&
      !customerPhone &&
      !pickup &&
      !destination &&
      !pickupDate &&
      !armadaName
    ) {
      return;
    }

    setForm((prev) => {
      const next = { ...prev };
      if (orderId && !String(prev.order_id || "").trim()) {
        next.order_id = orderId;
      }
      if (customerName && !String(prev.nama_pelanggan || "").trim()) {
        next.nama_pelanggan = customerName;
      }
      if (customerEmail && !String(prev.email || "").trim()) {
        next.email = customerEmail;
      }
      if (customerPhone && !String(prev.no_telp || "").trim()) {
        next.no_telp = customerPhone;
      }

      const rincian = Array.isArray(prev.rincian) ? [...prev.rincian] : [];
      if (rincian.length === 0) {
        rincian.push({
          lokasi_muat: "",
          lokasi_bongkar: "",
          armada_id: "",
          armada_start_date: "",
          armada_end_date: "",
          tonase: "",
          harga: "",
        });
      }

      const first = { ...rincian[0] };
      if (pickup && !String(first.lokasi_muat || "").trim()) {
        first.lokasi_muat = pickup;
      }
      if (destination && !String(first.lokasi_bongkar || "").trim()) {
        first.lokasi_bongkar = destination;
      }
      if (pickupDate && !String(first.armada_start_date || "").trim()) {
        first.armada_start_date = toInputDate(pickupDate);
      }
      rincian[0] = first;
      next.rincian = rincian;
      return next;
    });

    if (armadaName) {
      setPrefillArmadaName(armadaName);
    }
  }, [searchParams]);

  useEffect(() => {
    if (!prefillArmadaName || armadas.length === 0) return;

    const normalize = (value) =>
      String(value || "")
        .toLowerCase()
        .replace(/\s+/g, " ")
        .trim();

    const target = normalize(prefillArmadaName);
    if (!target) return;

    const matched = armadas.find((armada) => {
      const name = normalize(armada?.nama_truk);
      if (!name) return false;
      return name === target || name.includes(target) || target.includes(name);
    });

    if (!matched?.id) return;

    setForm((prev) => {
      const rincian = Array.isArray(prev.rincian) ? [...prev.rincian] : [];
      if (rincian.length === 0) return prev;
      if (String(rincian[0]?.armada_id || "").trim()) return prev;

      const first = { ...rincian[0], armada_id: String(matched.id) };
      rincian[0] = first;
      return { ...prev, rincian };
    });
  }, [prefillArmadaName, armadas]);

  const updateRincian = (index, key, value) => {
    const updated = [...(form.rincian || [])];
    updated[index] = { ...updated[index], [key]: value };
    setForm((prev) => ({ ...prev, rincian: updated }));
  };

  const addRincian = () => {
    setForm((prev) => ({
      ...prev,
      rincian: [
        ...(prev.rincian || []),
        {
          lokasi_muat: "",
          lokasi_bongkar: "",
          armada_id: "",
          armada_start_date: "",
          armada_end_date: "",
          tonase: "",
          harga: "",
        },
      ],
    }));
  };

  const removeRincian = (index) => {
    setForm((prev) => ({
      ...prev,
      rincian: (prev.rincian || []).filter((_, i) => i !== index),
    }));
  };

  const calcRowSubtotal = (row) => {
    const t = parseFloat(row?.tonase) || 0;
    const h = parseFloat(row?.harga) || 0;
    return t * h;
  };

  const subtotal = useMemo(() => {
    return (form.rincian || []).reduce((sum, r) => sum + calcRowSubtotal(r), 0);
  }, [form.rincian]);

  const pph = useMemo(() => subtotal * 0.02, [subtotal]);
  const totalBayar = useMemo(() => subtotal - pph, [subtotal, pph]);

  useEffect(() => {
    setForm((prev) => ({
      ...prev,
      total_biaya: subtotal,
      pph,
      total_bayar: totalBayar,
    }));
  }, [subtotal, pph, totalBayar]);

  const onChange = (key) => (e) =>
    setForm((prev) => ({ ...prev, [key]: e.target.value }));

  // ✅ VALIDASI POPUP UMUM
  const validate = () => {
    const msgGeneral = "Data is still incomplete, please complete it first!";

    const requiredTop = ["no_invoice", "nama_pelanggan", "tanggal", "status"];
    for (const key of requiredTop) {
      if (!String(form[key] || "").trim()) {
        setErr("");
        showPopup("danger", msgGeneral, 0);
        return false;
      }
    }

    if (!Array.isArray(form.rincian) || form.rincian.length === 0) {
      setErr("");
      showPopup("danger", msgGeneral, 0);
      return false;
    }

    for (let i = 0; i < form.rincian.length; i++) {
      const r = form.rincian[i] || {};
      if (
        !String(r.lokasi_muat || "").trim() ||
        !String(r.lokasi_bongkar || "").trim() ||
        !String(r.armada_id || "").trim() ||
        !String(r.armada_start_date || "").trim() ||
        !String(r.armada_end_date || "").trim() ||
        !String(r.tonase || "").trim() ||
        !String(r.harga || "").trim()
      ) {
        setErr("");
        showPopup("danger", msgGeneral, 0);
        return false;
      }
    }

    return true;
  };

  // ✅ fungsi final untuk save payload
  const doSavePayload = async (payload) => {
    setErr("");
    setSaving(true);

    try {
      const saved = await api.post("/invoices", payload);

      if (saved?.id) {
        showPopup(
          "success",
          "Invoice saved successfully! Redirecting to the invoice list...",
          3000
        );
        setTimeout(() => {
          window.location.href = "/invoice-list";
        }, 3000);
      } else {
        showPopup("danger", "Invoice saved, but the ID was not found.", 0);
      }
    } catch (e) {
      showPopup("danger", e?.message || "Failed to save invoice.", 0);
    } finally {
      setSaving(false);
      setPendingSave(null);
      closeWaitConfirm();
    }
  };

  const handleSave = async () => {
    if (!form.no_invoice) {
      setForm((prev) => ({
        ...prev,
        no_invoice: generateFallbackInvoiceNumber(),
      }));
    }

    if (!validate()) return;

    const rincianClean = (form.rincian || []).map((r) => ({
      lokasi_muat: (r.lokasi_muat || "").trim(),
      lokasi_bongkar: (r.lokasi_bongkar || "").trim(),
      armada_id: r.armada_id ? Number(r.armada_id) : null,
      armada_start_date: r.armada_start_date || null,
      armada_end_date: r.armada_end_date || null,
      tonase: parseFloat(r.tonase) || 0,
      harga: parseFloat(r.harga) || 0,
      total: (parseFloat(r.tonase) || 0) * (parseFloat(r.harga) || 0),
    }));

    const first = rincianClean[0];

    const payload = {
      order_id: form.order_id ? Number(form.order_id) : null,
      no_invoice: form.no_invoice,
      nama_pelanggan: form.nama_pelanggan,
      email: form.email,
      no_telp: form.no_telp,
      tanggal: form.tanggal,
      due_date: form.due_date,

      lokasi_muat: first?.lokasi_muat || null,
      lokasi_bongkar: first?.lokasi_bongkar || null,
      armada_id: first?.armada_id || null,
      armada_start_date: first?.armada_start_date || null,
      armada_end_date: first?.armada_end_date || null,
      tonase: first?.tonase || 0,
      harga: first?.harga || 0,

      total_biaya: subtotal,
      pph,
      total_bayar: totalBayar,

      status: form.status,
      diterima_oleh: form.diterima_oleh,

      rincian: rincianClean,
    };

    // ✅ LOGIC CEK ARMADA FULL / ONGOING
    const busy = rincianClean.find((r) => {
      const a = armadas.find((x) => Number(x.id) === Number(r.armada_id));
      if (!a) return false;
      return String(a.status || "").toLowerCase() !== "ready";
    });

    if (busy) {
      const a = armadas.find((x) => Number(x.id) === Number(busy.armada_id));
      const label = a
        ? `${a.nama_truk || ""} – ${a.plat_nomor || ""}`.trim()
        : "this fleet";

      setPendingSave(payload);
      setWaitConfirm({ show: true, armadaLabel: label });
      return;
    }

    // ✅ normal save jika armada ready
    await doSavePayload(payload);
  };

  // ✅ warna popup untuk 3 mode (success, danger, warning)
  const popupAccent =
    popup.type === "success"
      ? "#22c55e"
      : popup.type === "warning"
      ? "#d97706"
      : "#ef4444";

  const controlBg = isLightMode ? "#ffffff" : "#273142";
  const controlText = isLightMode ? "#0b1220" : "#ffffff";
  const controlBorder = isLightMode ? "#c7c8ca" : "#6c757d";
  const optionBg = controlBg;
  const optionText = controlText;

  return (
    <>
      <div className={`cvant-page-in ${pageIn ? "is-in" : ""}`}>
        {/* POPUP UMUM */}
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
                          : popup.type === "warning"
                          ? "solar:danger-triangle-linear"
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
                      {popup.type === "success"
                        ? "Success"
                        : popup.type === "warning"
                        ? "Warning"
                        : "Error"}
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
                    popup.type === "success"
                      ? "primary"
                      : popup.type === "warning"
                      ? "warning"
                      : "danger"
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

        {/* ✅ POPUP CONFIRM ARMADA FULL */}
        {waitConfirm.show && (
          <div
            className="position-fixed top-0 start-0 w-100 h-100 d-flex align-items-center justify-content-center"
            style={{
              zIndex: 9999,
              background: "rgba(0,0,0,0.55)",
              padding: "16px",
            }}
            onClick={() => {
              if (!saving) closeWaitConfirm();
            }}
          >
            <div
              className="radius-12 shadow-sm p-24"
              style={{
                width: "100%",
                maxWidth: "600px",
                backgroundColor: "#1b2431",
                border: `2px solid #d97706`,
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
                        color: "#d97706",
                      }}
                    />
                  </span>

                  <div>
                    <h5 className="mb-8 fw-bold" style={{ color: "#ffffff" }}>
                      Warning
                    </h5>
                    <p
                      className="mb-0"
                      style={{ color: "#cbd5e1", fontSize: "15px" }}
                    >
                      Armada{" "}
                      <span style={{ fontWeight: 700, color: "#ffffff" }}>
                        {waitConfirm.armadaLabel}
                      </span>{" "}
                      is still on the way. Does the customer want to wait?
                    </p>
                  </div>
                </div>

                <button
                  type="button"
                  className="btn p-0"
                  aria-label="Close"
                  onClick={() => {
                    if (!saving) closeWaitConfirm();
                  }}
                  style={{
                    border: "none",
                    background: "transparent",
                    lineHeight: 1,
                  }}
                  disabled={saving}
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
                  onClick={closeWaitConfirm}
                  disabled={saving}
                  style={{
                    border: "2px solid #64748b",
                    color: "#e2e8f0",
                  }}
                >
                  No
                </button>

                <button
                  type="button"
                  className="btn btn-warning radius-12 px-16"
                  onClick={() => {
                    if (pendingSave) doSavePayload(pendingSave);
                  }}
                  disabled={saving}
                  style={{
                    border: "2px solid #d97706",
                  }}
                >
                  {saving ? "Saving..." : "Yes"}
                </button>
              </div>
            </div>
          </div>
        )}

        <div className="container-fluid py-4">
          <div className="row g-4">
            <div className="col-lg-12">
              <div className="card shadow-sm border-0">
                <div className="card-header bg-transparent d-flex justify-content-end">
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

                  <div className="row g-3">
                    <div className="col-md-6">
                      <label className="form-label fw-semibold">
                        Nomor Invoice
                      </label>
                      <input
                        className="form-control"
                        value={form.no_invoice}
                        readOnly
                      />
                    </div>

                    <div className="col-md-3">
                      <label className="form-label fw-semibold">Tanggal</label>
                      <input
                        type="date"
                        className="form-control"
                        value={form.tanggal}
                        onChange={onChange("tanggal")}
                      />
                    </div>

                    <div className="col-md-3">
                      <label className="form-label fw-semibold">Jatuh Tempo</label>
                      <input
                        type="date"
                        className="form-control"
                        value={form.due_date}
                        onChange={onChange("due_date")}
                      />
                    </div>

                    <div className="col-12">
                      <hr className="my-2" />
                    </div>

                    <div className="col-md-4">
                      <label className="form-label fw-semibold">
                        Nama Customer
                      </label>
                      <input
                        className="form-control"
                        value={form.nama_pelanggan}
                        onChange={onChange("nama_pelanggan")}
                        placeholder="Nama pelanggan"
                      />
                    </div>

                    <div className="col-md-4">
                      <label className="form-label fw-semibold">
                        Email Customer
                      </label>
                      <input
                        className="form-control"
                        value={form.email}
                        onChange={onChange("email")}
                        placeholder="email@domain.com"
                      />
                    </div>

                    <div className="col-md-4">
                      <label className="form-label fw-semibold">No. Telp</label>
                      <input
                        className="form-control"
                        value={form.no_telp}
                        onChange={onChange("no_telp")}
                        placeholder="0812xxxx"
                      />
                    </div>

                    <div className="col-12">
                      <hr className="my-2" />
                    </div>

                    <div className="col-12">
                      <label className="form-label fw-semibold">
                        Rincian Muat / Bongkar & Armada
                      </label>

                      {(form.rincian || []).map((r, i) => {
                        const rowTotal = calcRowSubtotal(r);

                        return (
                          <div
                            key={i}
                            className={`row g-2 align-items-center mb-2 ${
                              i > 0 ? "mt-3" : ""
                            }`}
                            style={{ paddingBottom: "6px" }}
                          >
                            <div className="col-md-3">
                              <input
                                type="text"
                                className="form-control"
                                placeholder="Lokasi Muat"
                                value={r.lokasi_muat}
                                onChange={(e) =>
                                  updateRincian(i, "lokasi_muat", e.target.value)
                                }
                              />
                            </div>

                            <div className="col-md-3">
                              <input
                                type="text"
                                className="form-control"
                                placeholder="Lokasi Bongkar"
                                value={r.lokasi_bongkar}
                                onChange={(e) =>
                                  updateRincian(
                                    i,
                                    "lokasi_bongkar",
                                    e.target.value
                                  )
                                }
                              />
                            </div>

                            <div className="col-md-4">
                              <select
                                className="form-select"
                                value={r.armada_id}
                                onChange={(e) =>
                                  updateRincian(i, "armada_id", e.target.value)
                                }
                                style={{
                                  backgroundColor: controlBg,
                                  color: controlText,
                                  borderColor: controlBorder,
                                }}
                              >
                                <option
                                  value=""
                                  style={{
                                    backgroundColor: optionBg,
                                    color: optionText,
                                  }}
                                >
                                  -- Pilih Armada --
                                </option>

                                {armadas.map((a) => (
                                  <option
                                    key={a.id}
                                    value={a.id}
                                    style={{
                                      backgroundColor: optionBg,
                                      color: optionText,
                                    }}
                                  >
                                    {a.nama_truk} – {a.plat_nomor} ({a.status})
                                  </option>
                                ))}
                              </select>
                            </div>

                            <div className="col-md-2 text-end">
                              {form.rincian.length > 1 && (
                                <button
                                  className="btn btn-sm btn-outline-danger"
                                  onClick={() => removeRincian(i)}
                                >
                                  Hapus
                                </button>
                              )}
                            </div>

                            <div className="col-md-3">
                              <input
                                type="date"
                                className="form-control"
                                value={r.armada_start_date}
                                onChange={(e) =>
                                  updateRincian(
                                    i,
                                    "armada_start_date",
                                    e.target.value
                                  )
                                }
                              />
                            </div>

                            <div className="col-md-3">
                              <input
                                type="date"
                                className="form-control"
                                value={r.armada_end_date}
                                onChange={(e) =>
                                  updateRincian(
                                    i,
                                    "armada_end_date",
                                    e.target.value
                                  )
                                }
                              />
                            </div>

                            <div className="col-md-2">
                              <input
                                type="number"
                                className="form-control"
                                placeholder="Tonase"
                                value={r.tonase}
                                onChange={(e) =>
                                  updateRincian(i, "tonase", e.target.value)
                                }
                              />
                            </div>

                            <div className="col-md-2">
                              <input
                                type="number"
                                className="form-control"
                                placeholder="Harga / Ton"
                                value={r.harga}
                                onChange={(e) =>
                                  updateRincian(i, "harga", e.target.value)
                                }
                              />
                            </div>

                            <div className="col-md-2">
                              <input
                                type="text"
                                className="form-control"
                                value={`Rp ${rowTotal.toLocaleString("id-ID")}`}
                                readOnly
                              />
                            </div>
                          </div>
                        );
                      })}

                      <button
                        className="btn btn-sm btn-outline-primary mt-4"
                        onClick={addRincian}
                      >
                        + Tambah Rincian
                      </button>
                    </div>

                    <div className="col-md-4 mt-4">
                      <label className="form-label fw-semibold">Subtotal</label>
                      <input
                        type="text"
                        className="form-control"
                        value={`Rp ${subtotal.toLocaleString("id-ID")}`}
                        readOnly
                      />
                    </div>

                    <div className="col-md-4 mt-4">
                      <label className="form-label fw-semibold">PPH (2%)</label>
                      <input
                        type="text"
                        className="form-control"
                        value={`Rp ${pph.toLocaleString("id-ID")}`}
                        readOnly
                      />
                    </div>

                    <div className="col-md-4 mt-4">
                      <label className="form-label fw-semibold">Total Bayar</label>
                      <input
                        type="text"
                        className="form-control fw-bold"
                        style={{
                          backgroundColor: "#f8f9fa",
                          color: "black",
                          WebkitTextFillColor: "black",
                        }}
                        value={`Rp ${totalBayar.toLocaleString("id-ID")}`}
                        readOnly
                      />
                    </div>

                    <div className="col-md-6 mt-4">
                      <label className="form-label fw-semibold">Status</label>
                      <select
                        className="form-select"
                        value={form.status}
                        onChange={onChange("status")}
                        style={{
                          backgroundColor: controlBg,
                          color: controlText,
                          borderColor: controlBorder,
                        }}
                      >
                        {["Unpaid", "Paid", "Waiting"].map((s) => (
                          <option
                            key={s}
                            value={s}
                            style={{
                              backgroundColor: optionBg,
                              color: optionText,
                            }}
                          >
                            {s}
                          </option>
                        ))}
                      </select>
                    </div>

                    <div className="col-md-6 mt-4">
                      <label className="form-label fw-semibold">
                        Diterima Oleh
                      </label>
                      <select
                        className="form-select"
                        value={form.diterima_oleh}
                        onChange={onChange("diterima_oleh")}
                        style={{
                          backgroundColor: controlBg,
                          color: controlText,
                          borderColor: controlBorder,
                        }}
                      >
                        {["Admin", "Owner"].map((role) => (
                          <option
                            key={role}
                            value={role}
                            style={{
                              backgroundColor: optionBg,
                              color: optionText,
                            }}
                          >
                            {role}
                          </option>
                        ))}
                      </select>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* ✅ MOBILE FIX: Breadcrumb & Dashboard Title supaya sejajar (TIDAK UBAH DESKTOP) */}
        <style jsx global>{`
          @media (max-width: 576px) {
            /* breadcrumb container */
            .breadcrumb,
            .breadcrumb * {
              font-size: 11px !important;
              line-height: 1.2 !important;
              white-space: nowrap !important;
            }

            /* title/dashboard text biasanya pakai .text-lg atau h6 */
            .page-title,
            .page-title * {
              font-size: 12px !important;
              line-height: 1.2 !important;
              white-space: nowrap !important;
            }

            h5,
            h6,
            .text-lg {
              font-size: 12px !important;
              line-height: 1.2 !important;
            }

            /* biar breadcrumb & dashboard bisa sejajar */
            .d-flex.align-items-center.flex-wrap {
              flex-wrap: nowrap !important;
            }
          }
        `}</style>
      </div>
    </>
  );
}
