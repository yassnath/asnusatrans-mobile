"use client";

import { useEffect, useMemo, useState } from "react";
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
  const [showEstimate, setShowEstimate] = useState(false);
  const [showThanks, setShowThanks] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState("");
  const [distanceKm, setDistanceKm] = useState(0);
  const [distanceText, setDistanceText] = useState("");
  const [distanceLoading, setDistanceLoading] = useState(false);
  const [distanceError, setDistanceError] = useState("");
  const rawPricePerKm = Number(process.env.NEXT_PUBLIC_PRICE_PER_KM);
  const pricePerKm = Number.isFinite(rawPricePerKm) ? rawPricePerKm : 0;
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
        armada_end_date: "",
        tonase: "",
        harga: "",
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
        setForm((prev) => ({
          ...prev,
          rincian:
            prev.rincian && prev.rincian.length > 0
              ? prev.rincian.map((row, index) =>
                  index === 0 && !row.armada_id
                    ? { ...row, armada_id: list[0]?.id ?? "" }
                    : row
                )
              : [
                  {
                    lokasi_muat: "",
                    lokasi_bongkar: "",
                    armada_id: list[0]?.id ?? "",
                    armada_start_date: "",
                    armada_end_date: "",
                    tonase: "",
                    harga: "",
                  },
                ],
        }));
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

  useEffect(() => {
    const primary = form.rincian?.[0] || {};
    const origin = String(primary.lokasi_muat || "").trim();
    const destination = String(primary.lokasi_bongkar || "").trim();

    if (!origin || !destination) {
      setDistanceKm(0);
      setDistanceText("");
      setDistanceError("");
      return;
    }

    let active = true;
    const controller = new AbortController();
    const timer = setTimeout(async () => {
      setDistanceLoading(true);
      setDistanceError("");

      try {
        const apiUrl = (process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080")
          .replace(/\/+$/, "");
        const res = await fetch(
          `${apiUrl}/api/public/distance?origin=${encodeURIComponent(
            origin
          )}&destination=${encodeURIComponent(destination)}`,
          { signal: controller.signal }
        );
        const data = await res.json();

        if (!res.ok) {
          throw new Error(data?.message || "Gagal menghitung jarak.");
        }

        if (!active) return;
        setDistanceKm(Number(data?.distance_km) || 0);
        setDistanceText(data?.distance_text || "");
      } catch (err) {
        if (!active || err?.name === "AbortError") return;
        setDistanceKm(0);
        setDistanceText("");
        setDistanceError(err?.message || "Gagal menghitung jarak.");
      } finally {
        if (active) setDistanceLoading(false);
      }
    }, 600);

    return () => {
      active = false;
      clearTimeout(timer);
      controller.abort();
    };
  }, [form.rincian?.[0]?.lokasi_muat, form.rincian?.[0]?.lokasi_bongkar]);

  useEffect(() => {
    if (!pricePerKm) return;
    const autoHarga = distanceKm ? Math.round(distanceKm * pricePerKm) : "";

    setForm((prev) => {
      const updated = [...(prev.rincian || [])];
      if (!updated[0]) return prev;
      updated[0] = { ...updated[0], harga: String(autoHarga) };
      return { ...prev, rincian: updated };
    });
  }, [distanceKm, pricePerKm]);

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
          armada_id: armadas[0]?.id ?? "",
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
    const tonase = parseFloat(row?.tonase) || 0;
    const harga = parseFloat(row?.harga) || 0;
    return tonase * harga;
  };

  const subtotal = useMemo(() => {
    return (form.rincian || []).reduce(
      (sum, row) => sum + calcRowSubtotal(row),
      0
    );
  }, [form.rincian]);

  const pphFee = useMemo(() => subtotal * 0.02, [subtotal]);
  const totalBayar = useMemo(() => subtotal - pphFee, [subtotal, pphFee]);

  const formatCurrency = (value) => {
    const safeValue = Number.isFinite(value) ? value : 0;
    return `Rp ${safeValue.toLocaleString("id-ID")}`;
  };

  const handleSubmit = (event) => {
    event.preventDefault();
    setMessage(null);

    if (
      !form.name ||
      !form.email ||
      !form.phone ||
      !form.tanggal ||
      !form.due_date ||
      !form.status
    ) {
      setMessage({
        type: "error",
        text: "Lengkapi data wajib sebelum melanjutkan.",
      });
      return;
    }

    if (distanceLoading) {
      setMessage({
        type: "error",
        text: "Sedang menghitung jarak. Tunggu sebentar.",
      });
      return;
    }

    if (distanceError) {
      setMessage({
        type: "error",
        text: distanceError,
      });
      return;
    }

    if (!distanceKm) {
      setMessage({
        type: "error",
        text: "Jarak belum ditemukan. Pastikan lokasi muat dan bongkar benar.",
      });
      return;
    }

    if (!pricePerKm) {
      setMessage({
        type: "error",
        text: "Harga per km belum diset. Hubungi admin.",
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
        !String(row.armada_start_date || "").trim() ||
        !String(row.armada_end_date || "").trim() ||
        !String(row.tonase || "").trim() ||
        !String(row.harga || "").trim()
    );

    if (invalidRow) {
      setMessage({
        type: "error",
        text: "Lengkapi semua rincian muat/bongkar sebelum melanjutkan.",
      });
      return;
    }

    setSubmitError("");
    setShowEstimate(true);
  };

  const handleConfirmOrder = async () => {
    setSubmitting(true);
    setSubmitError("");

    try {
      const normalizedRincian = (form.rincian || []).map((row) => ({
        ...row,
        armada_id: row.armada_id ? Number(row.armada_id) : "",
        tonase: row.tonase ? Number(row.tonase) : "",
        harga: row.harga ? Number(row.harga) : "",
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

      await customerApi.post("/customer/orders", {
        pickup,
        destination,
        pickup_date: pickupDate,
        pickup_time: pickupTime,
        service: "regular",
        fleet: armadaLabel,
        cargo: form.cargo,
        weight: form.weight ? Number(form.weight) : null,
        distance: distanceKm ? Number(distanceKm) : null,
        notes: form.notes,
        insurance: false,
        estimate: subtotal,
        insurance_fee: pphFee,
        total: totalBayar,
        tanggal: form.tanggal,
        due_date: form.due_date,
        nama_pelanggan: form.name,
        email: form.email,
        no_telp: form.phone,
        status: form.status,
        diterima_oleh: form.diterima_oleh,
        rincian: normalizedRincian,
        total_biaya: subtotal,
        pph: pphFee,
        total_bayar: totalBayar,
      });

      setShowEstimate(false);
      setShowThanks(true);
    } catch (error) {
      setSubmitError(error?.message || "Gagal membuat order. Coba lagi.");
    } finally {
      setSubmitting(false);
    }
  };

  const controlBg = isLightMode ? "#ffffff" : "#273142";
  const controlText = isLightMode ? "#0b1220" : "#ffffff";
  const controlBorder = isLightMode ? "#c7c8ca" : "#6c757d";
  const optionBg = controlBg;
  const optionText = controlText;
  const primaryRincian = form.rincian?.[0] || {};
  const selectedFleet = armadas.find(
    (armada) => String(armada?.id) === String(primaryRincian.armada_id)
  );
  const fleetLabel = selectedFleet
    ? selectedFleet.kapasitas
      ? `${selectedFleet.nama_truk} (${selectedFleet.kapasitas} ton)`
      : selectedFleet.nama_truk
    : "-";

  return (
    <div className="container-fluid py-4">
      <div className="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-4">
        <div>
          <h4 className="mb-1">Form Order Pengiriman</h4>
          <p className="text-secondary-light mb-0">
            Lengkapi detail order untuk mendapatkan estimasi biaya.
          </p>
        </div>
      </div>

      <div className="row g-4">
        <div className="col-12">
          <form onSubmit={handleSubmit}>
            <div className="card shadow-sm border-0">
              <div className="card-header bg-transparent d-flex justify-content-end">
                <button type="submit" className="btn btn-sm btn-primary">
                  Simpan Order
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
                    <label className="form-label fw-semibold">Tanggal</label>
                    <input
                      type="date"
                      className="form-control"
                      value={form.tanggal}
                      readOnly
                    />
                  </div>

                  <div className="col-12">
                    <hr className="my-2" />
                  </div>

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
                  <div className="col-md-4">
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
                  <div className="col-md-4">
                    <label className="form-label fw-semibold">Jenis Barang</label>
                    <input
                      type="text"
                      className="form-control"
                      value={form.cargo}
                      onChange={onChange("cargo")}
                      placeholder="Contoh: material, makanan"
                    />
                  </div>
                  <div className="col-md-4">
                    <label className="form-label fw-semibold">Berat (ton)</label>
                    <input
                      type="number"
                      className="form-control"
                      value={form.weight}
                      onChange={onChange("weight")}
                      placeholder="Contoh: 4"
                      min="0"
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
                      const rowTotal = calcRowSubtotal(row);
                      const isAutoHarga = pricePerKm > 0 && index === 0;
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
                              value={row.armada_id}
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
                                  : "-- Pilih Armada --"}
                              </option>
                              {armadas.map((item) => {
                                const label = item?.kapasitas
                                  ? `${item.nama_truk} (${item.kapasitas} ton)`
                                  : item?.nama_truk || "Armada";
                                return (
                                  <option
                                    key={item.id}
                                    value={item.id}
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
                          <div className="col-md-2 text-end">
                            {(form.rincian || []).length > 1 && (
                              <button
                                className="btn btn-sm btn-outline-danger"
                                type="button"
                                onClick={() => removeRincian(index)}
                              >
                                Hapus
                              </button>
                            )}
                          </div>
                          <div className="col-md-3">
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
                          <div className="col-md-3">
                            <input
                              type="date"
                              className="form-control"
                              value={row.armada_end_date}
                              onChange={(e) =>
                                updateRincian(
                                  index,
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
                              value={row.tonase}
                              onChange={(e) =>
                                updateRincian(index, "tonase", e.target.value)
                              }
                            />
                          </div>
                          <div className="col-md-2">
                            <input
                              type="number"
                              className="form-control"
                              placeholder={isAutoHarga ? "Otomatis" : "Harga / Ton"}
                              value={row.harga}
                              onChange={(e) =>
                                updateRincian(index, "harga", e.target.value)
                              }
                              readOnly={isAutoHarga}
                            />
                          </div>
                          <div className="col-md-2">
                            <input
                              type="text"
                              className="form-control"
                              value={formatCurrency(rowTotal)}
                              readOnly
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
                      + Tambah Rincian
                    </button>
                  </div>

                  <div className="col-md-4 mt-4">
                    <label className="form-label fw-semibold">Subtotal</label>
                    <input
                      type="text"
                      className="form-control"
                      value={formatCurrency(subtotal)}
                      readOnly
                    />
                  </div>
                  <div className="col-md-4 mt-4">
                    <label className="form-label fw-semibold">PPH (2%)</label>
                    <input
                      type="text"
                      className="form-control"
                      value={formatCurrency(pphFee)}
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
                      value={formatCurrency(totalBayar)}
                      readOnly
                    />
                  </div>

                </div>
              </div>
            </div>
          </form>
        </div>
      </div>

      {showEstimate && (
        <div
          className="position-fixed top-0 start-0 w-100 h-100 d-flex align-items-center justify-content-center"
          style={{
            zIndex: 9999,
            background: "rgba(0,0,0,0.55)",
            padding: "16px",
          }}
          onClick={() => (submitting ? null : setShowEstimate(false))}
        >
          <div
            className="card shadow-none border"
            style={{ maxWidth: "520px", width: "100%" }}
            onClick={(event) => event.stopPropagation()}
          >
            <div className="card-body p-24">
              <h6 className="mb-16">Ringkasan Estimasi</h6>
              <table className="table table-borderless mb-12">
                <tbody>
                  <tr>
                    <td className="text-secondary-light">Armada</td>
                    <td className="text-end fw-semibold">{fleetLabel}</td>
                  </tr>
                  <tr>
                    <td className="text-secondary-light">Rute</td>
                    <td className="text-end fw-semibold">
                      {primaryRincian.lokasi_muat || "-"} -{" "}
                      {primaryRincian.lokasi_bongkar || "-"}
                    </td>
                  </tr>
                  <tr>
                    <td className="text-secondary-light">Jarak</td>
                    <td className="text-end fw-semibold">
                      {distanceLoading
                        ? "Menghitung..."
                        : distanceText
                        ? distanceText
                        : distanceKm
                        ? `${distanceKm} km`
                        : "-"}
                    </td>
                  </tr>
                  <tr>
                    <td className="text-secondary-light">Harga / km</td>
                    <td className="text-end fw-semibold">
                      {pricePerKm ? `${formatCurrency(pricePerKm)} / km` : "-"}
                    </td>
                  </tr>
                  <tr>
                    <td className="text-secondary-light">Subtotal</td>
                    <td className="text-end fw-semibold">
                      {formatCurrency(subtotal)}
                    </td>
                  </tr>
                  <tr>
                    <td className="text-secondary-light">PPH (2%)</td>
                    <td className="text-end fw-semibold">
                      {formatCurrency(pphFee)}
                    </td>
                  </tr>
                  <tr>
                    <td className="text-secondary-light">Total Bayar</td>
                    <td className="text-end fw-bold">
                      {formatCurrency(totalBayar)}
                    </td>
                  </tr>
                </tbody>
              </table>
              <p className="text-secondary-light mb-0">
                Estimasi dihitung berdasarkan rincian muat/bongkar & jarak.
              </p>
              {submitError ? (
                <div className="alert alert-danger mt-3 mb-0">{submitError}</div>
              ) : null}
              <div className="d-flex justify-content-end gap-2 mt-4">
                <button
                  type="button"
                  className="btn btn-outline-primary px-16"
                  onClick={() => setShowEstimate(false)}
                  disabled={submitting}
                >
                  Cancel
                </button>
                <button
                  type="button"
                  className="btn btn-primary px-20"
                  onClick={handleConfirmOrder}
                  disabled={submitting}
                >
                  {submitting ? "Menyimpan..." : "Oke"}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {showThanks && (
        <div
          className="position-fixed top-0 start-0 w-100 h-100 d-flex align-items-center justify-content-center"
          style={{
            zIndex: 9999,
            background: "rgba(0,0,0,0.55)",
            padding: "16px",
          }}
          onClick={() => setShowThanks(false)}
        >
          <div
            className="card shadow-none border"
            style={{ maxWidth: "480px", width: "100%" }}
            onClick={(event) => event.stopPropagation()}
          >
            <div className="card-body p-24 text-center">
              <h6 className="mb-12">Terimakasih sudah order</h6>
              <p className="text-secondary-light mb-20">
                Ditunggu update selanjutnya.
              </p>
              <button
                type="button"
                className="btn btn-primary px-24"
                onClick={() => setShowThanks(false)}
              >
                Oke
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default CustomerOrderLayer;
