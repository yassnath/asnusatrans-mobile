"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { Icon } from "@iconify/react/dist/iconify.js";
import { customerApi } from "@/lib/customerApi";

const formatCurrency = (value) => {
  const parsed = Number(value);
  const safeValue = Number.isFinite(parsed) ? parsed : 0;
  return `Rp ${safeValue.toLocaleString("id-ID")}`;
};

const statusBadge = (status) => {
  const label = String(status || "").toLowerCase();
  if (label.includes("paid")) return "bg-success-focus text-success-main";
  if (label.includes("accepted")) return "bg-success-focus text-success-main";
  if (label.includes("rejected") || label.includes("cancel")) {
    return "bg-danger-focus text-danger-main";
  }
  if (label.includes("pending")) return "bg-warning-focus text-warning-main";
  return "bg-info-focus text-info-main";
};

const formatStatusLabel = (status) => {
  if (!status) return "Pending";
  const label = String(status).toLowerCase();
  if (label.includes("pending")) return "Pending";
  if (label.includes("accepted")) return "Accepted";
  if (label.includes("rejected")) return "Rejected";
  if (label.includes("paid")) return "Paid";
  return status;
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

const CustomerDashboardLayer = () => {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const loadOrders = async () => {
      try {
        const data = await customerApi.get("/customer/orders");
        setOrders(Array.isArray(data) ? data : []);
      } catch (err) {
        setError(err?.message || "Failed to load order data.");
        setOrders([]);
      } finally {
        setLoading(false);
      }
    };

    loadOrders();
  }, []);

  const stats = useMemo(() => {
    const total = orders.length;
    const pending = orders.filter((o) => o.status === "Pending Payment").length;
    const paid = orders.filter((o) => o.status === "Paid").length;
    const totalSpend = orders.reduce(
      (sum, order) => sum + (Number(order.total) || 0),
      0
    );
    return { total, pending, paid, totalSpend };
  }, [orders]);

  const recentOrders = useMemo(() => orders.slice(0, 5), [orders]);

  const renderMobileOrders = () => (
    <div className="d-md-none d-flex flex-column gap-12">
      {recentOrders.map((order) => {
        const scheduleDate = formatScheduleDate(order.pickup_date || order.date);
        const schedule = scheduleDate;

        return (
          <div key={order.id} className="cvant-order-card">
            <div className="d-flex justify-content-between align-items-start gap-2">
              <div>
                <div className="fw-semibold">
                  {order.order_code || `ORD-${order.id}`}
                </div>
                <div className="text-secondary-light text-sm">
                  {order.service || "Service not selected"}
                </div>
              </div>
              <span className={`cvant-status-badge ${statusBadge(order.status)}`}>
                {formatStatusLabel(order.status)}
              </span>
            </div>

            <div className="cvant-order-meta">
              <div className="d-flex justify-content-between gap-3">
                <span className="text-secondary-light">Route</span>
                <span className="cvant-order-value">
                  {order.pickup || "-"} - {order.destination || "-"}
                </span>
              </div>
              <div className="d-flex justify-content-between gap-3">
                <span className="text-secondary-light">Schedule</span>
                <span className="cvant-order-value">{schedule}</span>
              </div>
              <div className="d-flex justify-content-between gap-3">
                <span className="text-secondary-light">Total</span>
                <span className="cvant-order-value">
                  {formatCurrency(order.total)}
                </span>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );

  return (
    <div className="container-fluid py-4 cvant-customer-dashboard">
      <div className="d-flex justify-content-end mb-4 cvant-dashboard-header">
        <Link href="/order" className="btn btn-primary btn-sm">
          Buat Order
        </Link>
      </div>

      <div className="row row-cols-xxxl-3 row-cols-lg-3 row-cols-sm-2 row-cols-1 gy-4 cvant-stats-row">
        <div className="col">
          <div className="card shadow-none border bg-gradient-start-1 h-100">
            <div className="card-body p-20">
              <div className="d-flex justify-content-between align-items-center gap-3">
                <div>
                  <p className="fw-medium text-primary-light mb-1">
                    Total Orders
                  </p>
                  <h6 className="mb-0">{stats.total}</h6>
                </div>
                <div className="w-50-px h-50-px bg-cyan rounded-circle d-flex justify-content-center align-items-center">
                  <Icon
                    icon="solar:clipboard-check-linear"
                    className="text-white text-2xl"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
        <div className="col">
          <div className="card shadow-none border bg-gradient-start-4 h-100">
            <div className="card-body p-20">
              <div className="d-flex justify-content-between align-items-center gap-3">
                <div>
                  <p className="fw-medium text-primary-light mb-1">
                    Pending Payment
                  </p>
                  <h6 className="mb-0">{stats.pending}</h6>
                </div>
                <div className="w-50-px h-50-px bg-warning-600 rounded-circle d-flex justify-content-center align-items-center">
                  <Icon
                    icon="solar:hourglass-linear"
                    className="text-white text-2xl"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
        <div className="col">
          <div className="card shadow-none border bg-gradient-start-5 h-100">
            <div className="card-body p-20">
              <div className="d-flex justify-content-between align-items-center gap-3">
                <div>
                  <p className="fw-medium text-primary-light mb-1">
                    Total Spend
                  </p>
                  <h6 className="mb-0">{formatCurrency(stats.totalSpend)}</h6>
                </div>
                <div className="w-50-px h-50-px bg-success-main rounded-circle d-flex justify-content-center align-items-center">
                  <Icon
                    icon="solar:card-transfer-linear"
                    className="text-white text-2xl"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="row gy-4 mt-1 cvant-orders-row">
        <div className="col-12">
          <div className="card shadow-none border">
            <div className="card-body p-24">
              <div className="d-flex align-items-center flex-wrap gap-2 justify-content-between mb-20">
                <h6 className="mb-0 fw-bold text-lg">Latest Orders</h6>
                <Link
                  href="/customer/orders"
                  className="text-primary-600 hover-text-primary d-flex align-items-center gap-1"
                >
                  View All
                  <Icon icon="solar:alt-arrow-right-linear" className="icon" />
                </Link>
              </div>
              {loading ? (
                <div className="py-3">Loading data...</div>
              ) : error ? (
                <div className="py-3 text-danger">{error}</div>
              ) : orders.length === 0 ? (
                <div className="py-3">No orders yet.</div>
              ) : (
                <>
                  {renderMobileOrders()}

                  <div className="table-responsive scroll-sm d-none d-md-block">
                    <table className="table bordered-table text-center align-middle mb-0">
                      <thead>
                        <tr>
                          <th>Order ID</th>
                          <th>Route</th>
                          <th>Schedule</th>
                          <th>Service</th>
                          <th>Total</th>
                          <th>Status</th>
                        </tr>
                      </thead>
                      <tbody>
                        {recentOrders.map((order) => (
                          <tr key={order.id}>
                            <td>{order.order_code || `ORD-${order.id}`}</td>
                            <td>
                              {order.pickup || "-"} - {order.destination || "-"}
                            </td>
                            <td>
                              {formatScheduleDate(order.pickup_date || order.date)}
                            </td>
                            <td>{order.service || "-"}</td>
                            <td>{formatCurrency(order.total)}</td>
                            <td>
                              <span
                                className={`cvant-status-badge ${statusBadge(
                                  order.status
                                )}`}
                              >
                                {formatStatusLabel(order.status)}
                              </span>
                            </td>
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

      <style jsx global>{`
        .cvant-status-badge {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          padding: 4px 10px;
          border-radius: 999px;
          font-size: 11px;
          font-weight: 600;
          white-space: nowrap;
        }

        .cvant-order-card {
          border-radius: 12px;
          padding: 14px;
          border: 1px solid #273142;
          background: #1b2431;
          display: flex;
          flex-direction: column;
          gap: 10px;
        }

        html[data-bs-theme="light"] .cvant-order-card,
        html[data-theme="light"] .cvant-order-card {
          border-color: rgba(148, 163, 184, 0.35);
          background: #ffffff;
        }

        .cvant-order-meta {
          display: flex;
          flex-direction: column;
          gap: 6px;
          font-size: 13px;
        }

        .cvant-order-value {
          font-weight: 600;
          text-align: right;
        }

        @media (max-width: 767.98px) {
          .cvant-dashboard-header {
            align-items: flex-start !important;
          }

          .cvant-dashboard-header .btn {
            width: 100%;
          }

          .cvant-stats-row {
            margin-top: 12px;
          }

          .cvant-order-card {
            padding: 12px;
          }

          .cvant-order-meta {
            font-size: 12px;
          }
        }
      `}</style>
    </div>
  );
};

export default CustomerDashboardLayer;
