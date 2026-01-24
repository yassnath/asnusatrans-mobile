"use client";

import { useEffect, useState } from "react";
import { customerApi } from "@/lib/customerApi";

const userKey = "cvant_customer_user";

const getTodayDate = () => {
  const now = new Date();
  const tzOffset = now.getTimezoneOffset() * 60000;
  return new Date(now - tzOffset).toISOString().split("T")[0];
};

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

const CustomerOrderLayer = () => {
  const [message, setMessage] = useState(null);
  const [isLightMode, setIsLightMode] = useState(false);
  const [armadas, setArmadas] = useState([]);
  const [armadaLoading, setArmadaLoading] = useState(true);
  const [armadaError, setArmadaError] = useState("");
  const [showConfirm, setShowConfirm] = useState(false);
  const [showWaiting, setShowWaiting] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const todayDate = getTodayDate();
  const [form, setForm] = useState({
    name: "",
    email: "",
    phone: "",
    company: "",
    tanggal: todayDate,
    due_date: todayDate,
    status: "Unpaid",
    diterima_oleh: "Customer",
    cargo: "",
    weight: "",
    notes: "",
    rincian: [
      {
        lokasi_muat: "",
        lokasi_bongkar: "",
        armada_id: "",
        armada_start_date: "",
      },
    ],
  });

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

  useEffect(() => {
    let active = true;

    const loadArmadas = async () => {
      setArmadaLoading(true);
      setArmadaError("");

      try {
        const apiUrl = (process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080")
          .replace(/\/+$/, "");
        const res = await fetch(`${apiUrl}/api/public/armadas`);
        const data = await res.json();

        if (!res.ok) {
          throw new Error(data?.message || "Gagal memuat armada.");
        }

        if (!active) return;
        const list = Array.isArray(data) ? data : [];
        setArmadas(list);
      } catch (err) {
        if (!active) return;
        setArmadas([]);
        setArmadaError(err?.message || "Gagal memuat armada.");
      } finally {
        if (active) setArmadaLoading(false);
      }
    };

    loadArmadas();
    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    const stored = localStorage.getItem(userKey);
    if (stored) {
      try {
        const user = JSON.parse(stored);
        setForm((prev) => ({
          ...prev,
          name: user.name || "",
          email: user.email || "",
          phone: user.phone || "",
          company: user.company || "",
        }));
      } catch {
        // ignore
      }
    }

    const loadProfile = async () => {
      try {
        const res = await customerApi.get("/customer/me");
        const user = res?.customer;
        if (!user) return;
        localStorage.setItem(userKey, JSON.stringify(user));
        setForm((prev) => ({
          ...prev,
          name: user.name || prev.name,
          email: user.email || prev.email,
          phone: user.phone || prev.phone,
          company: user.company || prev.company,
        }));
      } catch {
        // ignore api errors
      }
    };

    loadProfile();
  }, []);

  const onChange = (field) => (event) => {
    const value =
      event.target.type === "checkbox" ? event.target.checked : event.target.value;
    setMessage(null);
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  const updateRincian = (index, key, value) => {
    setForm((prev) => {
      const updated = [...(prev.rincian || [])];
      updated[index] = { ...updated[index], [key]: value };
      return { ...prev, rincian: updated };
    });
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

  const handleSubmit = async (event) => {
    event.preventDefault();
    setMessage(null);

    if (
      !form.name ||
      !form.email ||
      !form.phone ||
      !form.status
    ) {
      setMessage({
        type: "error",
        text: "Lengkapi data wajib sebelum melanjutkan.",
      });
      return;
    }

    if (!Array.isArray(form.rincian) || form.rincian.length === 0) {
      setMessage({
        type: "error",
        text: "Rincian muat/bongkar wajib diisi.",
      });
      return;
    }

    const invalidRow = form.rincian.some(
      (row) =>
        !String(row.lokasi_muat || "").trim() ||
        !String(row.lokasi_bongkar || "").trim() ||
        !String(row.armada_id || "").trim() ||
        !String(row.armada_start_date || "").trim()
    );

    if (invalidRow) {
      setMessage({
        type: "error",
        text: "Lengkapi semua rincian muat/bongkar sebelum melanjutkan.",
      });
      return;
    }

    setShowConfirm(true);
  };

  const handleConfirmOrder = async () => {
    setSubmitting(true);
    setMessage(null);

    try {
      const normalizedRincian = (form.rincian || []).map((row) => ({
        lokasi_muat: row.lokasi_muat,
        lokasi_bongkar: row.lokasi_bongkar,
        armada_id: row.armada_id ? Number(row.armada_id) : "",
        armada_start_date: row.armada_start_date || "",
        armada_end_date: row.armada_end_date || null,
        tonase: 0,
        harga: 0,
      }));
      const firstRincian = normalizedRincian[0] || {};
      const armadaLabel =
        armadas.find(
          (armada) => String(armada?.id) === String(firstRincian.armada_id)
        )?.nama_truk || "-";
      const pickup = firstRincian.lokasi_muat || "-";
      const destination = firstRincian.lokasi_bongkar || "-";
      const pickupDate = firstRincian.armada_start_date || form.tanggal;
      const pickupTime = "00:00";
      const estimate = 0;
      const insuranceFee = 0;
      const total = 0;

      await customerApi.post("/customer/orders", {
        pickup,
        destination,
        pickup_date: pickupDate,
        pickup_time: pickupTime,
        service: "regular",
        fleet: armadaLabel,
        cargo: form.cargo,
        weight: form.weight ? Number(form.weight) : null,
        distance: null,
        notes: form.notes,
        insurance: false,
        estimate,
        insurance_fee: insuranceFee,
        total,
        tanggal: form.tanggal,
        due_date: form.due_date,
        nama_pelanggan: form.name,
        email: form.email,
        no_telp: form.phone,
        status: form.status,
        diterima_oleh: form.diterima_oleh,
        rincian: normalizedRincian,
        total_biaya: estimate,
        pph: insuranceFee,
        total_bayar: total,
      });

      setShowConfirm(false);
      setShowWaiting(true);
    } catch (error) {
      setMessage({
        type: "error",
        text: error?.message || "Gagal membuat order. Coba lagi.",
      });
      setShowConfirm(false);
    } finally {
      setSubmitting(false);
    }
  };

  const controlBg = isLightMode ? "#ffffff" : "#273142";
  const controlText = isLightMode ? "#0b1220" : "#ffffff";
  const controlBorder = isLightMode ? "#c7c8ca" : "#6c757d";
  const optionBg = controlBg;
  const optionText = controlText;

  return (
    <div className="container-fluid py-4">
      <div className="row g-4">
        <div className="col-12">
          <form onSubmit={handleSubmit}>
            <div className="card shadow-sm border-0">
              <div className="card-header bg-transparent d-flex justify-content-end">
                <button
                  type="submit"
                  className="btn btn-sm btn-primary"
                  disabled={submitting}
                >
                  {submitting ? "Saving..." : "Save Order"}
                </button>
              </div>
              <div className="card-body">
                {message && (
                  <div
                    className={`alert ${
                      message.type === "success" ? "alert-success" : "alert-danger"
                    } mb-4`}
                  >
                    {message.text}
                  </div>
                )}

                <div className="row g-3">
                  <div className="col-md-4">
                    <label className="form-label fw-semibold">Nama</label>
                    <input
                      type="text"
                      className="form-control"
                      value={form.name}
                      readOnly
                    />
                  </div>
                  <div className="col-md-4">
                    <label className="form-label fw-semibold">Email</label>
                    <input
                      type="email"
                      className="form-control"
                      value={form.email}
                      readOnly
                    />
                  </div>
                  <div className="col-md-4">
                    <label className="form-label fw-semibold">Nomor HP</label>
                    <input
                      type="tel"
                      className="form-control"
                      value={form.phone}
                      readOnly
                    />
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-semibold">
                      Perusahaan (opsional)
                    </label>
                    <input
                      type="text"
                      className="form-control"
                      value={form.company}
                      readOnly
                    />
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-semibold">Jenis Barang</label>
                    <input
                      type="text"
                      className="form-control"
                      value={form.cargo}
                      onChange={onChange("cargo")}
                      placeholder="Contoh: material, makanan"
                    />
                  </div>
                  <div className="col-md-12">
                    <label className="form-label fw-semibold">Catatan</label>
                    <input
                      type="text"
                      className="form-control"
                      value={form.notes}
                      onChange={onChange("notes")}
                      placeholder="Catatan tambahan"
                    />
                  </div>

                  <div className="col-12">
                    <hr className="my-2" />
                  </div>

                  <div className="col-12">
                    <label className="form-label fw-semibold">
                      Rincian Muat / Bongkar & Armada
                    </label>

                    {armadaError ? (
                      <div className="text-danger text-sm mb-2">{armadaError}</div>
                    ) : null}

                    {(form.rincian || []).map((row, index) => {
                      return (
                        <div
                          key={index}
                          className={`row g-2 align-items-center mb-2 ${
                            index > 0 ? "mt-3" : ""
                          }`}
                          style={{ paddingBottom: "6px" }}
                        >
                          <div className="col-md-3">
                            <input
                              type="text"
                              className="form-control"
                              placeholder="Lokasi Muat"
                              value={row.lokasi_muat}
                              onChange={(e) =>
                                updateRincian(index, "lokasi_muat", e.target.value)
                              }
                            />
                          </div>
                          <div className="col-md-3">
                            <input
                              type="text"
                              className="form-control"
                              placeholder="Lokasi Bongkar"
                              value={row.lokasi_bongkar}
                              onChange={(e) =>
                                updateRincian(
                                  index,
                                  "lokasi_bongkar",
                                  e.target.value
                                )
                              }
                            />
                          </div>
                          <div className="col-md-4">
                            <select
                              className="form-select"
                              value={row.armada_id || ""}
                              disabled={armadaLoading}
                              onChange={(e) =>
                                updateRincian(index, "armada_id", e.target.value)
                              }
                              style={{
                                backgroundColor: controlBg,
                                color: controlText,
                                borderColor: controlBorder,
                              }}
                            >
                              <option
                                value=""
                                style={{ backgroundColor: optionBg, color: optionText }}
                              >
                                {armadaLoading
                                  ? "Memuat armada..."
                                  : "Pilih Armada"}
                              </option>
                              {armadas.map((item) => {
                                const statusLabel = item?.status || "Ready";
                                const isFull =
                                  String(statusLabel).toLowerCase().includes("full");
                                const label = item?.kapasitas
                                  ? `${item.nama_truk} (${item.kapasitas} ton) - ${statusLabel}`
                                  : `${item?.nama_truk || "Armada"} - ${statusLabel}`;
                                return (
                                  <option
                                    key={item.id}
                                    value={item.id}
                                    disabled={isFull}
                                    style={{
                                      backgroundColor: optionBg,
                                      color: optionText,
                                    }}
                                  >
                                    {label}
                                  </option>
                                );
                              })}
                            </select>
                          </div>
                          <div className="col-md-1 text-end">
                            {(form.rincian || []).length > 1 && (
                              <button
                                className="btn btn-sm btn-outline-danger"
                                type="button"
                                onClick={() => removeRincian(index)}
                              >
                                Remove
                              </button>
                            )}
                          </div>
                          <div className="col-md-4">
                            <input
                              type="date"
                              className="form-control"
                              value={row.armada_start_date}
                              onChange={(e) =>
                                updateRincian(
                                  index,
                                  "armada_start_date",
                                  e.target.value
                                )
                              }
                            />
                          </div>
                        </div>
                      );
                    })}

                    <button
                      type="button"
                      className="btn btn-sm btn-outline-primary mt-4"
                      onClick={addRincian}
                    >
                      + Add Detail
                    </button>
                  </div>

                </div>
              </div>
            </div>
          </form>
        </div>
      </div>

      {showConfirm && (
        <div
          className="position-fixed top-0 start-0 w-100 h-100 d-flex align-items-center justify-content-center"
          style={{
            zIndex: 9999,
            background: "rgba(0,0,0,0.55)",
            padding: "16px",
          }}
          onClick={() => {
            if (!submitting) setShowConfirm(false);
          }}
        >
          <div
            className="cvant-order-modal"
            style={{ maxWidth: "480px", width: "100%" }}
            onClick={(event) => event.stopPropagation()}
          >
            <div className="cvant-order-modal-header">
              <h6 className="mb-0">Confirm Order</h6>
            </div>
            <div className="cvant-order-modal-body text-center">
              <p className="text-secondary-light mb-20">
                Are you sure about your order?
              </p>
              <div className="d-flex justify-content-center gap-2 flex-wrap">
                <button
                  type="button"
                  className="btn btn-outline-secondary px-24"
                  onClick={() => setShowConfirm(false)}
                  disabled={submitting}
                >
                  Cancel
                </button>
                <button
                  type="button"
                  className="btn btn-primary px-24"
                  onClick={handleConfirmOrder}
                  disabled={submitting}
                >
                  {submitting ? "Processing..." : "Submit Order"}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {showWaiting && (
        <div
          className="position-fixed top-0 start-0 w-100 h-100 d-flex align-items-center justify-content-center"
          style={{
            zIndex: 9999,
            background: "rgba(0,0,0,0.55)",
            padding: "16px",
          }}
          onClick={() => setShowWaiting(false)}
        >
          <div
            className="cvant-order-modal"
            style={{ maxWidth: "520px", width: "100%" }}
            onClick={(event) => event.stopPropagation()}
          >
            <div className="cvant-order-modal-header">
              <h6 className="mb-0">Order submitted</h6>
            </div>
            <div className="cvant-order-modal-body text-center">
              <p className="text-secondary-light mb-20">
                Menunggu status acc dari owner/admin. Invoice akan dikirimkan ke
                notifikasi Anda untuk melanjutkan pembayaran.
              </p>
              <button
                type="button"
                className="btn btn-primary px-24"
                onClick={() => setShowWaiting(false)}
              >
                OK
              </button>
            </div>
          </div>
        </div>
      )}

      <style jsx global>{`
        .cvant-order-modal {
          background: var(--white);
          border-radius: 16px;
          box-shadow: 0px 13px 30px 10px rgba(46, 45, 116, 0.05);
          border: 0;
          overflow: hidden;
        }

        .cvant-order-modal-header {
          padding: 14px 18px;
          background: var(--primary-50);
          border-bottom: 1px solid rgba(148, 163, 184, 0.2);
        }

        .cvant-order-modal-body {
          padding: 22px 20px 24px;
        }
      `}</style>
    </div>
  );
};

export default CustomerOrderLayer;
