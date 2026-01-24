"use client";

import { useEffect, useState } from "react";
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
        setError(err?.message || "Failed to load order history.");
        setOrders([]);
      } finally {
        setLoading(false);
      }
    };

    loadOrders();
  }, []);

  const renderMobileCards = () => (
    <div className="d-md-none p-3 d-flex flex-column gap-12">
      {orders.map((order) => {
        const scheduleDate = formatScheduleDate(order.pickup_date || order.date);
        const schedule = `${scheduleDate}${
          order.pickup_time ? ` | ${String(order.pickup_time).slice(0, 5)}` : ""
        }`;

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
                {order.status || "-"}
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
            </div>
          </div>
        );
      })}
    </div>
  );

  return (
    <div className="container-fluid py-4">
      <div className="card shadow-sm border-0">
        <div className="card-body p-0">
          {loading ? (
            <div className="p-4">Loading data...</div>
          ) : error ? (
            <div className="p-4 text-danger">{error}</div>
          ) : orders.length === 0 ? (
            <div className="p-4">No orders yet.</div>
          ) : (
            <>
              {renderMobileCards()}

              <div className="table-responsive d-none d-md-block">
                <table className="table bordered-table text-center align-middle mb-0">
                  <thead>
                    <tr>
                      <th>Order ID</th>
                      <th>Route</th>
                      <th>Schedule</th>
                      <th>Fleet</th>
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
                          {formatScheduleDate(order.pickup_date || order.date)}{" "}
                          {order.pickup_time
                            ? `| ${String(order.pickup_time).slice(0, 5)}`
                            : ""}
                        </td>
                        <td>{order.fleet}</td>
                        <td>{formatCurrency(order.total)}</td>
                        <td>
                          <span
                            className={`${statusBadge(
                              order.status
                            )} px-16 py-4 rounded-pill fw-medium text-sm`}
                          >
                            {order.status || "-"}
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
  );
};

export default CustomerOrdersLayer;
