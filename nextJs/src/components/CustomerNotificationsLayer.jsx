"use client";

import { useEffect, useState } from "react";
import { customerApi } from "@/lib/customerApi";
import {
  buildCustomerNotifications,
  formatNotificationTime,
} from "@/lib/notificationUtils";

const CustomerNotificationsLayer = () => {
  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const loadNotifications = async () => {
      try {
        const orders = await customerApi.get("/customer/orders");
        const items = buildCustomerNotifications(orders);
        setNotifications(items);
      } catch (err) {
        setError(err?.message || "Failed to load notifications.");
        setNotifications([]);
      } finally {
        setLoading(false);
      }
    };

    loadNotifications();
  }, []);

  return (
    <div className="container-fluid py-4">
      <div className="card shadow-sm border-0">
        <div className="card-body">
          {loading ? (
            <div>Loading notifications...</div>
          ) : error ? (
            <div className="text-danger">{error}</div>
          ) : notifications.length === 0 ? (
            <div>No notifications yet.</div>
          ) : (
            <div className="d-grid gap-3">
              {notifications.map((item) => (
                <div key={item.id} className="border rounded-3 p-3">
                  <div className="d-flex align-items-start justify-content-between gap-3">
                    <div>
                      <h6 className="mb-1">{item.title}</h6>
                      <p className="mb-1 text-secondary-light">{item.message}</p>
                      <span className="text-secondary-light text-sm">
                        {formatNotificationTime(item.time)}
                      </span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default CustomerNotificationsLayer;
