"use client";

import { useEffect, useState } from "react";
import { Icon } from "@iconify/react/dist/iconify.js";
import { api } from "@/lib/api";

const isLightModeNow = () => {
  if (typeof window === "undefined") return false;

  const html = document.documentElement;
  const body = document.body;

  const bs =
    (html.getAttribute("data-bs-theme") ||
      body?.getAttribute("data-bs-theme") ||
      "").toLowerCase();
  if (bs === "light") return true;
  if (bs === "dark") return false;

  const dt =
    (html.getAttribute("data-theme") ||
      body?.getAttribute("data-theme") ||
      "").toLowerCase();
  if (dt === "light") return true;
  if (dt === "dark") return false;

  const cls = `${html.className || ""} ${body?.className || ""}`.toLowerCase();
  if (cls.includes("light") || cls.includes("theme-light")) return true;
  if (cls.includes("dark") || cls.includes("theme-dark")) return false;

  return false;
};

const CustomerRegistrationsLayer = () => {
  const [customers, setCustomers] = useState([]);
  const [isLightMode, setIsLightMode] = useState(false);

  const loadCustomers = async () => {
    try {
      const data = await api.get("/customer-registrations");
      setCustomers(Array.isArray(data) ? data : []);
    } catch {
      setCustomers([]);
    }
  };

  useEffect(() => {
    loadCustomers();
  }, []);

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

  const formatDate = (value) => {
    if (!value) return "-";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return value;
    return date.toLocaleDateString("id-ID");
  };

  const formatDateTime = (value) => {
    if (!value) return "-";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return value;
    const datePart = date.toLocaleDateString("id-ID");
    const hours = String(date.getHours()).padStart(2, "0");
    const minutes = String(date.getMinutes()).padStart(2, "0");
    return `${datePart}, ${hours}:${minutes}`;
  };

  const cardBg = isLightMode ? "#ffffff" : "#1b2431";
  const cardBorder = isLightMode ? "rgba(148,163,184,0.35)" : "#273142";
  const textMain = isLightMode ? "#0b1220" : "#ffffff";
  const textSub = isLightMode ? "#64748b" : "#94a3b8";

  const renderMobileCards = () => (
    <div className="d-md-none p-3 d-flex flex-column gap-12">
      {customers.map((customer, index) => (
        <div
          key={customer.id || index}
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
                  fontWeight: 700,
                  fontSize: "14px",
                  color: textMain,
                }}
              >
                {customer.name || "-"}
              </div>
              <div style={{ fontSize: "13px", color: textSub }}>
                {customer.email || "-"}
              </div>
            </div>

            <span
              className="badge bg-primary"
              style={{ fontSize: "12px", whiteSpace: "nowrap" }}
            >
              #{index + 1}
            </span>
          </div>

          <div
            className="mt-10 d-flex flex-column gap-6"
            style={{ fontSize: "13px" }}
          >
            <div className="d-flex justify-content-between">
              <span style={{ color: textSub }}>HP</span>
              <span style={{ color: textMain, fontWeight: 600 }}>
                {customer.phone || "-"}
              </span>
            </div>
            <div className="d-flex justify-content-between">
              <span style={{ color: textSub }}>Tgl Lahir</span>
              <span style={{ color: textMain, fontWeight: 600 }}>
                {formatDate(customer.birth_date)}
              </span>
            </div>
            <div>
              <div style={{ color: textSub }}>Alamat</div>
              <div
                style={{
                  color: textMain,
                  fontWeight: 600,
                  wordBreak: "break-word",
                }}
              >
                {customer.address || "-"}
              </div>
            </div>
            <div className="d-flex justify-content-between">
              <span style={{ color: textSub }}>Kota</span>
              <span style={{ color: textMain, fontWeight: 600 }}>
                {customer.city || "-"}
              </span>
            </div>
            <div className="d-flex justify-content-between">
              <span style={{ color: textSub }}>Perusahaan</span>
              <span style={{ color: textMain, fontWeight: 600 }}>
                {customer.company || "-"}
              </span>
            </div>
            <div className="d-flex justify-content-between">
              <span style={{ color: textSub }}>Terdaftar</span>
              <span style={{ color: textMain, fontWeight: 600 }}>
                {formatDateTime(customer.created_at)}
              </span>
            </div>
          </div>
        </div>
      ))}
    </div>
  );

  return (
    <div className="row">
      <div className="col-12">
        <div className="card h-100">
          <div className="card-body p-24">
            <div className="d-flex align-items-center justify-content-between flex-wrap gap-3 mb-20">
              <div>
                <h6 className="mb-4 fw-bold">Pendaftaran Customer</h6>
                <p className="text-secondary-light mb-0">
                  Data biodata customer yang sudah mendaftar.
                </p>
              </div>
              <button
                className="btn btn-primary radius-8 d-inline-flex align-items-center w-100 w-md-auto"
                onClick={loadCustomers}
              >
                <Icon
                  icon="solar:refresh-linear"
                  className="me-6"
                  style={{
                    display: "inline-flex",
                    alignItems: "center",
                    lineHeight: 1,
                    transform: "translateY(1px)",
                  }}
                />
                Refresh
              </button>
            </div>
          </div>

          <div className="card-body p-0">
            {customers.length === 0 ? (
              <div className="text-center py-40" style={{ color: textSub }}>
                <Icon icon="solar:inbox-linear" className="text-2xl" />
                <p className="mt-12 mb-0">Belum ada customer yang mendaftar.</p>
              </div>
            ) : (
              <>
                {renderMobileCards()}

                <div className="d-none d-md-block card-body table-responsive scroll-sm d-flex">
                  <table className="table bordered-table align-middle text-center mb-0">
                    <thead>
                      <tr>
                        <th>No</th>
                        <th>Nama</th>
                        <th>Email</th>
                        <th>HP</th>
                        <th>Tgl Lahir</th>
                        <th>Alamat</th>
                        <th>Kota</th>
                        <th>Perusahaan</th>
                        <th>Terdaftar</th>
                      </tr>
                    </thead>
                    <tbody>
                      {customers.map((customer, index) => (
                        <tr key={customer.id || index}>
                          <td>{index + 1}</td>
                          <td>{customer.name || "-"}</td>
                          <td>{customer.email || "-"}</td>
                          <td>{customer.phone || "-"}</td>
                          <td>{formatDate(customer.birth_date)}</td>
                          <td>{customer.address || "-"}</td>
                          <td>{customer.city || "-"}</td>
                          <td>{customer.company || "-"}</td>
                          <td>{formatDateTime(customer.created_at)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default CustomerRegistrationsLayer;
