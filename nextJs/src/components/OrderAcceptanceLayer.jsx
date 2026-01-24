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

const OrderAcceptanceLayer = () => {
  const [orders, setOrders] = useState([]);
  const [isLightMode, setIsLightMode] = useState(false);

  const loadOrders = async () => {
    try {
      const data = await api.get("/customer-orders");
      setOrders(Array.isArray(data) ? data : []);
    } catch {
      setOrders([]);
    }
  };

  useEffect(() => {
    loadOrders();
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

  const updateStatus = async (orderId, status) => {
    try {
      const updated = await api.patch(`/customer-orders/${orderId}/status`, { status });
      setOrders((prev) =>
        prev.map((order) => (order.id === orderId ? { ...order, ...updated } : order))
      );
    } catch {
      // ignore for now
    }
  };

  const formatCurrency = (value) => {
    const parsed = Number(value);
    const safeValue = Number.isFinite(parsed) ? parsed : 0;
    return `Rp ${safeValue.toLocaleString("id-ID")}`;
  };

  const formatScheduleDate = (value) => {
    if (!value) return "-";
    const raw = String(value);
    const match = raw.match(/^(\d{4})-(\d{2})-(\d{2})/);
    if (match) return `${match[3]}-${match[2]}-${match[1]}`;
    const parsed = new Date(raw);
    if (Number.isNaN(parsed.getTime())) return raw;
    const day = String(parsed.getDate()).padStart(2, "0");
    const month = String(parsed.getMonth() + 1).padStart(2, "0");
    const year = String(parsed.getFullYear());
    return `${day}-${month}-${year}`;
  };

  const formatStatusLabel = (status) => {
    if (!status) return "Pending";
    const normalized = String(status).toLowerCase();
    if (normalized.includes("pending")) return "Pending";
    if (normalized.includes("accepted")) return "Accepted";
    if (normalized.includes("rejected")) return "Rejected";
    if (normalized.includes("paid")) return "Paid";
    return status;
  };

  const statusBadge = (status) => {
    const label = String(status || "").toLowerCase();
    if (label.includes("accepted")) return "bg-success-focus text-success-main";
    if (label.includes("rejected")) return "bg-danger-focus text-danger-main";
    if (label.includes("paid")) return "bg-info-focus text-info-main";
    return "bg-warning-focus text-warning-main";
  };

  const cardBg = isLightMode ? "#ffffff" : "#1b2431";
  const cardBorder = isLightMode ? "rgba(148,163,184,0.35)" : "#273142";
  const textMain = isLightMode ? "#0b1220" : "#ffffff";
  const textSub = isLightMode ? "#64748b" : "#94a3b8";

  const renderMobileCards = () => (
    <div className="d-md-none p-3 d-flex flex-column gap-12">
      {orders.map((order) => {
        const schedule = formatScheduleDate(order.pickup_date);
        const isFinal = ["Accepted", "Rejected"].includes(order.status);

        return (
          <div
            key={order.id}
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
                  {order.order_code || order.id}
                </div>
                <div style={{ fontSize: "13px", color: textSub }}>
                  {order.customer?.name || "-"}
                </div>
                <div style={{ fontSize: "12px", color: textSub }}>
                  {order.customer?.email || "-"}
                </div>
              </div>

              <span
                className={`${statusBadge(
                  order.status
                )} px-12 py-4 rounded-pill fw-medium`}
                style={{ fontSize: "12px", whiteSpace: "nowrap" }}
              >
                {formatStatusLabel(order.status)}
              </span>
            </div>

            <div
              className="mt-10 d-flex flex-column gap-6"
              style={{ fontSize: "13px" }}
            >
              <div className="d-flex justify-content-between">
                <span style={{ color: textSub }}>Rute</span>
                <span style={{ color: textMain, fontWeight: 600 }}>
                  {order.pickup || "-"} - {order.destination || "-"}
                </span>
              </div>
              <div className="d-flex justify-content-between">
                <span style={{ color: textSub }}>Jadwal</span>
                <span style={{ color: textMain, fontWeight: 600 }}>{schedule}</span>
              </div>
              <div className="d-flex justify-content-between">
                <span style={{ color: textSub }}>Total</span>
                <span style={{ color: textMain, fontWeight: 700 }}>
                  {formatCurrency(order.total)}
                </span>
              </div>
            </div>

            <div className="d-flex justify-content-end gap-2 mt-12 flex-wrap">
              <button
                className="btn btn-success btn-sm radius-8"
                onClick={() => updateStatus(order.id, "Accepted")}
                disabled={isFinal}
              >
                Accept
              </button>
              <button
                className="btn btn-danger btn-sm radius-8"
                onClick={() => updateStatus(order.id, "Rejected")}
                disabled={isFinal}
              >
                Reject
              </button>
            </div>
          </div>
        );
      })}
    </div>
  );

  return (
    <div className="row">
      <div className="col-12">
        <div className="card h-100">
          <div className="card-header d-flex flex-wrap align-items-center justify-content-between gap-3 cvant-data-header">
            <div className="d-flex flex-column justify-content-center">
              <h6 className="mb-0 fw-bold">Customer Order</h6>
            </div>
            <button
              className="btn btn-sm btn-primary radius-8 d-inline-flex align-items-center cvant-refresh-btn"
              onClick={loadOrders}
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
            {orders.length === 0 ? (
              <div className="text-center py-40" style={{ color: textSub }}>
                <Icon icon="solar:inbox-linear" className="text-2xl" />
                <p className="mt-12 mb-0">Belum ada order customer yang masuk.</p>
              </div>
            ) : (
              <>
                {renderMobileCards()}

                <div className="d-none d-md-block card-body table-responsive scroll-sm d-flex">
                  <table className="table bordered-table text-center align-middle mb-0">
                    <thead>
                      <tr>
                        <th>ID Order</th>
                        <th>Customer</th>
                        <th>Rute</th>
                        <th>Jadwal</th>
                        <th>Total</th>
                        <th>Status</th>
                        <th>Action</th>
                      </tr>
                    </thead>
                    <tbody>
                      {orders.map((order) => {
                        const isFinal = ["Accepted", "Rejected"].includes(order.status);
                        return (
                          <tr key={order.id}>
                            <td>{order.order_code || order.id}</td>
                            <td>
                              <div className="d-flex flex-column">
                                <span className="fw-semibold">
                                  {order.customer?.name || "-"}
                                </span>
                                <span className="text-secondary-light text-sm">
                                  {order.customer?.email || "-"}
                                </span>
                              </div>
                            </td>
                            <td>
                              {order.pickup || "-"} - {order.destination || "-"}
                            </td>
                            <td>
                              {formatScheduleDate(order.pickup_date)}
                            </td>
                            <td>{formatCurrency(order.total)}</td>
                            <td>
                              <span
                                className={`${statusBadge(
                                  order.status
                                )} px-16 py-4 rounded-pill fw-medium text-sm`}
                              >
                                {formatStatusLabel(order.status)}
                              </span>
                            </td>
                            <td>
                              <div className="d-flex justify-content-center gap-2">
                                <button
                                  className="btn btn-success btn-sm radius-8"
                                  onClick={() => updateStatus(order.id, "Accepted")}
                                  disabled={isFinal}
                                >
                                  Accept
                                </button>
                                <button
                                  className="btn btn-danger btn-sm radius-8"
                                  onClick={() => updateStatus(order.id, "Rejected")}
                                  disabled={isFinal}
                                >
                                  Reject
                                </button>
                              </div>
                            </td>
                          </tr>
                        );
                      })}
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

export default OrderAcceptanceLayer;
