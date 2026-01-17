"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { customerApi } from "@/lib/customerApi";

const userKey = "cvant_customer_user";

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
  const router = useRouter();
  const [message, setMessage] = useState(null);
  const [isLightMode, setIsLightMode] = useState(false);
  const [form, setForm] = useState({
    name: "",
    email: "",
    phone: "",
    company: "",
    pickup: "",
    destination: "",
    date: "",
    time: "",
    service: "regular",
    fleet: "cdd",
    cargo: "",
    weight: "",
    distance: "",
    notes: "",
    insurance: false,
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

  const pricing = useMemo(() => {
    const distance = Number(form.distance || 0);
    const weight = Number(form.weight || 0);
    const base = 350000;
    const serviceFactor =
      form.service === "express" ? 1.35 : form.service === "charter" ? 1.8 : 1;
    const fleetFactor =
      form.fleet === "trailer" ? 1.5 : form.fleet === "fuso" ? 1.25 : 1;
    const estimate = Math.round(
      (base + distance * 2500 + weight * 120000) * serviceFactor * fleetFactor
    );
    const insuranceFee = form.insurance ? Math.round(estimate * 0.02) : 0;
    return {
      estimate,
      insuranceFee,
      total: estimate + insuranceFee,
    };
  }, [form.distance, form.weight, form.service, form.fleet, form.insurance]);

  const formatCurrency = (value) => {
    const safeValue = Number.isFinite(value) ? value : 0;
    return `Rp ${safeValue.toLocaleString("id-ID")}`;
  };

  const handleSubmit = async (event) => {
    event.preventDefault();
    setMessage(null);

    if (
      !form.name ||
      !form.email ||
      !form.phone ||
      !form.pickup ||
      !form.destination ||
      !form.date ||
      !form.time
    ) {
      setMessage({
        type: "error",
        text: "Lengkapi data wajib sebelum melanjutkan.",
      });
      return;
    }

    try {
      await customerApi.post("/customer/orders", {
        pickup: form.pickup,
        destination: form.destination,
        pickup_date: form.date,
        pickup_time: form.time,
        service: form.service,
        fleet: form.fleet,
        cargo: form.cargo,
        weight: form.weight ? Number(form.weight) : null,
        distance: form.distance ? Number(form.distance) : null,
        notes: form.notes,
        insurance: form.insurance,
        estimate: pricing.estimate,
        insurance_fee: pricing.insuranceFee,
        total: pricing.total,
      });

      router.push("/order/payment");
    } catch (error) {
      setMessage({
        type: "error",
        text: error?.message || "Gagal membuat order. Coba lagi.",
      });
    }
  };

  const controlBg = isLightMode ? "#ffffff" : "#273142";
  const controlText = isLightMode ? "#0b1220" : "#ffffff";
  const controlBorder = isLightMode ? "#c7c8ca" : "#6c757d";
  const optionBg = controlBg;
  const optionText = controlText;

  return (
    <div className="container-fluid py-4">
      <div className="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-4">
        <div>
          <h4 className="mb-1">Form Order Pengiriman</h4>
          <p className="text-secondary-light mb-0">
            Lengkapi detail order untuk mendapatkan estimasi biaya dan lanjut ke pembayaran.
          </p>
        </div>
      </div>

      <div className="row g-4">
        <div className="col-lg-8">
          <div className="card shadow-sm border-0">
            <div className="card-header bg-transparent">
              <h6 className="mb-0">Detail Order</h6>
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

              <form onSubmit={handleSubmit}>
                <div className="row g-3">
                  <div className="col-md-6">
                    <label className="form-label fw-semibold">Nama</label>
                    <input
                      type="text"
                      className="form-control"
                      value={form.name}
                      onChange={onChange("name")}
                      placeholder="Nama pemesan"
                    />
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-semibold">Email</label>
                    <input
                      type="email"
                      className="form-control"
                      value={form.email}
                      onChange={onChange("email")}
                      placeholder="nama@email.com"
                    />
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-semibold">Nomor HP</label>
                    <input
                      type="tel"
                      className="form-control"
                      value={form.phone}
                      onChange={onChange("phone")}
                      placeholder="08xxxxxxxxxx"
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
                      onChange={onChange("company")}
                      placeholder="Nama perusahaan"
                    />
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-semibold">Pickup</label>
                    <input
                      type="text"
                      className="form-control"
                      value={form.pickup}
                      onChange={onChange("pickup")}
                      placeholder="Kota asal"
                    />
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-semibold">Destination</label>
                    <input
                      type="text"
                      className="form-control"
                      value={form.destination}
                      onChange={onChange("destination")}
                      placeholder="Kota tujuan"
                    />
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-semibold">Tanggal Pickup</label>
                    <input
                      type="date"
                      className="form-control"
                      value={form.date}
                      onChange={onChange("date")}
                    />
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-semibold">Jam Pickup</label>
                    <input
                      type="time"
                      className="form-control"
                      value={form.time}
                      onChange={onChange("time")}
                    />
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-semibold">Service</label>
                    <select
                      className="form-select"
                      value={form.service}
                      onChange={onChange("service")}
                      style={{
                        backgroundColor: controlBg,
                        color: controlText,
                        borderColor: controlBorder,
                      }}
                    >
                      {["regular", "express", "charter"].map((item) => (
                        <option
                          key={item}
                          value={item}
                          style={{ backgroundColor: optionBg, color: optionText }}
                        >
                          {item}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-semibold">Armada</label>
                    <select
                      className="form-select"
                      value={form.fleet}
                      onChange={onChange("fleet")}
                      style={{
                        backgroundColor: controlBg,
                        color: controlText,
                        borderColor: controlBorder,
                      }}
                    >
                      {[
                        { value: "cdd", label: "CDD Long" },
                        { value: "fuso", label: "Fuso Box" },
                        { value: "trailer", label: "Trailer" },
                      ].map((item) => (
                        <option
                          key={item.value}
                          value={item.value}
                          style={{ backgroundColor: optionBg, color: optionText }}
                        >
                          {item.label}
                        </option>
                      ))}
                    </select>
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
                  <div className="col-md-6">
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
                  <div className="col-md-6">
                    <label className="form-label fw-semibold">Jarak (km)</label>
                    <input
                      type="number"
                      className="form-control"
                      value={form.distance}
                      onChange={onChange("distance")}
                      placeholder="Contoh: 700"
                      min="0"
                    />
                  </div>
                  <div className="col-md-6">
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
                    <div className="form-check d-flex align-items-center gap-2">
                      <input
                        className="form-check-input"
                        type="checkbox"
                        id="insurance"
                        checked={form.insurance}
                        onChange={onChange("insurance")}
                      />
                      <label className="form-check-label" htmlFor="insurance">
                        Tambah asuransi barang (2%)
                      </label>
                    </div>
                  </div>
                </div>

                <div className="d-flex justify-content-end mt-4">
                  <button type="submit" className="btn btn-primary px-24">
                    Lanjutkan Pembayaran
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>

        <div className="col-lg-4">
          <div className="card shadow-sm border-0">
            <div className="card-header bg-transparent">
              <h6 className="mb-0">Ringkasan Estimasi</h6>
            </div>
            <div className="card-body">
              <table className="table table-borderless mb-0">
                <tbody>
                  <tr>
                    <td className="text-secondary-light">Service</td>
                    <td className="text-end fw-semibold">{form.service}</td>
                  </tr>
                  <tr>
                    <td className="text-secondary-light">Armada</td>
                    <td className="text-end fw-semibold">{form.fleet}</td>
                  </tr>
                  <tr>
                    <td className="text-secondary-light">Rute</td>
                    <td className="text-end fw-semibold">
                      {form.pickup || "-"} - {form.destination || "-"}
                    </td>
                  </tr>
                  <tr>
                    <td className="text-secondary-light">Estimasi dasar</td>
                    <td className="text-end fw-semibold">
                      {formatCurrency(pricing.estimate)}
                    </td>
                  </tr>
                  <tr>
                    <td className="text-secondary-light">Asuransi</td>
                    <td className="text-end fw-semibold">
                      {formatCurrency(pricing.insuranceFee)}
                    </td>
                  </tr>
                  <tr>
                    <td className="text-secondary-light">Total</td>
                    <td className="text-end fw-bold">
                      {formatCurrency(pricing.total)}
                    </td>
                  </tr>
                </tbody>
              </table>
              <p className="text-secondary-light mt-3 mb-0">
                Estimasi dihitung berdasarkan jarak, berat, dan service. Final akan
                dikonfirmasi oleh tim operasional.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default CustomerOrderLayer;
