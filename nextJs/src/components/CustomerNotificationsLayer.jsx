"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { customerApi } from "@/lib/customerApi";
import {
  buildCustomerNotifications,
  formatNotificationTime,
  getStoredInvoiceNotifications,
} from "@/lib/notificationUtils";

const CustomerNotificationsLayer = () => {
  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const loadNotifications = async () => {
      try {
        const [orders, profile] = await Promise.all([
          customerApi.get("/customer/orders"),
          customerApi.get("/customer/me"),
        ]);
        const customer = profile?.customer || null;
        const invoiceNotifications = getStoredInvoiceNotifications();
        const items = buildCustomerNotifications(
          orders,
          customer,
          invoiceNotifications
        );
        setNotifications(items);
      } catch (err) {
        setError(err?.message || "Failed to load notifications.");
        setNotifications([]);
      } finally {
        setLoading(false);
      }
    };

    loadNotifications();

    const handleStorage = (event) => {
      if (event.key === "cvant_customer_invoice_notifications") {
        loadNotifications();
      }
    };
    if (typeof window !== "undefined") {
      window.addEventListener("storage", handleStorage);
    }

    return () => {
      if (typeof window !== "undefined") {
        window.removeEventListener("storage", handleStorage);
      }
    };
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
              {notifications.map((item) => {
                const Wrapper = item.href ? Link : "div";
                const wrapperProps = item.href
                  ? { href: item.href, className: "cvant-notif-card" }
                  : { className: "cvant-notif-card" };

                return (
                  <Wrapper key={item.id} {...wrapperProps}>
                    <div className="d-flex align-items-start justify-content-between gap-3">
                      <div>
                        <h6 className="mb-1">{item.title}</h6>
                        <p className="mb-1 text-secondary-light">{item.message}</p>
                        <span className="text-secondary-light text-sm">
                          {formatNotificationTime(item.time)}
                        </span>
                      </div>
                    </div>
                  </Wrapper>
                );
              })}
            </div>
          )}
        </div>
      </div>

      <style jsx global>{`
        .cvant-notif-card {
          border: 1px solid rgba(148, 163, 184, 0.2);
          border-radius: 12px;
          padding: 14px;
          text-decoration: none;
          color: inherit;
          transition: background-color 0.2s ease, border-color 0.2s ease;
        }

        .cvant-notif-card:hover,
        .cvant-notif-card:focus-visible {
          background: rgba(91, 140, 255, 0.08);
          border-color: rgba(91, 140, 255, 0.35);
          outline: none;
        }
      `}</style>
    </div>
  );
};

export default CustomerNotificationsLayer;
