"use client";

import { useEffect, useState } from "react";
import { Icon } from "@iconify/react/dist/iconify.js";
import Link from "next/link";
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
  const [popup, setPopup] = useState({
    show: false,
    type: "success",
    title: "",
    message: "",
  });
  const notifyOrdersUpdated = () => {
    if (typeof window === "undefined") return;
    window.dispatchEvent(new Event("cvant:order-acceptance-updated"));
  };

  const showPopup = (type, title, message) => {
    setPopup({ show: true, type, title, message });
  };

  const closePopup = () => {
    setPopup((prev) => ({ ...prev, show: false }));
  };

  const loadOrders = async () => {
    try {
      const data = await api.get("/customer-orders");
      setOrders(Array.isArray(data) ? data : []);
      notifyOrdersUpdated();
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

  const updateStatus = async (order, status) => {
    if (!order?.id) return;
    try {
      const updated = await api.patch(`/customer-orders/${order.id}/status`, {
        status,
      });
      setOrders((prev) =>
        prev.map((item) => (item.id === order.id ? { ...item, ...updated } : item))
      );
      notifyOrdersUpdated();
      const code = order.order_code || order.id;
      const actionLabel = String(status).toLowerCase().includes("accept")
        ? "diterima"
        : "ditolak";
      showPopup(
        "success",
        "Status diperbarui",
        `Order ${code} berhasil ${actionLabel}.`
      );
    } catch (error) {
      showPopup(
        "error",
        "Gagal memperbarui status",
        error?.message || "Gagal memperbarui status order."
      );
    }
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

  const isLongRoute = (value) => String(value || "").length > 32;
  const resolvePopupTheme = (type) => {
    const normalized = String(type || "").toLowerCase();
    if (normalized.includes("success")) {
      return {
        accent: "var(--success-600, #16a34a)",
        icon: "solar:check-circle-linear",
        buttonClass: "btn-success",
      };
    }
    if (normalized.includes("error") || normalized.includes("danger")) {
      return {
        accent: "var(--danger-600, #dc2626)",
        icon: "solar:danger-triangle-linear",
        buttonClass: "btn-danger",
      };
    }
    return {
      accent: "var(--primary-600, #487fff)",
      icon: "solar:info-circle-linear",
      buttonClass: "btn-primary",
    };
  };

  const buildInvoiceHref = (order) => {
    const params = new URLSearchParams();
    if (order?.id) params.set("orderId", String(order.id));
    if (order?.customer?.name) params.set("customerName", order.customer.name);
    if (order?.customer?.email) params.set("customerEmail", order.customer.email);
    if (order?.customer?.phone) params.set("customerPhone", order.customer.phone);
    if (order?.fleet) params.set("armadaName", order.fleet);
    if (order?.pickup) params.set("pickup", order.pickup);
    if (order?.destination) params.set("destination", order.destination);
    if (order?.pickup_date) params.set("pickupDate", String(order.pickup_date));

    const query = params.toString();
    return query ? `/invoice-add?${query}` : "/invoice-add";
  };

  const cardBg = isLightMode ? "#ffffff" : "#1b2431";
  const cardBorder = isLightMode ? "rgba(148,163,184,0.35)" : "#273142";
  const textMain = isLightMode ? "#0b1220" : "#ffffff";
  const textSub = isLightMode ? "#64748b" : "#94a3b8";

  const renderMobileCards = () => (
    <div className="d-md-none p-3 d-flex flex-column gap-12">
      {orders.map((order) => {
        const schedule = formatScheduleDate(order.pickup_date);
        const routeLabel = `${order.pickup || "-"} - ${order.destination || "-"}`;
        const routeClassName = isLongRoute(routeLabel)
          ? "cvant-route-text cvant-route-text-long"
          : "cvant-route-text";
        const normalizedStatus = String(order.status || "").toLowerCase();
        const isPaid =
          normalizedStatus.includes("paid") && !normalizedStatus.includes("unpaid");
        const canCreateInvoice = String(order.status || "")
          .toLowerCase()
          .includes("accepted");
        const createHref = buildInvoiceHref(order);

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
                {isLongRoute(routeLabel) ? (
                  <span
                    className={routeClassName}
                    style={{ color: textMain, fontWeight: 600 }}
                  >
                    <span className="cvant-route-line">
                      {order.pickup || "-"} -
                    </span>
                    <span className="cvant-route-line">
                      {order.destination || "-"}
                    </span>
                  </span>
                ) : (
                  <span
                    className={routeClassName}
                    style={{ color: textMain, fontWeight: 600 }}
                  >
                    {routeLabel}
                  </span>
                )}
              </div>
              <div className="d-flex justify-content-between">
                <span style={{ color: textSub }}>Jadwal</span>
                <span style={{ color: textMain, fontWeight: 600 }}>{schedule}</span>
              </div>
            </div>

            <div className="cvant-order-actions mt-12">
              <div className="cvant-order-actions-left">
                <button
                  className="btn btn-success btn-sm radius-8"
                  onClick={() => updateStatus(order, "Accepted")}
                  disabled={isPaid}
                >
                  Accept
                </button>
                <button
                  className="btn btn-danger btn-sm radius-8"
                  onClick={() => updateStatus(order, "Rejected")}
                  disabled={isPaid}
                >
                  Reject
                </button>
              </div>
              <div className="cvant-order-actions-right">
                {canCreateInvoice ? (
                  <Link
                    href={createHref}
                    className="btn btn-primary btn-sm radius-8"
                  >
                    Create
                  </Link>
                ) : (
                  <button
                    type="button"
                    className="btn btn-outline-secondary btn-sm radius-8"
                    disabled
                  >
                    Create
                  </button>
                )}
              </div>
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
                        <th>Status</th>
                        <th>Action</th>
                        <th>Create</th>
                      </tr>
                    </thead>
                    <tbody>
                      {orders.map((order) => {
                        const routeLabel = `${order.pickup || "-"} - ${
                          order.destination || "-"
                        }`;
                        const routeClassName = isLongRoute(routeLabel)
                          ? "cvant-route-text cvant-route-text-long"
                          : "cvant-route-text";
                        const normalizedStatus = String(order.status || "").toLowerCase();
                        const isPaid =
                          normalizedStatus.includes("paid") &&
                          !normalizedStatus.includes("unpaid");
                        const canCreateInvoice = String(order.status || "")
                          .toLowerCase()
                          .includes("accepted");
                        const createHref = buildInvoiceHref(order);
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
                              {isLongRoute(routeLabel) ? (
                                <span className={routeClassName}>
                                  <span className="cvant-route-line">
                                    {order.pickup || "-"} -
                                  </span>
                                  <span className="cvant-route-line">
                                    {order.destination || "-"}
                                  </span>
                                </span>
                              ) : (
                                <span className={routeClassName}>{routeLabel}</span>
                              )}
                            </td>
                            <td>
                              {formatScheduleDate(order.pickup_date)}
                            </td>
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
                                  onClick={() => updateStatus(order, "Accepted")}
                                  disabled={isPaid}
                                >
                                  Accept
                                </button>
                                <button
                                  className="btn btn-danger btn-sm radius-8"
                                  onClick={() => updateStatus(order, "Rejected")}
                                  disabled={isPaid}
                                >
                                  Reject
                                </button>
                              </div>
                            </td>
                            <td>
                                {canCreateInvoice ? (
                                  <Link href={createHref} className="btn btn-primary btn-sm radius-8">
                                    Create
                                  </Link>
                                ) : (
                                <button
                                  type="button"
                                  className="btn btn-outline-secondary btn-sm radius-8"
                                  disabled
                                >
                                  Create
                                </button>
                              )}
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
              maxWidth: "520px",
              backgroundColor: "#1b2431",
              border: `2px solid ${resolvePopupTheme(popup.type).accent}`,
              boxShadow: "0 22px 55px rgba(0,0,0,0.55)",
            }}
            onClick={(event) => event.stopPropagation()}
          >
            <div className="d-flex align-items-start justify-content-between gap-2">
              <div className="d-flex align-items-start gap-12">
                <span style={{ marginTop: "2px" }}>
                  <Icon
                    icon={resolvePopupTheme(popup.type).icon}
                    style={{
                      fontSize: "28px",
                      color: resolvePopupTheme(popup.type).accent,
                    }}
                  />
                </span>

                <div>
                  <h5 className="mb-8 fw-bold" style={{ color: "#ffffff" }}>
                    {popup.title || "Informasi"}
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
                className={`btn ${resolvePopupTheme(popup.type).buttonClass} radius-12 px-16`}
                onClick={closePopup}
                style={{
                  border: `2px solid ${resolvePopupTheme(popup.type).accent}`,
                }}
              >
                OK
              </button>
            </div>
          </div>
        </div>
      )}
      <style jsx global>{`
        .cvant-route-text {
          display: inline-block;
          max-width: 100%;
          line-height: 1.3;
          word-break: break-word;
        }

        .cvant-route-text-long {
          font-size: clamp(10px, 0.8vw + 7px, 12px);
        }

        .cvant-route-line {
          display: block;
        }

        @media (max-width: 767.98px) {
          .cvant-route-text-long {
            font-size: clamp(10px, 3vw, 11.5px);
          }

          .cvant-order-actions {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 10px;
            flex-wrap: nowrap;
          }

          .cvant-order-actions-left {
            display: flex;
            gap: 8px;
            flex-wrap: nowrap;
          }

          .cvant-order-actions-right {
            margin-left: auto;
          }
        }

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
