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

  const formatDateTime = (value) => {
    if (!value) return "-";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return value;
    const day = String(date.getDate()).padStart(2, "0");
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const year = date.getFullYear();
    const datePart = `${day}-${month}-${year}`;
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
            <div className="d-flex justify-content-between align-items-start">
              <span style={{ color: textSub, flex: "0 0 auto" }}>Alamat</span>
              <span
                style={{
                  color: textMain,
                  fontWeight: 600,
                  textAlign: "right",
                  marginLeft: "12px",
                  minWidth: 0,
                  flex: "1 1 auto",
                  wordBreak: "break-word",
                }}
              >
                {customer.address || "-"}
              </span>
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
          <div className="card-header d-flex flex-wrap align-items-center justify-content-between gap-3 cvant-data-header">
            <div className="d-flex flex-column justify-content-center">
              <h6 className="mb-0 fw-bold cvant-data-title">Data Customer</h6>
            </div>
            <button
              className="btn btn-sm btn-primary radius-8 d-inline-flex align-items-center cvant-refresh-btn"
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
      <style jsx global>{`
        @media (max-width: 767.98px) {
          .cvant-data-header {
            flex-wrap: nowrap !important;
            align-items: center !important;
            gap: 8px !important;
          }

          .cvant-data-header > div {
            min-width: 0 !important;
          }

          .cvant-data-title {
            line-height: 1.2 !important;
          }

          .cvant-refresh-btn {
            padding: 4px 10px !important;
            height: 32px !important;
            font-size: 12px !important;
          }
        }
      `}</style>
    </div>
  );
};

export default CustomerRegistrationsLayer;
