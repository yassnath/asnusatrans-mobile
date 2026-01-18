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
        setError(err?.message || "Gagal memuat data order.");
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
    <div className="d-md-none p-3 d-flex flex-column gap-12">
      {recentOrders.map((order) => {
        const schedule = `${order.pickup_date || "-"}${
          order.pickup_time ? ` | ${String(order.pickup_time).slice(0, 5)}` : ""
        }`;

        return (
          <div key={order.id} className="cvant-order-card">
            <div className="d-flex justify-content-between align-items-start gap-2">
              <div>
                <div className="fw-semibold">
                  {order.order_code || `ORD-${order.id}`}
                </div>
                <div className="text-secondary-light text-sm">
                  {order.service || "Service belum dipilih"}
                </div>
              </div>
              <span className={`cvant-status-badge ${statusBadge(order.status)}`}>
                {order.status || "Pending Payment"}
              </span>
            </div>

            <div className="cvant-order-meta">
              <div className="d-flex justify-content-between gap-3">
                <span className="text-secondary-light">Rute</span>
                <span className="cvant-order-value">
                  {order.pickup || "-"} - {order.destination || "-"}
                </span>
              </div>
              <div className="d-flex justify-content-between gap-3">
                <span className="text-secondary-light">Jadwal</span>
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
      <div className="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-4 cvant-dashboard-header">
        <div>
          <h4 className="mb-1">Dashboard Customer</h4>
          <p className="text-secondary-light mb-0">
            Ringkasan aktivitas order terbaru Anda.
          </p>
        </div>
        <Link href="/order" className="btn btn-primary btn-sm">
          Buat Order
        </Link>
      </div>

      <div className="row g-4 mb-4">
        <div className="col-12 col-sm-6 col-xl-4">
          <div className="card shadow-sm border-0 h-100 cvant-stat-card">
            <div className="card-body d-flex align-items-center gap-3">
              <span className="d-flex align-items-center justify-content-center rounded-circle bg-primary-50 text-primary-600 cvant-stat-icon">
                <Icon icon="solar:clipboard-check-linear" />
              </span>
              <div>
                <p className="mb-1 text-secondary-light cvant-stat-label">
                  Total Order
                </p>
                <h5 className="mb-0 cvant-stat-value">{stats.total}</h5>
              </div>
            </div>
          </div>
        </div>
        <div className="col-12 col-sm-6 col-xl-4">
          <div className="card shadow-sm border-0 h-100 cvant-stat-card">
            <div className="card-body d-flex align-items-center gap-3">
              <span className="d-flex align-items-center justify-content-center rounded-circle bg-warning-focus text-warning-600 cvant-stat-icon">
                <Icon icon="solar:hourglass-linear" />
              </span>
              <div>
                <p className="mb-1 text-secondary-light cvant-stat-label">
                  Pending Payment
                </p>
                <h5 className="mb-0 cvant-stat-value">{stats.pending}</h5>
              </div>
            </div>
          </div>
        </div>
        <div className="col-12 col-sm-6 col-xl-4">
          <div className="card shadow-sm border-0 h-100 cvant-stat-card">
            <div className="card-body d-flex align-items-center gap-3">
              <span className="d-flex align-items-center justify-content-center rounded-circle bg-success-focus text-success-600 cvant-stat-icon">
                <Icon icon="solar:card-transfer-linear" />
              </span>
              <div>
                <p className="mb-1 text-secondary-light cvant-stat-label">
                  Total Biaya
                </p>
                <h5 className="mb-0 cvant-stat-value">
                  {formatCurrency(stats.totalSpend)}
                </h5>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="card shadow-sm border-0">
        <div className="card-header bg-transparent d-flex align-items-center justify-content-between flex-wrap gap-2 cvant-orders-header">
          <h6 className="mb-0">Riwayat Order Terbaru</h6>
          <Link
            href="/customer/orders"
            className="btn btn-outline-primary btn-sm radius-8"
          >
            Lihat Semua
          </Link>
        </div>
        <div className="card-body p-0">
          {loading ? (
            <div className="p-4">Memuat data...</div>
          ) : error ? (
            <div className="p-4 text-danger">{error}</div>
          ) : orders.length === 0 ? (
            <div className="p-4">Belum ada order yang dibuat.</div>
          ) : (
            <>
              {renderMobileOrders()}

              <div className="d-none d-md-block card-body table-responsive scroll-sm d-flex">
                <table className="table bordered-table text-center align-middle mb-0">
                  <thead>
                    <tr>
                      <th>ID Order</th>
                      <th>Rute</th>
                      <th>Jadwal</th>
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
                          {order.pickup_date || "-"}{" "}
                          {order.pickup_time
                            ? `| ${String(order.pickup_time).slice(0, 5)}`
                            : ""}
                        </td>
                        <td>{order.service || "-"}</td>
                        <td>{formatCurrency(order.total)}</td>
                        <td>
                          <span
                            className={`cvant-status-badge ${statusBadge(
                              order.status
                            )}`}
                          >
                            {order.status || "Pending Payment"}
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

      <style jsx global>{`
        .cvant-stat-card .card-body {
          padding: 16px 18px;
        }

        .cvant-stat-icon {
          width: 44px;
          height: 44px;
          font-size: 20px;
        }

        .cvant-stat-label {
          font-size: 13px;
        }

        .cvant-stat-value {
          font-size: 20px;
          font-weight: 700;
        }

        .cvant-orders-header .btn {
          height: 32px;
          padding: 4px 12px;
        }

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
          border: 1px solid var(--bs-border-color, rgba(148, 163, 184, 0.25));
          background: var(--bs-body-bg, #1b2431);
          display: flex;
          flex-direction: column;
          gap: 10px;
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

          .cvant-stat-card .card-body {
            padding: 14px 16px;
          }

          .cvant-stat-value {
            font-size: 18px;
          }

          .cvant-orders-header {
            flex-wrap: nowrap !important;
            gap: 8px !important;
          }

          .cvant-orders-header h6 {
            font-size: 14px;
          }

          .cvant-orders-header .btn {
            height: 30px;
            padding: 4px 10px;
            font-size: 12px;
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
