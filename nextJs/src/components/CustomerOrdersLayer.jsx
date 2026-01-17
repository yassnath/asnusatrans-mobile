"use client";

import { useEffect, useState } from "react";
import { customerApi } from "@/lib/customerApi";

const formatCurrency = (value) => {
  const parsed = Number(value);
  const safeValue = Number.isFinite(parsed) ? parsed : 0;
  return `Rp ${safeValue.toLocaleString("id-ID")}`;
};

const CustomerOrdersLayer = () => {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const loadOrders = async () => {
      try {
        const data = await customerApi.get("/customer/orders");
        setOrders(Array.isArray(data) ? data : []);
      } catch (err) {
        setError(err?.message || "Gagal memuat riwayat order.");
        setOrders([]);
      } finally {
        setLoading(false);
      }
    };

    loadOrders();
  }, []);

  return (
    <div className="container-fluid py-4">
      <div className="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-4">
        <div>
          <h4 className="mb-1">Riwayat Pesanan</h4>
          <p className="text-secondary-light mb-0">
            Daftar lengkap order yang pernah dibuat.
          </p>
        </div>
      </div>

      <div className="card shadow-sm border-0">
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
                    <th>Armada</th>
                    <th>Total</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {orders.map((order) => (
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
                      <td>{order.fleet}</td>
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

export default CustomerOrdersLayer;
