"use client";
import React, { useEffect, useRef, useState } from "react";
import { Icon } from "@iconify/react/dist/iconify.js";
import { usePathname } from "next/navigation";
import ThemeToggleButton from "../helper/ThemeToggleButton";
import Link from "next/link";
import ChatbotWidget from "../components/ChatbotWidget";
import { api } from "@/lib/api";
import {
  buildAdminNotifications,
  formatNotificationTime,
} from "@/lib/notificationUtils";

const adminLastSeenKey = "cvant_admin_notif_seen";

const getTimeValue = (value) => {
  if (!value) return 0;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? 0 : date.getTime();
};

const MasterLayout = ({ children }) => {
  let pathname = usePathname();
  let [sidebarActive, seSidebarActive] = useState(false);
  let [mobileMenu, setMobileMenu] = useState(false);
  const location = usePathname();
  const [profileName, setProfileName] = useState("User");
  const [profileRole, setProfileRole] = useState("Admin");
  const [profileImage, setProfileImage] = useState("/assets/images/icon.webp");
  const [notifOpen, setNotifOpen] = useState(false);
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const notifRef = useRef(null);

  useEffect(() => {
    if (typeof window !== "undefined") {
      const storedRole = localStorage.getItem("role");
      const storedUsername = localStorage.getItem("username");

      if (storedRole === "owner") {
        setProfileName("Bezallael Antok");
        setProfileRole("Owner");
        setProfileImage("/assets/images/pp-owner.webp");
      } else if (storedRole === "admin") {
        setProfileName("Andi");
        setProfileRole("Admin");
        setProfileImage("/assets/images/pp-admin.webp");
      } else {
        setProfileName(storedUsername || "User");
        setProfileRole("User");
        setProfileImage("/assets/images/icon.webp");
      }
    }
  }, []);

  const getLastSeen = () => {
    if (typeof window === "undefined") return 0;
    const raw = window.localStorage.getItem(adminLastSeenKey);
    const parsed = Number(raw);
    return Number.isNaN(parsed) ? 0 : parsed;
  };

  const markNotificationsSeen = () => {
    if (typeof window === "undefined") return;
    const now = Date.now();
    window.localStorage.setItem(adminLastSeenKey, String(now));
    setUnreadCount(0);
  };

  const loadNotifications = async () => {
    try {
      const [customers, orders] = await Promise.all([
        api.get("/customer-registrations"),
        api.get("/customer-orders"),
      ]);
      const items = buildAdminNotifications(customers, orders);
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
    if (!notifOpen) return;
    const handleClick = (event) => {
      if (!notifRef.current || notifRef.current.contains(event.target)) return;
      setNotifOpen(false);
    };
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [notifOpen]);

  const handleLogout = () => {
    if (typeof window !== "undefined") {
      localStorage.removeItem("token");
      localStorage.removeItem("user");
      localStorage.removeItem("role");
      localStorage.removeItem("username");
    }

    document.cookie =
      "token=; path=/; expires=Thu, 01 Jan 1970 00:00:00 UTC; SameSite=Lax;";

    window.location.href = "/sign-in";
  };

  const toggleNotifications = () => {
    setNotifOpen((value) => {
      const next = !value;
      if (next) markNotificationsSeen();
      return next;
    });
  };

  useEffect(() => {
    if (typeof window === "undefined") return;

    const handleDropdownClick = (event) => {
      event.preventDefault();
      const clickedLink = event.currentTarget;
      const clickedDropdown = clickedLink.closest(".dropdown");

      if (!clickedDropdown) return;

      const isActive = clickedDropdown.classList.contains("open");

      const allDropdowns = document.querySelectorAll(".sidebar-menu .dropdown");
      allDropdowns.forEach((dropdown) => {
        dropdown.classList.remove("open");
        const submenu = dropdown.querySelector(".sidebar-submenu");
        if (submenu) submenu.style.maxHeight = "0px";
      });

      if (!isActive) {
        clickedDropdown.classList.add("open");
        const submenu = clickedDropdown.querySelector(".sidebar-submenu");
        if (submenu) submenu.style.maxHeight = `${submenu.scrollHeight}px`;
      }
    };

    const dropdownTriggers = document.querySelectorAll(
      ".sidebar-menu .dropdown > a, .sidebar-menu .dropdown > Link"
    );

    dropdownTriggers.forEach((trigger) => {
      trigger.addEventListener("click", handleDropdownClick);
    });

    const openActiveDropdown = () => {
      const allDropdowns = document.querySelectorAll(".sidebar-menu .dropdown");
      allDropdowns.forEach((dropdown) => {
        const submenuLinks = dropdown.querySelectorAll(".sidebar-submenu li a");
        submenuLinks.forEach((link) => {
          if (
            link.getAttribute("href") === location ||
            link.getAttribute("to") === location
          ) {
            dropdown.classList.add("open");
            const submenu = dropdown.querySelector(".sidebar-submenu");
            if (submenu) submenu.style.maxHeight = `${submenu.scrollHeight}px`;
          }
        });
      });
    };

    openActiveDropdown();

    return () => {
      dropdownTriggers.forEach((trigger) => {
        trigger.removeEventListener("click", handleDropdownClick);
      });
    };
  }, [location.pathname]);

  const sidebarControl = () => seSidebarActive(!sidebarActive);
  const mobileMenuControl = () => setMobileMenu(!mobileMenu);

  return (
    <>
      <section className={mobileMenu ? "overlay active" : "overlay "}>
        {/* ✅ Tambah helper class sidebar-collapsed */}
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
              href="/dashboard"
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
                  href="/dashboard"
                  className={pathname === "/dashboard" ? "active-page" : ""}
                >
                  <Icon
                    icon="solar:home-smile-angle-outline"
                    className="menu-icon"
                  />
                  <span>Dashboard</span>
                </Link>
              </li>

              <li className="sidebar-menu-group-title">Application</li>

              <li className="dropdown">
                <Link href="#" onClick={(event) => event.preventDefault()}>
                  <Icon icon="hugeicons:invoice-03" className="menu-icon" />
                  <span>Invoice</span>
                </Link>
                <ul className="sidebar-submenu">
                  <li>
                    <Link
                      href="/invoice-list"
                      className={
                        pathname === "/invoice-list" ? "active-page" : ""
                      }
                    >
                      <i className="ri-circle-fill circle-icon text-primary-600 w-auto" />{" "}
                      List
                    </Link>
                  </li>

                  <li>
                    <Link
                      href="/invoice-add"
                      className={pathname === "/invoice-add" ? "active-page" : ""}
                    >
                      <i className="ri-circle-fill circle-icon cvant-dot-income w-auto" />{" "}
                      Add Income
                    </Link>
                  </li>

                  <li>
                    <Link
                      href="/invoice-expense"
                      className={
                        pathname === "/invoice-expense" ? "active-page" : ""
                      }
                    >
                      <i className="ri-circle-fill circle-icon cvant-dot-expense w-auto" />{" "}
                      Add Expense
                    </Link>
                  </li>
                </ul>
              </li>

              <li style={{ marginTop: "-10px" }}>
                <Link
                  href="/calendar"
                  className={pathname === "/calendar" ? "active-page" : ""}
                >
                  <Icon
                    icon="material-symbols:calendar-month-outline"
                    className="menu-icon"
                  />
                  <span>Calendar</span>
                </Link>
              </li>

              <li className="dropdown">
                <Link href="#" onClick={(event) => event.preventDefault()}>
                  <Icon icon="mdi:truck-outline" className="menu-icon" />
                  <span>Fleet</span>
                </Link>
                <ul className="sidebar-submenu">
                  <li>
                    <Link
                      href="/armada-list"
                      className={pathname === "/armada-list" ? "active-page" : ""}
                    >
                      <i className="ri-circle-fill circle-icon text-primary-600 w-auto" />{" "}
                      List
                    </Link>
                  </li>
                  <li>
                    <Link
                      href="/armada-add"
                      className={pathname === "/armada-add" ? "active-page" : ""}
                    >
                      <i className="ri-circle-fill circle-icon text-success-main w-auto" />{" "}
                      Add New
                    </Link>
                  </li>
                </ul>
              </li>

              <li className="sidebar-menu-group-title">Orders</li>

              <li>
                <Link
                  href="/order-acceptance"
                  className={
                    pathname === "/order-acceptance" ? "active-page" : ""
                  }
                >
                  <Icon
                    icon="solar:clipboard-check-linear"
                    className="menu-icon"
                  />
                  <span>Penerimaan Order</span>
                </Link>
              </li>

              <li className="sidebar-menu-group-title">Customer</li>

              <li>
                <Link
                  href="/customer-registrations"
                  className={
                    pathname === "/customer-registrations" ? "active-page" : ""
                  }
                >
                  <Icon icon="solar:user-linear" className="menu-icon" />
                  <span>Pendaftaran Customer</span>
                </Link>
              </li>
            </ul>
          </div>
        </aside>

        <main
          className={sidebarActive ? "dashboard-main active" : "dashboard-main"}
        >
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
                    <input type="text" placeholder="Search" aria-label="Search" />
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
                              Aktivitas terbaru customer
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
                                href={item.href || "/dashboard"}
                                className="cvant-notify-item"
                                onClick={() => setNotifOpen(false)}
                              >
                                <div className="cvant-notify-title">
                                  {item.title}
                                </div>
                                <div className="cvant-notify-text">
                                  {item.message}
                                </div>
                                <div className="cvant-notify-time">
                                  {formatNotificationTime(item.time)}
                                </div>
                              </Link>
                            ))
                          )}
                        </div>
                      </div>
                    ) : null}
                  </div>

                  <div className="dropdown">
                    <button
                      className="d-flex justify-content-center align-items-center rounded-circle"
                      type="button"
                      data-bs-toggle="dropdown"
                    >
                      <img
                        src={profileImage}
                        alt="image_user"
                        className="w-40-px h-40-px object-fit-cover rounded-circle"
                      />
                    </button>

                    <div className="dropdown-menu to-top dropdown-menu-sm">
                      <div className="py-12 px-16 radius-8 bg-primary-50 mb-16 d-flex align-items-center justify-content-between gap-2">
                        <div>
                          <h6 className="text-lg text-primary-light fw-semibold mb-2">
                            {profileName}
                          </h6>
                          <span className="text-secondary-light fw-medium text-sm">
                            {profileRole}
                          </span>
                        </div>

                        <button type="button" className="hover-text-danger">
                          <Icon
                            icon="radix-icons:cross-1"
                            className="icon text-xl"
                          />
                        </button>
                      </div>

                      <ul className="to-top-list">
                        <li>
                          <button
                            className="dropdown-item text-black px-0 py-8 hover-bg-transparent hover-text-danger d-flex align-items-center gap-3"
                            onClick={handleLogout}
                          >
                            <Icon icon="lucide:power" className="icon text-xl" />{" "}
                            Log Out
                          </button>
                        </li>
                      </ul>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div className="dashboard-main-body">{children}</div>

          <footer className="d-footer">
            <div className="row align-items-center justify-content-between">
              <div className="col-auto">
                <p className="mb-0">© 2025 CV ANT. All Rights Reserved.</p>
              </div>
            </div>
          </footer>

          <ChatbotWidget />
        </main>
      </section>

      {/* ✅ FIX + NEON GRADIENT + GLOW SIDEBAR */}
      <style jsx global>{`
        /* =========================================
           ✅ DESKTOP COLLAPSED SIDEBAR HOVER FIX
           ========================================= */

        /* contoh default collapsed width (sesuaikan bila theme mu beda) */
        .sidebar.sidebar-collapsed {
          width: 92px !important; /* ✅ compact */
        }

        /* highlight follow width sidebar collapsed */
        .sidebar.sidebar-collapsed .sidebar-menu > li > a {
          justify-content: center !important;
          padding-left: 0 !important;
          padding-right: 0 !important;
          margin: 0 auto !important;
          width: 66px !important; /* ✅ highlight “nempel” icon */
        }

        /* sembunyikan text saat collapsed */
        .sidebar.sidebar-collapsed .sidebar-menu > li > a span {
          display: none !important;
        }

        .sidebar.sidebar-collapsed .sidebar-menu > li > a .menu-icon {
          margin: 0 !important;
          font-size: 22px !important;
        }

        /* hover/active highlight agar tidak full lebar */
        .sidebar.sidebar-collapsed .sidebar-menu > li > a:hover,
        .sidebar.sidebar-collapsed .sidebar-menu > li > a.active-page {
          border-radius: 14px !important;
          width: 66px !important;
          margin: 0 auto !important;
          transform: translateY(-1px);
        }

        /* dropdown anchor collapsed */
        .sidebar.sidebar-collapsed .dropdown > a {
          width: 66px !important;
          margin: 0 auto !important;
          justify-content: center !important;
        }

        .sidebar.sidebar-collapsed .sidebar-submenu {
          display: none !important;
        }

        /* =========================================
           ✅ MOBILE SIDEBAR WIDTH FIX
           ========================================= */
        @media (max-width: 991px) {
          .sidebar.sidebar-open {
            width: 78vw !important; /* ✅ lebih kecil dari sebelumnya */
            max-width: 320px !important;
            left: 0 !important;
          }

          /* biar header bars tetap kelihatan */
          .overlay.active {
            padding-left: 48px; /* ✅ sisakan sedikit ruang di kiri */
          }

          /* optional: geser sidebar supaya tidak terlalu mepet */
          .sidebar.sidebar-open {
            border-top-right-radius: 18px !important;
            border-bottom-right-radius: 18px !important;
          }
        }

        /* ===== SPACING SIDEBAR MENU ===== */
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

        /* ✅ Neon gradient background for main menu hover/active */
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

        /* ✅ icon ikut putih pas hover/active */
        .sidebar-menu > li > a:hover .menu-icon,
        .sidebar-menu > li > a.active-page .menu-icon {
          color: #ffffff !important;
          filter: drop-shadow(0 0 6px rgba(255, 255, 255, 0.18));
        }

        /* ✅ teks ikut putih */
        .sidebar-menu > li > a:hover span,
        .sidebar-menu > li > a.active-page span {
          color: #ffffff !important;
        }

        /* base submenu */
        .sidebar-submenu a {
          padding-top: 9px !important;
          padding-bottom: 9px !important;
          border-radius: 8px !important;
          transition: background 0.18s ease, color 0.18s ease !important;
        }

        /* ✅ DARK MODE: submenu hover -> putih */
        html[data-bs-theme="dark"] .sidebar-submenu a:hover,
        html[data-bs-theme="dark"] .sidebar-submenu a.active-page,
        html[data-theme="dark"] .sidebar-submenu a:hover,
        html[data-theme="dark"] .sidebar-submenu a.active-page {
          background: rgba(91, 140, 255, 0.14) !important;
          color: #ffffff !important;
        }

        /* ✅ LIGHT MODE: submenu hover -> text gelap */
        html[data-bs-theme="light"] .sidebar-submenu a:hover,
        html[data-bs-theme="light"] .sidebar-submenu a.active-page,
        html[data-theme="light"] .sidebar-submenu a:hover,
        html[data-theme="light"] .sidebar-submenu a.active-page {
          background: rgba(91, 140, 255, 0.18) !important;
          color: #0b1220 !important;
          font-weight: 600;
        }

        /* circle dot tetap keliatan */
        .sidebar-submenu a:hover .circle-icon,
        .sidebar-submenu a.active-page .circle-icon {
          opacity: 0.9;
        }

        /* DOT COLOR FIX */
        .cvant-dot-income {
          color: #22c55e !important;
        }
        .cvant-dot-expense {
          color: #ef4444 !important;
        }

        /* Mobile spacing */
        @media (max-width: 991px) {
          .sidebar-menu > li:not(.sidebar-menu-group-title) {
            margin-bottom: 10px !important;
          }

          .sidebar-submenu > li {
            margin-bottom: 8px !important;
          }
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
          background: var(--white);
          border: 0;
          border-radius: 16px;
          box-shadow: 0px 13px 30px 10px rgba(46, 45, 116, 0.05);
          z-index: 40;
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
      `}</style>
    </>
  );
};

export default MasterLayout;
