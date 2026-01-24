"use client";

import { useEffect, useState } from "react";
import { Icon } from "@iconify/react/dist/iconify.js";
import { customerApi } from "@/lib/customerApi";

const formatCurrency = (value) => {
  const parsed = Number(value);
  const safeValue = Number.isFinite(parsed) ? parsed : 0;
  return `Rp ${safeValue.toLocaleString("id-ID")}`;
};

const formatScheduleDate = (value) => {
  if (!value) return "-";
  const raw = String(value);
  const match = raw.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (match) {
    return `${match[3]}-${match[2]}-${match[1]}`;
  }
  const parsed = new Date(raw);
  if (Number.isNaN(parsed.getTime())) return raw;
  const day = String(parsed.getDate()).padStart(2, "0");
  const month = String(parsed.getMonth() + 1).padStart(2, "0");
  const year = String(parsed.getFullYear());
  return `${day}-${month}-${year}`;
};

const statusBadge = (status) => {
  if (status === "Accepted") return "bg-success-focus text-success-main";
  if (status === "Rejected") return "bg-danger-focus text-danger-main";
  if (status === "Paid") return "bg-info-focus text-info-main";
  return "bg-warning-focus text-warning-main";
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

const CustomerOrdersLayer = () => {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const loadOrders = async () => {
    setLoading(true);
    setError("");
    try {
      const data = await customerApi.get("/customer/orders");
      setOrders(Array.isArray(data) ? data : []);
    } catch (err) {
      setError(err?.message || "Failed to load order history.");
      setOrders([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadOrders();
  }, []);

  const renderMobileCards = () => (
    <div className="d-md-none p-3 d-flex flex-column gap-12">
      {orders.map((order) => {
        const scheduleDate = formatScheduleDate(order.pickup_date || order.date);
        const schedule = scheduleDate;
        const statusLabel = String(order.status || "").toLowerCase();
        const canPay =
          statusLabel.includes("accepted") && !statusLabel.includes("paid");
        const isPaid = statusLabel.includes("paid");

        return (
          <div key={order.id} className="cvant-mobile-card">
            <div className="d-flex justify-content-between align-items-start gap-2">
              <div>
                <div className="fw-semibold">
                  {order.order_code || `ORD-${order.id}`}
                </div>
              </div>
              <span
                className={`${statusBadge(
                  order.status
                )} px-12 py-4 rounded-pill fw-medium text-sm`}
              >
                {formatStatusLabel(order.status)}
              </span>
            </div>

            <div className="mt-10 d-flex flex-column gap-6">
              <div className="cvant-mobile-card-row">
                <span className="cvant-mobile-card-label">Rute</span>
                <span className="cvant-mobile-card-value">
                  {order.pickup || "-"} - {order.destination || "-"}
                </span>
              </div>
              <div className="cvant-mobile-card-row">
                <span className="cvant-mobile-card-label">Jadwal</span>
                <span className="cvant-mobile-card-value">{schedule}</span>
              </div>
              <div className="cvant-mobile-card-row">
                <span className="cvant-mobile-card-label">Armada</span>
                <span className="cvant-mobile-card-value">
                  {order.fleet || "-"}
                </span>
              </div>
              <div className="cvant-mobile-card-row">
                <span className="cvant-mobile-card-label">Total</span>
                <span className="cvant-mobile-card-value">
                  {formatCurrency(order.total)}
                </span>
              </div>
              <div className="cvant-mobile-card-row">
                <span className="cvant-mobile-card-label">Payment</span>
                {canPay ? (
                  <a
                    className="btn btn-sm btn-primary"
                    href={`/order/payment?id=${order.id}`}
                  >
                    Pay
                  </a>
                ) : (
                  <button
                    type="button"
                    className="btn btn-sm btn-outline-secondary"
                    disabled
                  >
                    {isPaid ? "Paid" : "Waiting"}
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
              <h6 className="mb-0 fw-bold cvant-data-title">Order History</h6>
            </div>
            <button
              className="btn btn-sm btn-primary radius-8 d-inline-flex align-items-center cvant-refresh-btn"
              onClick={loadOrders}
              disabled={loading}
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
            {loading ? (
              <div className="text-center py-40">Loading data...</div>
            ) : error ? (
              <div className="text-center py-40 text-danger">{error}</div>
            ) : orders.length === 0 ? (
              <div className="text-center py-40">
                <Icon icon="solar:inbox-linear" className="text-2xl" />
                <p className="mt-12 mb-0">No orders yet.</p>
              </div>
            ) : (
              <>
                {renderMobileCards()}

                <div className="d-none d-md-block card-body table-responsive scroll-sm d-flex">
                  <table className="table bordered-table text-center align-middle mb-0">
                    <thead>
                      <tr>
                        <th>Order ID</th>
                        <th>Route</th>
                        <th>Schedule</th>
                      <th>Fleet</th>
                      <th>Total</th>
                      <th>Status</th>
                      <th>Payment</th>
                    </tr>
                  </thead>
                  <tbody>
                    {orders.map((order) => {
                      const statusLabel = String(order.status || "").toLowerCase();
                      const canPay =
                        statusLabel.includes("accepted") &&
                        !statusLabel.includes("paid");
                      const isPaid = statusLabel.includes("paid");

                      return (
                        <tr key={order.id}>
                          <td>{order.order_code || `ORD-${order.id}`}</td>
                          <td>
                            {order.pickup} - {order.destination}
                          </td>
                          <td>
                            {formatScheduleDate(order.pickup_date || order.date)}
                          </td>
                          <td>{order.fleet}</td>
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
                            {canPay ? (
                              <a
                                className="btn btn-sm btn-primary"
                                href={`/order/payment?id=${order.id}`}
                              >
                                Pay
                              </a>
                            ) : (
                              <button
                                type="button"
                                className="btn btn-sm btn-outline-secondary"
                                disabled
                              >
                                {isPaid ? "Paid" : "Waiting"}
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

export default CustomerOrdersLayer;
