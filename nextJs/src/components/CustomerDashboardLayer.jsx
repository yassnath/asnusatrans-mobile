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

  return (
    <div className="container-fluid py-4">
      <div className="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-4">
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
        <div className="col-md-4">
          <div className="card shadow-sm border-0 h-100">
            <div className="card-body d-flex align-items-center gap-3">
              <span className="d-flex align-items-center justify-content-center rounded-circle bg-primary-50 text-primary-600 w-48-px h-48-px">
                <Icon icon="solar:clipboard-check-linear" />
              </span>
              <div>
                <p className="mb-1 text-secondary-light">Total Order</p>
                <h5 className="mb-0">{stats.total}</h5>
              </div>
            </div>
          </div>
        </div>
        <div className="col-md-4">
          <div className="card shadow-sm border-0 h-100">
            <div className="card-body d-flex align-items-center gap-3">
              <span className="d-flex align-items-center justify-content-center rounded-circle bg-warning-focus text-warning-600 w-48-px h-48-px">
                <Icon icon="solar:hourglass-linear" />
              </span>
              <div>
                <p className="mb-1 text-secondary-light">Pending Payment</p>
                <h5 className="mb-0">{stats.pending}</h5>
              </div>
            </div>
          </div>
        </div>
        <div className="col-md-4">
          <div className="card shadow-sm border-0 h-100">
            <div className="card-body d-flex align-items-center gap-3">
              <span className="d-flex align-items-center justify-content-center rounded-circle bg-success-focus text-success-600 w-48-px h-48-px">
                <Icon icon="solar:card-transfer-linear" />
              </span>
              <div>
                <p className="mb-1 text-secondary-light">Total Biaya</p>
                <h5 className="mb-0">{formatCurrency(stats.totalSpend)}</h5>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="card shadow-sm border-0">
        <div className="card-header bg-transparent d-flex align-items-center justify-content-between flex-wrap gap-2">
          <h6 className="mb-0">Riwayat Order Terbaru</h6>
          <Link href="/customer/orders" className="btn btn-outline-primary btn-sm">
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
            <div className="table-responsive">
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
                  {orders.slice(0, 5).map((order) => (
                    <tr key={order.id}>
                      <td>{order.order_code || `ORD-${order.id}`}</td>
                      <td>
                        {order.pickup} - {order.destination}
                      </td>
                      <td>
                        {order.pickup_date}{" "}
                        {order.pickup_time
                          ? `| ${String(order.pickup_time).slice(0, 5)}`
                          : ""}
                      </td>
                      <td>{order.service}</td>
                      <td>{formatCurrency(order.total)}</td>
                      <td>{order.status}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default CustomerDashboardLayer;
