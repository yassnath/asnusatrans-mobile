"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import ThemeToggleButton from "@/helper/ThemeToggleButton";
import PublicChatbotWidget from "@/components/PublicChatbotWidget";

const ordersKey = "cvant_customer_orders";
const latestOrderKey = "cvant_latest_order";
const userKey = "cvant_customer_user";
const tokenKey = "cvant_customer_token";

const CustomerOrderLayer = () => {
  const router = useRouter();
  const [message, setMessage] = useState(null);
  const [customer, setCustomer] = useState(null);
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
    const stored = localStorage.getItem(userKey);
    if (!stored) return;
    try {
      const user = JSON.parse(stored);
      setCustomer(user);
      setForm((prev) => ({
        ...prev,
        name: user.name || "",
        email: user.email || "",
        phone: user.phone || "",
        company: user.company || "",
      }));
    } catch {
      // ignore invalid storage
    }
  }, []);

  const customerInitial = useMemo(() => {
    const name = customer?.name || "";
    return name ? name.trim().charAt(0).toUpperCase() : "C";
  }, [customer]);

  const customerRole = customer?.role || "Customer";

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
    const estimate = Math.round((base + distance * 2500 + weight * 120000) * serviceFactor * fleetFactor);
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

  const handleSignOut = () => {
    localStorage.removeItem(tokenKey);
    localStorage.removeItem(userKey);
    document.cookie =
      "customer_token=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT; SameSite=Lax;";
    router.push("/customer/sign-in");
  };

  const handleSubmit = (event) => {
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
      setMessage({ type: "error", text: "Lengkapi data wajib sebelum melanjutkan." });
      return;
    }

    const order = {
      id: `ORD-${Date.now().toString().slice(-6)}`,
      name: form.name,
      email: form.email,
      phone: form.phone,
      company: form.company,
      pickup: form.pickup,
      destination: form.destination,
      date: form.date,
      time: form.time,
      service: form.service,
      fleet: form.fleet,
      cargo: form.cargo,
      weight: form.weight,
      distance: form.distance,
      notes: form.notes,
      insurance: form.insurance,
      estimate: pricing.estimate,
      insuranceFee: pricing.insuranceFee,
      total: pricing.total,
      status: "Pending Payment",
      createdAt: new Date().toISOString(),
    };

    const currentOrders = JSON.parse(localStorage.getItem(ordersKey) || "[]");
    const nextOrders = [order, ...currentOrders];
    localStorage.setItem(ordersKey, JSON.stringify(nextOrders));
    localStorage.setItem(latestOrderKey, JSON.stringify(order));
    router.push("/order/payment");
  };

  return (
    <>
      <style jsx global>{`
        .cvant-order {
          --cvant-order-text: #e2e8f0;
          --cvant-order-muted: #94a3b8;
          --cvant-order-border: rgba(148, 163, 184, 0.16);
          --cvant-order-border-strong: rgba(148, 163, 184, 0.3);
          --cvant-order-card-bg: rgba(15, 23, 42, 0.7);
          --cvant-order-input-bg: rgba(15, 23, 42, 0.7);
          --cvant-order-nav-bg: rgba(12, 17, 27, 0.8);
          --cvant-order-pill-bg: rgba(15, 23, 42, 0.35);
          --cvant-order-user-bg: rgba(15, 23, 42, 0.35);
          --cvant-order-danger-text: #fecaca;
          --cvant-order-danger-bg: rgba(239, 68, 68, 0.15);
          --cvant-order-danger-border: rgba(239, 68, 68, 0.6);
          --cvant-order-shadow: 0 20px 40px rgba(0, 0, 0, 0.35);
          --cvant-order-bg: radial-gradient(
              900px 500px at 12% 12%,
              rgba(91, 140, 255, 0.16),
              transparent 60%
            ),
            radial-gradient(
              800px 520px at 85% 20%,
              rgba(34, 211, 238, 0.14),
              transparent 60%
            ),
            linear-gradient(180deg, #0f172a 0%, #0b1220 100%);
          min-height: 100vh;
          background: var(--cvant-order-bg);
          color: var(--cvant-order-text);
        }

        html[data-theme="light"] .cvant-order,
        html[data-bs-theme="light"] .cvant-order {
          --cvant-order-text: #0f172a;
          --cvant-order-muted: #475569;
          --cvant-order-border: rgba(15, 23, 42, 0.12);
          --cvant-order-border-strong: rgba(15, 23, 42, 0.2);
          --cvant-order-card-bg: rgba(255, 255, 255, 0.95);
          --cvant-order-input-bg: rgba(255, 255, 255, 0.95);
          --cvant-order-nav-bg: rgba(248, 250, 252, 0.92);
          --cvant-order-pill-bg: rgba(248, 250, 252, 0.9);
          --cvant-order-user-bg: rgba(241, 245, 249, 0.9);
          --cvant-order-danger-text: #b91c1c;
          --cvant-order-danger-bg: rgba(239, 68, 68, 0.12);
          --cvant-order-danger-border: rgba(239, 68, 68, 0.4);
          --cvant-order-shadow: 0 20px 40px rgba(15, 23, 42, 0.12);
          --cvant-order-bg: radial-gradient(
              900px 500px at 12% 12%,
              rgba(91, 140, 255, 0.1),
              transparent 60%
            ),
            radial-gradient(
              800px 520px at 85% 20%,
              rgba(34, 211, 238, 0.1),
              transparent 60%
            ),
            linear-gradient(180deg, #f8fafc 0%, #e2e8f0 100%);
        }

        .cvant-order-container {
          width: min(1200px, 92vw);
          margin: 0 auto;
        }

        .cvant-order-nav {
          position: sticky;
          top: 0;
          z-index: 20;
          border-bottom: 1px solid var(--cvant-order-border);
          background: var(--cvant-order-nav-bg);
          backdrop-filter: blur(10px);
        }

        .cvant-order-nav-inner {
          display: flex;
          align-items: center;
          justify-content: space-between;
          padding: 16px 0;
          gap: 16px;
          flex-wrap: wrap;
        }

        .cvant-order-nav a {
          text-decoration: none;
        }

        .cvant-order-actions {
          display: flex;
          align-items: center;
          gap: 12px;
          flex-wrap: wrap;
        }

        .cvant-order-pill {
          padding: 6px 12px;
          border-radius: 999px;
          border: 1px solid var(--cvant-order-border-strong);
          color: var(--cvant-order-muted);
          background: var(--cvant-order-pill-bg);
          font-size: 13px;
        }

        .cvant-order-logout {
          border-radius: 999px;
          border: 1px solid var(--cvant-order-danger-border);
          background: var(--cvant-order-danger-bg);
          color: var(--cvant-order-danger-text);
          padding: 8px 14px;
        }

        .cvant-order-user {
          display: flex;
          align-items: center;
          gap: 10px;
          padding: 6px 12px;
          border-radius: 999px;
          border: 1px solid var(--cvant-order-border);
          background: var(--cvant-order-user-bg);
          color: var(--cvant-order-text);
        }

        .cvant-order-avatar {
          width: 32px;
          height: 32px;
          border-radius: 50%;
          background: var(--primary-600);
          color: #fff;
          display: inline-flex;
          align-items: center;
          justify-content: center;
          font-weight: 600;
          font-size: 14px;
        }

        .cvant-order-user-name {
          font-size: 13px;
          font-weight: 600;
          line-height: 1.2;
        }

        .cvant-order-user-role {
          font-size: 11px;
          color: var(--cvant-order-muted);
          line-height: 1.2;
        }

        .cvant-order-main {
          padding: 40px 0 70px;
        }

        .cvant-order-grid {
          display: grid;
          grid-template-columns: 1.1fr 0.9fr;
          gap: 28px;
        }

        .cvant-order-card {
          border-radius: 20px;
          padding: 24px;
          background: var(--cvant-order-card-bg);
          border: 1px solid var(--cvant-order-border);
          box-shadow: var(--cvant-order-shadow);
        }

        .cvant-order-title {
          font-size: 24px;
          font-weight: 700;
          margin-bottom: 6px;
        }

        .cvant-order-desc {
          color: var(--cvant-order-muted);
          font-size: 14px;
          margin-bottom: 18px;
        }

        .cvant-order-form {
          display: grid;
          gap: 16px;
        }

        .cvant-order-field label {
          display: block;
          font-weight: 600;
          margin-bottom: 6px;
        }

        .cvant-order-input,
        .cvant-order-select,
        .cvant-order-textarea {
          width: 100%;
          border-radius: 12px;
          border: 1px solid var(--cvant-order-border-strong);
          background: var(--cvant-order-input-bg);
          color: var(--cvant-order-text);
          padding: 10px 12px;
        }

        .cvant-order-input::placeholder,
        .cvant-order-textarea::placeholder {
          color: var(--cvant-order-muted);
        }

        .cvant-order-row {
          display: grid;
          grid-template-columns: repeat(2, minmax(0, 1fr));
          gap: 14px;
        }

        .cvant-order-summary h4 {
          font-size: 18px;
          margin-bottom: 10px;
        }

        .cvant-order-summary-item {
          display: flex;
          align-items: center;
          justify-content: space-between;
          padding: 10px 0;
          border-bottom: 1px dashed var(--cvant-order-border);
          color: var(--cvant-order-muted);
        }

        .cvant-order-summary-item strong {
          color: var(--cvant-order-text);
        }

        .cvant-order-summary-item:last-child {
          border-bottom: none;
        }

        .cvant-order-total {
          font-size: 20px;
          font-weight: 700;
          margin-top: 12px;
        }

        .cvant-order-submit {
          border-radius: 999px;
          padding: 12px 16px;
          border: 1px solid var(--primary-600);
          background: var(--primary-600);
          color: #ffffff;
          font-weight: 600;
          width: 100%;
        }

        .cvant-order-submit:hover {
          background: var(--primary-700);
          border-color: var(--primary-700);
          color: #ffffff;
        }

        .cvant-order-submit:active,
        .cvant-order-submit:focus {
          background: var(--primary-800);
          border-color: var(--primary-800);
        }

        .cvant-order-alert {
          padding: 10px 14px;
          border-radius: 12px;
          font-size: 14px;
        }

        .cvant-order-alert.error {
          background: var(--cvant-order-danger-bg);
          border: 1px solid var(--cvant-order-danger-border);
          color: var(--cvant-order-danger-text);
        }

        @media (max-width: 991px) {
          .cvant-order-grid {
            grid-template-columns: 1fr;
          }

          .cvant-order-row {
            grid-template-columns: 1fr;
          }
        }
      `}</style>

      <div className="cvant-order">
        <header className="cvant-order-nav">
          <div className="cvant-order-container cvant-order-nav-inner">
            <Link href="/" className="d-inline-flex align-items-center gap-2">
              <img src="/assets/images/logo.webp" alt="CV ANT" style={{ height: "34px" }} />
            </Link>
            <div className="cvant-order-actions">
              <ThemeToggleButton />
              {customer ? (
                <div className="cvant-order-user">
                  <span className="cvant-order-avatar">{customerInitial}</span>
                  <div>
                    <div className="cvant-order-user-name">
                      {customer.name || "Customer"}
                    </div>
                    <div className="cvant-order-user-role">{customerRole}</div>
                  </div>
                </div>
              ) : null}
              <span className="cvant-order-pill">Customer Order</span>
              <button type="button" className="cvant-order-logout" onClick={handleSignOut}>
                Keluar
              </button>
            </div>
          </div>
        </header>

        <main className="cvant-order-main">
          <div className="cvant-order-container cvant-order-grid">
            <section className="cvant-order-card">
              <h2 className="cvant-order-title">Form Order Pengiriman</h2>
              <p className="cvant-order-desc">
                Lengkapi detail berikut untuk mendapatkan estimasi biaya dan lanjut ke pembayaran.
              </p>

              {message && (
                <div className={`cvant-order-alert ${message.type}`}>{message.text}</div>
              )}

              <form onSubmit={handleSubmit} className="cvant-order-form">
                <div className="cvant-order-row">
                  <div className="cvant-order-field">
                    <label>Nama</label>
                    <input
                      type="text"
                      className="cvant-order-input"
                      value={form.name}
                      onChange={onChange("name")}
                      placeholder="Nama pemesan"
                      required
                    />
                  </div>
                  <div className="cvant-order-field">
                    <label>Email</label>
                    <input
                      type="email"
                      className="cvant-order-input"
                      value={form.email}
                      onChange={onChange("email")}
                      placeholder="nama@email.com"
                      required
                    />
                  </div>
                </div>

                <div className="cvant-order-row">
                  <div className="cvant-order-field">
                    <label>Nomor HP</label>
                    <input
                      type="tel"
                      className="cvant-order-input"
                      value={form.phone}
                      onChange={onChange("phone")}
                      placeholder="08xxxxxxxxxx"
                      required
                    />
                  </div>
                  <div className="cvant-order-field">
                    <label>Perusahaan (opsional)</label>
                    <input
                      type="text"
                      className="cvant-order-input"
                      value={form.company}
                      onChange={onChange("company")}
                      placeholder="Nama perusahaan"
                    />
                  </div>
                </div>

                <div className="cvant-order-row">
                  <div className="cvant-order-field">
                    <label>Pickup</label>
                    <input
                      type="text"
                      className="cvant-order-input"
                      value={form.pickup}
                      onChange={onChange("pickup")}
                      placeholder="Kota asal"
                      required
                    />
                  </div>
                  <div className="cvant-order-field">
                    <label>Destination</label>
                    <input
                      type="text"
                      className="cvant-order-input"
                      value={form.destination}
                      onChange={onChange("destination")}
                      placeholder="Kota tujuan"
                      required
                    />
                  </div>
                </div>

                <div className="cvant-order-row">
                  <div className="cvant-order-field">
                    <label>Tanggal Pickup</label>
                    <input
                      type="date"
                      className="cvant-order-input"
                      value={form.date}
                      onChange={onChange("date")}
                      required
                    />
                  </div>
                  <div className="cvant-order-field">
                    <label>Jam Pickup</label>
                    <input
                      type="time"
                      className="cvant-order-input"
                      value={form.time}
                      onChange={onChange("time")}
                      required
                    />
                  </div>
                </div>

                <div className="cvant-order-row">
                  <div className="cvant-order-field">
                    <label>Service</label>
                    <select
                      className="cvant-order-select"
                      value={form.service}
                      onChange={onChange("service")}
                    >
                      <option value="regular">Regular</option>
                      <option value="express">Express</option>
                      <option value="charter">Charter</option>
                    </select>
                  </div>
                  <div className="cvant-order-field">
                    <label>Armada</label>
                    <select
                      className="cvant-order-select"
                      value={form.fleet}
                      onChange={onChange("fleet")}
                    >
                      <option value="cdd">CDD Long</option>
                      <option value="fuso">Fuso Box</option>
                      <option value="trailer">Trailer</option>
                    </select>
                  </div>
                </div>

                <div className="cvant-order-row">
                  <div className="cvant-order-field">
                    <label>Jenis Barang</label>
                    <input
                      type="text"
                      className="cvant-order-input"
                      value={form.cargo}
                      onChange={onChange("cargo")}
                      placeholder="Contoh: material, makanan"
                    />
                  </div>
                  <div className="cvant-order-field">
                    <label>Berat (ton)</label>
                    <input
                      type="number"
                      className="cvant-order-input"
                      value={form.weight}
                      onChange={onChange("weight")}
                      placeholder="Contoh: 4"
                      min="0"
                    />
                  </div>
                </div>

                <div className="cvant-order-row">
                  <div className="cvant-order-field">
                    <label>Jarak (km)</label>
                    <input
                      type="number"
                      className="cvant-order-input"
                      value={form.distance}
                      onChange={onChange("distance")}
                      placeholder="Contoh: 700"
                      min="0"
                    />
                  </div>
                  <div className="cvant-order-field">
                    <label>Catatan</label>
                    <input
                      type="text"
                      className="cvant-order-input"
                      value={form.notes}
                      onChange={onChange("notes")}
                      placeholder="Catatan tambahan"
                    />
                  </div>
                </div>

                <div className="d-flex align-items-center gap-2">
                  <input
                    type="checkbox"
                    id="insurance"
                    checked={form.insurance}
                    onChange={onChange("insurance")}
                  />
                  <label htmlFor="insurance">Tambah asuransi barang (2%)</label>
                </div>

                <button type="submit" className="cvant-order-submit">
                  Lanjutkan Pembayaran
                </button>
              </form>
            </section>

            <aside className="cvant-order-card cvant-order-summary">
              <h4>Ringkasan Estimasi</h4>
              <div className="cvant-order-summary-item">
                <span>Service</span>
                <strong>{form.service}</strong>
              </div>
              <div className="cvant-order-summary-item">
                <span>Armada</span>
                <strong>{form.fleet}</strong>
              </div>
              <div className="cvant-order-summary-item">
                <span>Rute</span>
                <strong>
                  {form.pickup || "-"} - {form.destination || "-"}
                </strong>
              </div>
              <div className="cvant-order-summary-item">
                <span>Estimasi dasar</span>
                <strong>{formatCurrency(pricing.estimate)}</strong>
              </div>
              <div className="cvant-order-summary-item">
                <span>Asuransi</span>
                <strong>{formatCurrency(pricing.insuranceFee)}</strong>
              </div>
              <div className="cvant-order-total">
                Total: {formatCurrency(pricing.total)}
              </div>
              <p className="cvant-order-desc mt-16">
                Estimasi dihitung berdasarkan jarak, berat, dan service. Final
                akan dikonfirmasi oleh tim operasional.
              </p>
            </aside>
          </div>
        </main>
      </div>

      <PublicChatbotWidget />
    </>
  );
};

export default CustomerOrderLayer;
