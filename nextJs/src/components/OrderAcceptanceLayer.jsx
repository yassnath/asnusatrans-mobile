"use client";

import { useEffect, useState } from "react";
import { Icon } from "@iconify/react/dist/iconify.js";
import { api } from "@/lib/api";

const OrderAcceptanceLayer = () => {
  const [orders, setOrders] = useState([]);

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

  const statusBadge = (status) => {
    if (status === "Accepted") return "bg-success-focus text-success-main";
    if (status === "Rejected") return "bg-danger-focus text-danger-main";
    if (status === "Paid") return "bg-info-focus text-info-main";
    return "bg-warning-focus text-warning-main";
  };

  return (
    <div className="row">
      <div className="col-12">
        <div className="card h-100">
          <div className="card-body p-24">
            <div className="d-flex align-items-center justify-content-between flex-wrap gap-3 mb-20">
              <div>
                <h6 className="mb-4 fw-bold">Penerimaan Order Customer</h6>
                <p className="text-secondary-light mb-0">
                  Kelola order masuk sebelum diteruskan ke operasional.
                </p>
              </div>
              <button className="btn btn-primary radius-8" onClick={loadOrders}>
                <Icon icon="solar:refresh-linear" className="me-6" />
                Refresh
              </button>
            </div>

            {orders.length === 0 ? (
              <div className="text-center py-40">
                <Icon icon="solar:inbox-linear" className="text-2xl text-secondary-light" />
                <p className="text-secondary-light mt-12 mb-0">
                  Belum ada order customer yang masuk.
                </p>
              </div>
            ) : (
              <div className="table-responsive scroll-sm">
                <table className="table bordered-table text-center align-middle mb-0">
                  <thead>
                    <tr>
                      <th>ID Order</th>
                      <th>Customer</th>
                      <th>Rute</th>
                      <th>Jadwal</th>
                      <th>Service</th>
                      <th>Total</th>
                      <th>Status</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {orders.map((order) => (
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
                          {order.pickup_date || "-"}{" "}
                          {order.pickup_time
                            ? `| ${String(order.pickup_time).slice(0, 5)}`
                            : ""}
                        </td>
                        <td>{order.service || "-"}</td>
                        <td>{formatCurrency(order.total)}</td>
                        <td>
                          <span
                            className={`${statusBadge(order.status)} px-16 py-4 rounded-pill fw-medium text-sm`}
                          >
                            {order.status || "Pending Payment"}
                          </span>
                        </td>
                        <td>
                          <div className="d-flex justify-content-center gap-2">
                            <button
                              className="btn btn-success btn-sm radius-8"
                              onClick={() => updateStatus(order.id, "Accepted")}
                              disabled={order.status === "Accepted"}
                            >
                              Accept
                            </button>
                            <button
                              className="btn btn-danger btn-sm radius-8"
                              onClick={() => updateStatus(order.id, "Rejected")}
                              disabled={order.status === "Rejected"}
                            >
                              Reject
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default OrderAcceptanceLayer;
