"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { customerApi } from "@/lib/customerApi";
import {
  buildCustomerNotifications,
  formatNotificationTime,
  getStoredInvoiceNotifications,
} from "@/lib/notificationUtils";

const readKey = "cvant_customer_notif_read";

const CustomerNotificationsLayer = () => {
  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [readIds, setReadIds] = useState([]);

  const readSet = useMemo(() => new Set(readIds), [readIds]);

  const saveReadIds = (next) => {
    setReadIds(next);
    if (typeof window !== "undefined") {
      window.localStorage.setItem(readKey, JSON.stringify(next));
      window.dispatchEvent(new CustomEvent("cvant-notif-read"));
    }
  };

  useEffect(() => {
    if (typeof window !== "undefined") {
      try {
        const stored = JSON.parse(window.localStorage.getItem(readKey) || "[]");
        setReadIds(Array.isArray(stored) ? stored : []);
      } catch {
        setReadIds([]);
      }
    }

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
      if (event.type === "cvant-notif-read") {
        try {
          const stored = JSON.parse(window.localStorage.getItem(readKey) || "[]");
          setReadIds(Array.isArray(stored) ? stored : []);
        } catch {
          setReadIds([]);
        }
        return;
      }
      if (event.key === "cvant_customer_invoice_notifications") {
        loadNotifications();
      }
      if (event.key === readKey) {
        try {
          const stored = JSON.parse(window.localStorage.getItem(readKey) || "[]");
          setReadIds(Array.isArray(stored) ? stored : []);
        } catch {
          setReadIds([]);
        }
      }
    };
    if (typeof window !== "undefined") {
      window.addEventListener("storage", handleStorage);
      window.addEventListener("cvant-notif-read", handleStorage);
    }

    return () => {
      if (typeof window !== "undefined") {
        window.removeEventListener("storage", handleStorage);
        window.removeEventListener("cvant-notif-read", handleStorage);
      }
    };
  }, []);

  const handleMarkRead = (event, id) => {
    event.preventDefault();
    event.stopPropagation();
    if (!id || readSet.has(id)) return;
    saveReadIds([...readIds, id]);
  };

  const handleOpenNotification = (event, id) => {
    if (!id || readSet.has(id)) return;
    saveReadIds([...readIds, id]);
  };

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
                const isRead = readSet.has(item.id);
                const Wrapper = item.href ? Link : "div";
                const wrapperProps = item.href
                  ? {
                      href: item.href,
                      className: `cvant-notif-card${isRead ? " is-read" : ""}`,
                      onClick: (event) => handleOpenNotification(event, item.id),
                    }
                  : {
                      className: `cvant-notif-card${isRead ? " is-read" : ""}`,
                      onClick: (event) => handleOpenNotification(event, item.id),
                    };

                return (
                  <Wrapper key={item.id} {...wrapperProps}>
                    <div className="cvant-notif-body">
                      <div>
                        <h6 className="mb-1">{item.title}</h6>
                        <p className="mb-1 text-secondary-light">{item.message}</p>
                        <span className="text-secondary-light text-sm">
                          {formatNotificationTime(item.time)}
                        </span>
                      </div>
                      <div className="cvant-notif-actions">
                        <button
                          type="button"
                          className="cvant-mark-read-btn"
                          onClick={(event) => handleMarkRead(event, item.id)}
                          disabled={isRead}
                        >
                          {isRead ? "Read" : "Mark as read"}
                        </button>
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

        .cvant-notif-card.is-read {
          opacity: 0.75;
        }

        .cvant-notif-body {
          display: flex;
          flex-direction: column;
          gap: 8px;
        }

        .cvant-notif-actions {
          display: flex;
          justify-content: flex-end;
        }

        .cvant-mark-read-btn {
          border: none;
          background: transparent;
          padding: 0;
          font-weight: 600;
          font-size: 12px;
          color: var(--primary-600);
          white-space: nowrap;
        }

        .cvant-mark-read-btn:disabled {
          color: rgba(148, 163, 184, 0.85);
          cursor: default;
        }
      `}</style>
    </div>
  );
};

export default CustomerNotificationsLayer;
