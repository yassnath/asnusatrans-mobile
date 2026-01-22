"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { Icon } from "@iconify/react/dist/iconify.js";
import { usePathname } from "next/navigation";
import Link from "next/link";
import ThemeToggleButton from "@/helper/ThemeToggleButton";
import { customerApi } from "@/lib/customerApi";
import {
  buildCustomerNotifications,
  formatNotificationTime,
} from "@/lib/notificationUtils";

const lastSeenKey = "cvant_customer_notif_seen";

const getTimeValue = (value) => {
  if (!value) return 0;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? 0 : date.getTime();
};

const getLastSeen = () => {
  if (typeof window === "undefined") return 0;
  const raw = window.localStorage.getItem(lastSeenKey);
  const parsed = Number(raw);
  return Number.isNaN(parsed) ? 0 : parsed;
};

const CustomerLayout = ({ children }) => {
  const pathname = usePathname();
  const [sidebarActive, setSidebarActive] = useState(false);
  const [mobileMenu, setMobileMenu] = useState(false);
  const [customer, setCustomer] = useState(null);
  const [profileOpen, setProfileOpen] = useState(false);
  const [notifOpen, setNotifOpen] = useState(false);
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const profileRef = useRef(null);
  const notifRef = useRef(null);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const stored = window.localStorage.getItem("cvant_customer_user");
    if (stored) {
      try {
        setCustomer(JSON.parse(stored));
      } catch {
        setCustomer(null);
      }
    }

    const loadProfile = async () => {
      try {
        const res = await customerApi.get("/customer/me");
        const user = res?.customer;
        if (user) {
          setCustomer(user);
          window.localStorage.setItem("cvant_customer_user", JSON.stringify(user));
        }
      } catch {
        // ignore
      }
    };

    loadProfile();
  }, []);

  const loadNotifications = async () => {
    try {
      const orders = await customerApi.get("/customer/orders");
      const items = buildCustomerNotifications(orders);
      setNotifications(items);

      const lastSeen = getLastSeen();
      const unread = items.filter((item) => getTimeValue(item.time) > lastSeen);
      setUnreadCount(unread.length);
    } catch {
      setNotifications([]);
      setUnreadCount(0);
    }
  };

  useEffect(() => {
    loadNotifications();
  }, []);

  useEffect(() => {
    if (!profileOpen) return;
    const handleClick = (event) => {
      if (!profileRef.current || profileRef.current.contains(event.target)) return;
      setProfileOpen(false);
    };
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [profileOpen]);

  useEffect(() => {
    if (!notifOpen) return;
    const handleClick = (event) => {
      if (!notifRef.current || notifRef.current.contains(event.target)) return;
      setNotifOpen(false);
    };
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [notifOpen]);

  const customerInitial = useMemo(() => {
    const name = customer?.name || "";
    return name ? name.trim().charAt(0).toUpperCase() : "C";
  }, [customer]);

  const customerRole = customer?.role || "Customer";
  const customerName = customer?.name || "Customer";

  const handleLogout = () => {
    customerApi.clearToken();
    if (typeof window !== "undefined") {
      window.location.href = "/sign-in";
    }
  };

  const markNotificationsSeen = () => {
    if (typeof window === "undefined") return;
    const now = Date.now();
    window.localStorage.setItem(lastSeenKey, String(now));
    setUnreadCount(0);
  };

  const toggleNotifications = () => {
    setNotifOpen((value) => {
      const next = !value;
      if (next) markNotificationsSeen();
      return next;
    });
  };

  const sidebarControl = () => setSidebarActive((value) => !value);
  const mobileMenuControl = () => setMobileMenu((value) => !value);

  return (
    <>
      <section className={mobileMenu ? "overlay active" : "overlay "}>
        <aside
          className={
            sidebarActive
              ? "sidebar active sidebar-collapsed"
              : mobileMenu
              ? "sidebar sidebar-open"
              : "sidebar"
          }
        >
          <button
            onClick={mobileMenuControl}
            type="button"
            className="sidebar-close-btn"
          >
            <Icon icon="radix-icons:cross-2" />
          </button>

          <div>
            <Link
              href="/customer/dashboard"
              className="sidebar-logo"
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
              }}
            >
              <img
                src="/assets/images/logo.webp"
                alt="site logo"
                className="light-logo"
              />
              <img
                src="/assets/images/logo-light.webp"
                alt="site logo"
                className="dark-logo"
              />
              <img
                src="/assets/images/logo-icon.webp"
                alt="site logo"
                className="logo-icon"
              />
            </Link>
          </div>

          <div className="sidebar-menu-area">
            <ul className="sidebar-menu" id="sidebar-menu">
              <li>
                <Link
                  href="/customer/dashboard"
                  className={
                    pathname === "/customer/dashboard" ? "active-page" : ""
                  }
                >
                  <Icon
                    icon="solar:home-smile-angle-outline"
                    className="menu-icon"
                  />
                  <span>Dashboard</span>
                </Link>
              </li>

              <li className="sidebar-menu-group-title">Order</li>

              <li>
                <Link
                  href="/order"
                  className={pathname === "/order" ? "active-page" : ""}
                >
                  <Icon icon="solar:clipboard-check-linear" className="menu-icon" />
                  <span>Order & Payment</span>
                </Link>
              </li>

              <li>
                <Link
                  href="/customer/orders"
                  className={
                    pathname === "/customer/orders" ? "active-page" : ""
                  }
                >
                  <Icon icon="solar:document-text-linear" className="menu-icon" />
                  <span>Riwayat Pesanan</span>
                </Link>
              </li>

              <li className="sidebar-menu-group-title">Akun</li>

              <li>
                <Link
                  href="/customer/notifications"
                  className={
                    pathname === "/customer/notifications" ? "active-page" : ""
                  }
                >
                  <Icon icon="solar:bell-linear" className="menu-icon" />
                  <span>Notifikasi</span>
                </Link>
              </li>

              <li>
                <Link
                  href="/customer/settings"
                  className={
                    pathname === "/customer/settings" ? "active-page" : ""
                  }
                >
                  <Icon icon="solar:settings-linear" className="menu-icon" />
                  <span>Settings</span>
                </Link>
              </li>
            </ul>
          </div>
        </aside>

        <main className={sidebarActive ? "dashboard-main active" : "dashboard-main"}>
          <div className="navbar-header">
            <div className="row align-items-center justify-content-between">
              <div className="col-auto">
                <div className="d-flex flex-wrap align-items-center gap-4">
                  <button
                    type="button"
                    className="sidebar-toggle"
                    onClick={sidebarControl}
                  >
                    {sidebarActive ? (
                      <Icon
                        icon="iconoir:arrow-right"
                        className="icon text-2xl non-active"
                      />
                    ) : (
                      <Icon
                        icon="heroicons:bars-3-solid"
                        className="icon text-2xl non-active"
                      />
                    )}
                  </button>

                  <button
                    onClick={mobileMenuControl}
                    type="button"
                    className="sidebar-mobile-toggle"
                  >
                    <Icon icon="heroicons:bars-3-solid" className="icon" />
                  </button>

                  <form className="navbar-search">
                    <input type="text" placeholder="Search" />
                    <Icon icon="ion:search-outline" className="icon" />
                  </form>
                </div>
              </div>

              <div className="col-auto">
                <div className="d-flex flex-wrap align-items-center gap-3">
                  <ThemeToggleButton />

                  <div className="cvant-notify" ref={notifRef}>
                    <button
                      type="button"
                      className="cvant-notify-btn"
                      onClick={toggleNotifications}
                      aria-label="Notifikasi"
                      aria-expanded={notifOpen}
                    >
                      <Icon icon="solar:bell-linear" className="icon" />
                      {unreadCount > 0 ? (
                        <span className="cvant-notify-badge">{unreadCount}</span>
                      ) : null}
                    </button>

                    {notifOpen ? (
                      <div className="cvant-notify-menu">
                        <div className="cvant-notify-header">
                          <div>
                            <h6 className="mb-0">Notifikasi</h6>
                            <span className="text-secondary-light text-sm">
                              Aktivitas terbaru order Anda
                            </span>
                          </div>
                          <button
                            type="button"
                            className="cvant-notify-close"
                            onClick={() => setNotifOpen(false)}
                            aria-label="Tutup notifikasi"
                          >
                            <Icon icon="radix-icons:cross-1" />
                          </button>
                        </div>

                        <div className="cvant-notify-list">
                          {notifications.length === 0 ? (
                            <div className="cvant-notify-empty">
                              Belum ada aktivitas terbaru.
                            </div>
                          ) : (
                            notifications.slice(0, 6).map((item) => (
                              <Link
                                key={item.id}
                                href={item.href || "/customer/orders"}
                                className="cvant-notify-item"
                                onClick={() => setNotifOpen(false)}
                              >
                                <div className="cvant-notify-title">{item.title}</div>
                                <div className="cvant-notify-text">{item.message}</div>
                                <div className="cvant-notify-time">
                                  {formatNotificationTime(item.time)}
                                </div>
                              </Link>
                            ))
                          )}
                        </div>

                        <Link href="/customer/notifications" className="cvant-notify-footer">
                          Lihat semua notifikasi
                        </Link>
                      </div>
                    ) : null}
                  </div>

                  <div className="cvant-profile" ref={profileRef}>
                    <button
                      className="d-flex justify-content-center align-items-center rounded-circle"
                      type="button"
                      onClick={() => setProfileOpen((value) => !value)}
                      aria-label="Menu profil"
                      aria-expanded={profileOpen}
                    >
                      <span className="cvant-profile-avatar">{customerInitial}</span>
                    </button>

                    {profileOpen ? (
                      <div className="cvant-profile-menu">
                        <div className="cvant-profile-header">
                          <div>
                            <h6 className="text-lg text-primary-light fw-semibold mb-2">
                              {customerName}
                            </h6>
                            <span className="text-secondary-light fw-medium text-sm">
                              {customerRole}
                            </span>
                          </div>

                          <button
                            type="button"
                            className="hover-text-danger"
                            onClick={() => setProfileOpen(false)}
                          >
                            <Icon icon="radix-icons:cross-1" className="icon text-xl" />
                          </button>
                        </div>

                        <ul className="cvant-profile-list">
                          <li>
                            <button
                              className="dropdown-item text-black px-0 py-8 hover-bg-transparent hover-text-danger d-flex align-items-center gap-3"
                              onClick={handleLogout}
                            >
                              <Icon icon="lucide:power" className="icon text-xl" />
                              Log Out
                            </button>
                          </li>
                        </ul>
                      </div>
                    ) : null}
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div className="dashboard-main-body">{children}</div>

          <footer className="d-footer">
            <div className="row align-items-center justify-content-between">
              <div className="col-auto">
                <p className="mb-0">c 2025 CV ANT. All Rights Reserved.</p>
              </div>
            </div>
          </footer>

        </main>
      </section>

      <style jsx global>{`
        .sidebar.sidebar-collapsed {
          width: 92px !important;
        }

        .sidebar.sidebar-collapsed .sidebar-menu > li > a {
          justify-content: center !important;
          padding-left: 0 !important;
          padding-right: 0 !important;
          margin: 0 auto !important;
          width: 66px !important;
        }

        .sidebar.sidebar-collapsed .sidebar-menu > li > a span {
          display: none !important;
        }

        .sidebar.sidebar-collapsed .sidebar-menu > li > a .menu-icon {
          margin: 0 !important;
          font-size: 22px !important;
        }

        .sidebar.sidebar-collapsed .sidebar-menu > li > a:hover,
        .sidebar.sidebar-collapsed .sidebar-menu > li > a.active-page {
          border-radius: 14px !important;
          width: 66px !important;
          margin: 0 auto !important;
          transform: translateY(-1px);
        }

        .sidebar.sidebar-collapsed .dropdown > a {
          width: 66px !important;
          margin: 0 auto !important;
          justify-content: center !important;
        }

        .sidebar.sidebar-collapsed .sidebar-submenu {
          display: none !important;
        }

        .sidebar-menu > li:not(.sidebar-menu-group-title) {
          margin-bottom: 8px !important;
        }

        .sidebar-menu-group-title {
          margin: 14px 0 10px !important;
          padding-top: 6px;
        }

        .sidebar-menu > li.dropdown {
          margin-bottom: 10px !important;
        }

        .sidebar-submenu > li {
          margin-bottom: 6px !important;
        }

        .sidebar-submenu > li:last-child {
          margin-bottom: 0 !important;
        }

        .sidebar-menu a,
        .sidebar-submenu a {
          display: flex;
          align-items: center;
          padding-top: 10px !important;
          padding-bottom: 10px !important;
          border-radius: 10px !important;
          position: relative;
          transition: all 0.2s ease !important;
        }

        .sidebar-menu > li > a:hover,
        .sidebar-menu > li > a.active-page {
          background: linear-gradient(
            90deg,
            rgba(91, 140, 255, 0.94),
            rgba(168, 85, 247, 0.92)
          ) !important;
          color: #fff !important;
          box-shadow: 0 10px 26px rgba(0, 0, 0, 0.25),
            0 0 14px rgba(91, 140, 255, 0.18),
            0 0 16px rgba(168, 85, 247, 0.14) !important;
          transform: translateY(-1px);
        }

        .sidebar-menu > li > a:hover .menu-icon,
        .sidebar-menu > li > a.active-page .menu-icon {
          color: #ffffff !important;
          filter: drop-shadow(0 0 6px rgba(255, 255, 255, 0.18));
        }

        .sidebar-menu > li > a:hover span,
        .sidebar-menu > li > a.active-page span {
          color: #ffffff !important;
        }

        .sidebar-submenu a {
          padding-top: 9px !important;
          padding-bottom: 9px !important;
          border-radius: 8px !important;
          transition: background 0.18s ease, color 0.18s ease !important;
        }

        html[data-bs-theme="dark"] .sidebar-submenu a:hover,
        html[data-bs-theme="dark"] .sidebar-submenu a.active-page,
        html[data-theme="dark"] .sidebar-submenu a:hover,
        html[data-theme="dark"] .sidebar-submenu a.active-page {
          background: rgba(91, 140, 255, 0.14) !important;
          color: #ffffff !important;
        }

        html[data-bs-theme="light"] .sidebar-submenu a:hover,
        html[data-bs-theme="light"] .sidebar-submenu a.active-page,
        html[data-theme="light"] .sidebar-submenu a:hover,
        html[data-theme="light"] .sidebar-submenu a.active-page {
          background: rgba(91, 140, 255, 0.18) !important;
          color: #0b1220 !important;
          font-weight: 600;
        }

        .sidebar-submenu a:hover .circle-icon,
        .sidebar-submenu a.active-page .circle-icon {
          opacity: 0.9;
        }

        .cvant-notify {
          position: relative;
        }

        .cvant-notify-btn {
          width: 40px;
          height: 40px;
          border-radius: 999px;
          border: 1px solid rgba(148, 163, 184, 0.3);
          background: rgba(15, 23, 42, 0.12);
          display: inline-flex;
          align-items: center;
          justify-content: center;
          color: inherit;
          position: relative;
        }

        html[data-theme="light"] .cvant-notify-btn,
        html[data-bs-theme="light"] .cvant-notify-btn {
          background: #ffffff;
        }

        .cvant-notify-badge {
          position: absolute;
          top: -4px;
          right: -4px;
          background: #ef4444;
          color: #fff;
          font-size: 10px;
          font-weight: 700;
          border-radius: 999px;
          padding: 2px 6px;
          min-width: 18px;
          text-align: center;
        }

        .cvant-notify-menu {
          position: absolute;
          top: calc(100% + 12px);
          right: 0;
          width: min(320px, 90vw);
          background: var(--bs-body-bg, #1f2937);
          border: 1px solid rgba(148, 163, 184, 0.3);
          border-radius: 12px;
          box-shadow: 0 18px 40px rgba(0, 0, 0, 0.2);
          z-index: 40;
          color: var(--text-primary-light);
        }

        .cvant-notify-header {
          display: flex;
          align-items: flex-start;
          justify-content: space-between;
          gap: 12px;
          padding: 12px 14px;
          border-bottom: 1px solid rgba(148, 163, 184, 0.2);
        }

        .cvant-notify-close {
          border: none;
          background: transparent;
          color: inherit;
          padding: 0;
        }

        .cvant-notify-list {
          max-height: 320px;
          overflow-y: auto;
        }

        .cvant-notify-item {
          padding: 12px 14px;
          border-bottom: 1px solid rgba(148, 163, 184, 0.12);
          display: block;
          text-decoration: none;
          color: inherit;
          transition: background-color 0.2s ease;
        }

        .cvant-notify-item:last-child {
          border-bottom: none;
        }

        .cvant-notify-item:hover,
        .cvant-notify-item:focus-visible {
          background-color: var(--primary-50);
          outline: none;
        }

        .cvant-notify-title {
          font-weight: 600;
          margin-bottom: 4px;
        }

        .cvant-notify-text {
          font-size: 13px;
          color: rgba(148, 163, 184, 0.9);
        }

        .cvant-notify-time {
          font-size: 11px;
          color: rgba(148, 163, 184, 0.7);
          margin-top: 6px;
        }

        html[data-theme="light"] .cvant-notify-text,
        html[data-bs-theme="light"] .cvant-notify-text,
        html[data-theme="light"] .cvant-notify-time,
        html[data-bs-theme="light"] .cvant-notify-time {
          color: rgba(100, 116, 139, 0.85);
        }

        .cvant-notify-empty {
          padding: 16px;
          text-align: center;
          font-size: 13px;
          color: rgba(148, 163, 184, 0.8);
        }

        .cvant-notify-footer {
          display: block;
          text-align: center;
          padding: 10px 12px;
          font-weight: 600;
          color: var(--primary-600);
          border-top: 1px solid rgba(148, 163, 184, 0.2);
          text-decoration: none;
        }

        .cvant-profile {
          position: relative;
        }

        .cvant-profile-avatar {
          width: 40px;
          height: 40px;
          border-radius: 50%;
          background: var(--primary-600);
          color: #fff;
          font-weight: 600;
          display: inline-flex;
          align-items: center;
          justify-content: center;
        }

        .cvant-profile-menu {
          position: absolute;
          top: calc(100% + 12px);
          right: 0;
          width: 220px;
          border-radius: 12px;
          background: var(--bs-body-bg, #1f2937);
          border: 1px solid rgba(148, 163, 184, 0.3);
          box-shadow: 0 18px 40px rgba(0, 0, 0, 0.2);
          z-index: 40;
          padding: 10px 12px;
          color: var(--text-primary-light);
        }

        .cvant-profile-menu .dropdown-item {
          color: inherit !important;
        }

        .cvant-profile-header {
          display: flex;
          align-items: flex-start;
          justify-content: space-between;
          gap: 12px;
          padding: 10px 12px;
          border-radius: 10px;
          background: var(--primary-50);
          margin-bottom: 10px;
        }

        .cvant-profile-list {
          list-style: none;
          padding: 0;
          margin: 0;
        }

        @media (max-width: 991px) {
          .sidebar.sidebar-open {
            width: 78vw !important;
            max-width: 320px !important;
            left: 0 !important;
          }

          .overlay.active {
            padding-left: 48px;
          }

          .sidebar.sidebar-open {
            border-top-right-radius: 18px !important;
            border-bottom-right-radius: 18px !important;
          }
        }
      `}</style>
    </>
  );
};

export default CustomerLayout;
