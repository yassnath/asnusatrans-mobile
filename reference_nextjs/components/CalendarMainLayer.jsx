"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { Icon } from "@iconify/react/dist/iconify.js";
import FullCalendar from "@fullcalendar/react";
import dayGridPlugin from "@fullcalendar/daygrid";
import { api } from "@/lib/api";
import { formatInvoiceNumber } from "@/lib/invoiceNumber";

export default function CalendarMainLayer() {
  // ✅ efek masuk (tanpa ubah style existing)
  const [pageIn, setPageIn] = useState(false);
  useEffect(() => {
    const t = requestAnimationFrame(() => setPageIn(true));
    return () => cancelAnimationFrame(t);
  }, []);

  const [invoices, setInvoices] = useState([]);
  const [expenses, setExpenses] = useState([]);

  const calendarRef = useRef(null);
  const calendarApiRef = useRef(null); // ✅ store api once
  const [calendarHeight, setCalendarHeight] = useState(null);

  const [currentRange, setCurrentRange] = useState({ start: "", end: "" });

  const [isLightMode, setIsLightMode] = useState(false);
  const tooltipRef = useRef(null);

  /** ✅ Mobile month state */
  const [mobileMonth, setMobileMonth] = useState(() => {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), 1);
  });

  /** ✅ Month picker ref (dipakai mobile & desktop) */
  const monthPickerRef = useRef(null);
  const [pickerMode, setPickerMode] = useState("mobile"); // "mobile" | "desktop"
  const titleMonthPickerRef = useRef(null);

  const getCssVar = (name, fallback) => {
    if (typeof window === "undefined") return fallback;
    const v = window
      .getComputedStyle(document.documentElement)
      .getPropertyValue(name)
      .trim();
    return v || fallback;
  };

  const isLightModeNow = () => {
    if (typeof window === "undefined") return false;

    const html = document.documentElement;
    const body = document.body;

    const bs = (
      html.getAttribute("data-bs-theme") ||
      body?.getAttribute("data-bs-theme") ||
      ""
    ).toLowerCase();
    if (bs === "light") return true;
    if (bs === "dark") return false;

    const dt = (
      html.getAttribute("data-theme") ||
      body?.getAttribute("data-theme") ||
      ""
    ).toLowerCase();
    if (dt === "light") return true;
    if (dt === "dark") return false;

    const cls = `${html.className || ""} ${body?.className || ""}`.toLowerCase();
    if (cls.includes("light") || cls.includes("theme-light")) return true;
    if (cls.includes("dark") || cls.includes("theme-dark")) return false;

    return false;
  };

  useEffect(() => {
    const update = () => setIsLightMode(isLightModeNow());
    update();

    const obs = new MutationObserver(update);
    obs.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-bs-theme", "data-theme", "class", "style"],
    });
    if (document.body) {
      obs.observe(document.body, {
        attributes: true,
        attributeFilter: ["data-bs-theme", "data-theme", "class", "style"],
      });
    }
    return () => obs.disconnect();
  }, []);

  useEffect(() => {
    const updateHeight = () => {
      if (calendarRef.current) {
        setCalendarHeight(calendarRef.current.offsetHeight);
      }
    };
    updateHeight();
    window.addEventListener("resize", updateHeight);
    return () => window.removeEventListener("resize", updateHeight);
  }, [invoices, expenses]);

  const normalizeDate = (value) => {
    if (!value) return "";

    const str = String(value).trim();

    if (/^\d{2}-\d{2}-\d{4}$/.test(str)) {
      const [dd, mm, yyyy] = str.split("-");
      return `${yyyy}-${mm}-${dd}`;
    }

    if (/^\d{4}-\d{2}-\d{2}$/.test(str)) return str;

    if (/^\d{4}-\d{2}-\d{2}T/.test(str)) {
      const d = new Date(str);
      if (!isNaN(d)) {
        const y = d.getFullYear();
        const m = String(d.getMonth() + 1).padStart(2, "0");
        const day = String(d.getDate()).padStart(2, "0");
        return `${y}-${m}-${day}`;
      }
      return str.split("T")[0];
    }

    if (/^\d{4}-\d{2}-\d{2}\s/.test(str)) {
      return str.split(" ")[0];
    }

    return "";
  };

  const toDisplayDDMMYYYY = (value) => {
    const norm = normalizeDate(value);
    if (!norm) return "-";
    const [y, m, d] = norm.split("-");
    return `${d}-${m}-${y}`;
  };

  /** ✅ format month title */
  const monthTitle = useMemo(() => {
    const y = mobileMonth.getFullYear();
    const m = mobileMonth.getMonth();
    const monthNames = [
      "Januari",
      "Februari",
      "Maret",
      "April",
      "Mei",
      "Juni",
      "Juli",
      "Agustus",
      "September",
      "Oktober",
      "November",
      "Desember",
    ];
    return `${monthNames[m]} ${y}`;
  }, [mobileMonth]);

  const mobileMonthValue = useMemo(() => {
    const y = mobileMonth.getFullYear();
    const m = String(mobileMonth.getMonth() + 1).padStart(2, "0");
    return `${y}-${m}`;
  }, [mobileMonth]);

  const mobileDateValue = useMemo(() => {
    const y = mobileMonth.getFullYear();
    const m = String(mobileMonth.getMonth() + 1).padStart(2, "0");
    return `${y}-${m}-01`;
  }, [mobileMonth]);

  /** ✅ generate all dates of month for mobile list */
  const mobileDays = useMemo(() => {
    const year = mobileMonth.getFullYear();
    const month = mobileMonth.getMonth();
    const last = new Date(year, month + 1, 0).getDate();

    const out = [];
    for (let day = 1; day <= last; day++) {
      const d = new Date(year, month, day);
      const iso = normalizeDate(d.toISOString());
      out.push({
        iso,
        day,
        weekDay: d.getDay(), // 0..6
      });
    }
    return out;
  }, [mobileMonth]);

  useEffect(() => {
    const load = async () => {
      try {
        const [inv, exp] = await Promise.all([
          api.get("/invoices"),
          api.get("/expenses"),
        ]);

        setInvoices(Array.isArray(inv) ? inv : []);
        setExpenses(Array.isArray(exp) ? exp : []);
      } catch {
        setInvoices([]);
        setExpenses([]);
      }
    };

    load();
    const t = setInterval(load, 5000);
    return () => clearInterval(t);
  }, []);

  const armadaColors = ["#0d6efd", "#6610f2", "#20c997", "#fd7e14", "#6f42c1"];
  const getArmadaColor = (id) => armadaColors[id % armadaColors.length];

  const calendarEvents = useMemo(() => {
    const today = normalizeDate(new Date().toISOString());

    const incomeEvents =
      invoices?.map((inv) => ({
        id: `inv-${inv.id}`,
        type: "income",
        title: formatInvoiceNumber(inv.no_invoice, inv.tanggal),
        date: normalizeDate(inv.tanggal),
        total: inv.total_bayar,
        textColor: "#0d6efd",
      })) || [];

    const expenseEvents =
      expenses?.map((exp) => ({
        id: `exp-${exp.id}`,
        type: "expense",
        title: formatInvoiceNumber(exp.no_expense, exp.tanggal),
        date: normalizeDate(exp.tanggal),
        total: exp.total_pengeluaran,
        textColor: "#dc3545",
      })) || [];

    const armadaEvents =
      invoices
        ?.filter(
          (inv) =>
            inv.armada &&
            inv.armada_start_date &&
            inv.armada_end_date &&
            inv.armada_id
        )
        .map((inv) => {
          const startISO = normalizeDate(inv.armada_start_date);
          const endISO = normalizeDate(inv.armada_end_date);

          const [y, m, d] = endISO.split("-");
          const endExclusive = `${y}-${m}-${String(Number(d) + 1).padStart(
            2,
            "0"
          )}`;

          let bg = getArmadaColor(inv.armada_id);
          let border = bg;

          const success600 = getCssVar("--success-600", "#16a34a");
          const warning600 = getCssVar("--warning-600", "#f59e0b");
          let text = warning600;

          if (today >= startISO && today <= endISO) {
            bg = "#198754";
            border = "#198754";
            text = warning600;
          } else if (today > endISO) {
            bg = "white";
            border = "#cccccc";
            text = success600;
          }

          return {
            id: `arm-${inv.id}`,
            type: "armada",
            title: `${inv.armada.nama_truk} – ${inv.armada.plat_nomor}`,
            start: startISO,
            end: endExclusive,
            backgroundColor: bg,
            textColor: text,
            borderColor: border,
            startOriginal: startISO,
            endOriginal: endISO,
          };
        }) || [];

    return [...incomeEvents, ...expenseEvents, ...armadaEvents];
  }, [invoices, expenses]);

  const getIncomeDot = (s) =>
    s === "Paid"
      ? "bg-success-600"
      : s === "Waiting"
      ? "bg-info-600"
      : "bg-warning-600";

  const getExpenseDot = (s) =>
    s === "Paid"
      ? "bg-success-600"
      : s === "Approved"
      ? "bg-primary-600"
      : "bg-warning-600";

  const leftTransactions = useMemo(() => {
    const startISO = currentRange.start ? normalizeDate(currentRange.start) : "";
    const endISO = currentRange.end ? normalizeDate(currentRange.end) : "";

    const all = [...invoices, ...expenses]
      .map((item) => {
        const iso = normalizeDate(item.tanggal);
        const [y, m, d] = (iso || "").split("-");
        return {
          ...item,
          tanggal_iso: iso,
          tanggal_dd: iso ? `${d}-${m}-${y}` : "-",
          sort_time: iso ? Number(`${y}${m}${d}`) : 0,
          isIncome: item.no_invoice !== undefined,
        };
      })
      .filter((item) => {
        if (!startISO || !endISO) return true;
        return item.tanggal_iso >= startISO && item.tanggal_iso < endISO;
      })
      .sort((a, b) => b.sort_time - a.sort_time);

    return all;
  }, [invoices, expenses, currentRange]);

  /** ✅ MOBILE EVENTS MAP (tanggal => events) */
  const mobileEventsByDate = useMemo(() => {
    const map = new Map();

    const today = normalizeDate(new Date().toISOString());

    const success600 = getCssVar("--success-600", "#16a34a");
    const warning600 = getCssVar("--warning-600", "#f59e0b");

    invoices.forEach((inv) => {
      const dateISO = normalizeDate(inv.tanggal);
      if (!dateISO) return;
      const list = map.get(dateISO) || [];
      list.push({
        type: "income",
        title: formatInvoiceNumber(inv.no_invoice, inv.tanggal),
        total: Number(inv.total_bayar || 0),
        id: inv.id,
        color: "#0d6efd",
      });
      map.set(dateISO, list);
    });

    expenses.forEach((exp) => {
      const dateISO = normalizeDate(exp.tanggal);
      if (!dateISO) return;
      const list = map.get(dateISO) || [];
      list.push({
        type: "expense",
        title: formatInvoiceNumber(exp.no_expense, exp.tanggal),
        total: Number(exp.total_pengeluaran || 0),
        id: exp.id,
        color: "#dc3545",
      });
      map.set(dateISO, list);
    });

    invoices
      .filter(
        (inv) =>
          inv.armada &&
          inv.armada_start_date &&
          inv.armada_end_date &&
          inv.armada_id
      )
      .forEach((inv) => {
        const startISO = normalizeDate(inv.armada_start_date);
        const endISO = normalizeDate(inv.armada_end_date);
        if (!startISO || !endISO) return;

        let textColor = getArmadaColor(inv.armada_id);
        if (today >= startISO && today <= endISO) textColor = warning600;
        else if (today > endISO) textColor = success600;

        const start = new Date(`${startISO}T00:00:00`);
        const end = new Date(`${endISO}T00:00:00`);

        for (
          let d = new Date(start);
          d <= end;
          d.setDate(d.getDate() + 1)
        ) {
          const iso = normalizeDate(d.toISOString());
          const list = map.get(iso) || [];

          list.push({
            type: "armada",
            title: `${inv.armada.nama_truk} – ${inv.armada.plat_nomor}`,
            id: inv.id,
            dotColor: getArmadaColor(inv.armada_id),
            color: textColor,
            startOriginal: startISO,
            endOriginal: endISO,
          });

          map.set(iso, list);
        }
      });

    for (const [key, arr] of map.entries()) {
      arr.sort((a, b) => {
        const order = { armada: 0, income: 1, expense: 2 };
        return (order[a.type] ?? 9) - (order[b.type] ?? 9);
      });
      map.set(key, arr);
    }

    return map;
  }, [invoices, expenses]);

  const ensureTooltipEl = () => {
    if (typeof document === "undefined") return null;

    if (!tooltipRef.current) {
      const el = document.createElement("div");
      el.className =
        "apexcharts-tooltip apexcharts-active apexcharts-tooltip-style-1 cvant-fc-native-tooltip";
      el.style.position = "fixed";
      el.style.zIndex = "9999";
      el.style.pointerEvents = "none";
      el.style.display = "none";
      el.style.transform = "translate(10px, 10px)";
      tooltipRef.current = el;
      document.body.appendChild(el);
    }
    return tooltipRef.current;
  };

  const hideTooltip = () => {
    const el = tooltipRef.current;
    if (!el) return;
    el.style.display = "none";
  };

  const showTooltip = (html, x, y) => {
    const el = ensureTooltipEl();
    if (!el) return;
    el.innerHTML = html;
    el.style.left = `${x}px`;
    el.style.top = `${y}px`;
    el.style.display = "block";
  };

  const buildTooltipHtmlFromLines = (title, lines = []) => {
    const body = lines
      .filter(Boolean)
      .map(
        (t) =>
          `<div style="opacity:.85;font-size:12px;margin-bottom:3px;line-height:1.2;">${t}</div>`
      )
      .join("");

    return `
      <div class="cvant-tooltip-pad" style="line-height:1.2;">
        <div style="font-weight:600;margin-bottom:3px;">${title}</div>
        ${body}
      </div>
    `;
  };

  useEffect(() => {
    return () => {
      if (tooltipRef.current) {
        tooltipRef.current.remove();
        tooltipRef.current = null;
      }
    };
  }, []);

  const btnTextColor = isLightMode ? "#111827" : "#ffffff";

  const weekNames = ["Min", "Sen", "Sel", "Rab", "Kam", "Jum", "Sab"];

  const goPrevMonth = () => {
    const y = mobileMonth.getFullYear();
    const m = mobileMonth.getMonth();
    setMobileMonth(new Date(y, m - 1, 1));
  };

  const goNextMonth = () => {
    const y = mobileMonth.getFullYear();
    const m = mobileMonth.getMonth();
    setMobileMonth(new Date(y, m + 1, 1));
  };

  /** ✅ open month picker */
  const openMonthPicker = (mode) => {
    setPickerMode(mode);
    const el = monthPickerRef.current;
    if (!el) return;

    // set value sesuai mode
    if (mode === "mobile") {
      const y = mobileMonth.getFullYear();
      const m = String(mobileMonth.getMonth() + 1).padStart(2, "0");
      el.value = `${y}-${m}`;
    } else {
      const api = calendarApiRef.current;
      const d = api?.getDate ? api.getDate() : new Date();
      const y = d.getFullYear();
      const m = String(d.getMonth() + 1).padStart(2, "0");
      el.value = `${y}-${m}`;
    }

    // trigger open
    if (typeof el.showPicker === "function") el.showPicker();
    else el.click();
  };

  /** ✅ handle picker change */
  const onMonthPicked = (e, modeOverride) => {
    const v = e.target.value; // yyyy-mm
    if (!v) return;
    const [yy, mm] = v.split("-");
    const year = Number(yy);
    const monthIndex = Number(mm) - 1;

    if (!Number.isFinite(year) || !Number.isFinite(monthIndex)) return;

    const mode = modeOverride || pickerMode;
    if (mode === "mobile") {
      setMobileMonth(new Date(year, monthIndex, 1));
    } else {
      const api = calendarApiRef.current;
      if (api?.gotoDate) api.gotoDate(new Date(year, monthIndex, 1));
    }
  };

  const onMobileDatePicked = (e) => {
    const v = e.target.value; // yyyy-mm-dd
    if (!v) return;
    const [yy, mm] = v.split("-");
    const year = Number(yy);
    const monthIndex = Number(mm) - 1;
    if (!Number.isFinite(year) || !Number.isFinite(monthIndex)) return;
    setMobileMonth(new Date(year, monthIndex, 1));
  };

  useEffect(() => {
    const start = new Date(mobileMonth.getFullYear(), mobileMonth.getMonth(), 1);
    const end = new Date(
      mobileMonth.getFullYear(),
      mobileMonth.getMonth() + 1,
      1
    );
    setCurrentRange({
      start: start.toISOString(),
      end: end.toISOString(),
    });
  }, [mobileMonth]);

  const syncTitleMonthPicker = () => {
    const input = titleMonthPickerRef.current;
    if (!input) return;
    const api = calendarApiRef.current;
    const d = api?.getDate ? api.getDate() : new Date();
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, "0");
    input.value = `${y}-${m}`;
  };

  const handleTitleMonthPicked = (e) => {
    const v = e.target.value; // yyyy-mm
    if (!v) return;
    const [yy, mm] = v.split("-");
    const year = Number(yy);
    const monthIndex = Number(mm) - 1;
    if (!Number.isFinite(year) || !Number.isFinite(monthIndex)) return;
    const api = calendarApiRef.current;
    if (api?.gotoDate) api.gotoDate(new Date(year, monthIndex, 1));
  };

  const attachTitleMonthPicker = () => {
    if (typeof document === "undefined") return;
    const titleEl = document.querySelector(".fc-toolbar-title");
    if (!titleEl) return;

    titleEl.style.cursor = "pointer";
    titleEl.title = "Klik untuk pilih bulan & tahun";
    titleEl.style.pointerEvents = "auto";
    if (!titleEl.style.position) titleEl.style.position = "relative";

    let input = titleEl.querySelector('input[data-cvant-month-picker="true"]');
    if (!input) {
      input = document.createElement("input");
      input.type = "month";
      input.setAttribute("data-cvant-month-picker", "true");
      input.setAttribute("aria-label", "Pilih bulan dan tahun");
      input.style.position = "absolute";
      input.style.inset = "0";
      input.style.opacity = "0.01";
      input.style.cursor = "pointer";
      input.style.width = "100%";
      input.style.height = "100%";
      input.style.display = "block";
      input.style.pointerEvents = "auto";
      input.style.appearance = "auto";
      input.style.webkitAppearance = "auto";
      input.style.MozAppearance = "auto";
      input.style.border = "0";
      input.style.padding = "0";
      input.style.margin = "0";
      input.style.background = "transparent";
      input.style.zIndex = "5";
      input.addEventListener("click", () => {
        if (typeof input.showPicker === "function") input.showPicker();
      });
      input.addEventListener("change", handleTitleMonthPicked);
      titleEl.appendChild(input);
    }

    titleMonthPickerRef.current = input;
    syncTitleMonthPicker();
    titleEl.onclick = () => {
      syncTitleMonthPicker();
      if (typeof input.showPicker === "function") input.showPicker();
      else input.click();
    };
  };

  return (
    <>
      {/* ✅ hidden month picker */}
      <input
        ref={monthPickerRef}
        type="month"
        style={{
          position: "fixed",
          opacity: 0,
          pointerEvents: "none",
          width: 1,
          height: 1,
          left: -9999,
          top: -9999,
        }}
        onChange={onMonthPicked}
      />

      {/* ✅ efek-in ditempel ke wrapper root */}
      <div className={`row gy-4 page-in ${pageIn ? "is-in" : ""}`}>
        {/* ✅ LEFT SIDE */}
        <div className="col-xxl-3 col-lg-4">
          <div className="card h-100 p-0">
            <div
              className="card-body p-24"
              style={{
                maxHeight: calendarHeight ? `${calendarHeight}px` : "650px",
                overflowY: "auto",
                transition: "max-height .2s ease",
              }}
            >
              <h6 className="fw-semibold text-sm text-primary-light mb-12">
                All Transactions
              </h6>

              {leftTransactions.map((item) => {
                const isIncome = item.isIncome;

                return (
                  <div
                    key={`${isIncome ? "inv" : "exp"}-${item.id}`}
                    className="event-item d-flex align-items-center justify-content-between gap-4 pb-16 mb-16 border border-start-0 border-end-0 border-top-0"
                  >
                    <div>
                      <div className="d-flex align-items-center gap-10">
                        <span
                          className={`w-12-px h-12-px ${
                            isIncome
                              ? getIncomeDot(item.status)
                              : getExpenseDot(item.status)
                          } rounded-circle`}
                        />
                        <span className="text-secondary-light text-xs">
                          {item.tanggal_dd}
                        </span>
                      </div>

                      <span
                        className="fw-semibold d-block mt-2"
                        style={{ color: isIncome ? "#0d6efd" : "#dc3545" }}
                      >
                        {isIncome
                          ? formatInvoiceNumber(item.no_invoice, item.tanggal)
                          : formatInvoiceNumber(item.no_expense, item.tanggal)}
                      </span>

                      <span className="text-secondary-light text-xs d-block mt-2">
                        Total: Rp{" "}
                        {Number(
                          isIncome ? item.total_bayar : item.total_pengeluaran
                        ).toLocaleString("id-ID")}
                      </span>

                      <span className="text-secondary-light text-xs d-block mt-1">
                        Dicatat oleh:{" "}
                        {isIncome ? item.diterima_oleh : item.dicatat_oleh}
                      </span>
                    </div>

                    <button
                      onClick={() =>
                        (window.location.href = isIncome
                          ? `/invoice-preview?id=${item.id}`
                          : `/expense-preview?id=${item.id}`)
                      }
                      className="btn p-0 border-0 bg-transparent cvant-eye-btn"
                      aria-label="View"
                      type="button"
                    >
                      <Icon
                        icon="mdi:eye-outline"
                        className="text-neutral-600 text-xl cvant-eye-icon"
                      />
                    </button>
                  </div>
                );
              })}
            </div>
          </div>
        </div>

        {/* ✅ RIGHT SIDE */}
        <div className="col-xxl-9 col-lg-8">
          <div className="card h-100 p-0">
            <div
              className="card-body p-24"
              ref={calendarRef}
              style={{
                height: "100%",
                overflow: "visible",
              }}
            >
              {/* ✅ MOBILE LIST CALENDAR */}
              <div className="d-lg-none">
                <div className="d-flex align-items-center justify-content-between mb-12">
                  {/* ✅ tombol center vertikal */}
                  <button
                    className="btn btn-sm cvant-month-btn"
                    style={{
                      border: "1px solid rgba(255,255,255,0.14)",
                      color: btnTextColor,
                    }}
                    onClick={goPrevMonth}
                    type="button"
                  >
                    <Icon icon="solar:alt-arrow-left-linear" />
                  </button>

                  {/* ✅ title clickable untuk month picker */}
                  <div style={{ position: "relative", display: "inline-block" }}>
                    <button
                      type="button"
                      className="btn p-0 border-0 bg-transparent"
                      style={{
                        fontWeight: 800,
                        fontSize: "16px",
                        color: btnTextColor,
                        cursor: "pointer",
                      }}
                    >
                      {monthTitle}
                    </button>
                    <input
                      type="date"
                      value={mobileDateValue}
                      onChange={onMobileDatePicked}
                      aria-label="Pilih bulan dan tahun"
                      onClick={(e) => {
                        if (typeof e.currentTarget.showPicker === "function") {
                          e.currentTarget.showPicker();
                        }
                      }}
                      style={{
                        position: "absolute",
                        inset: 0,
                        opacity: 0.01,
                        cursor: "pointer",
                        width: "100%",
                        height: "100%",
                        border: 0,
                        padding: 0,
                        margin: 0,
                        background: "transparent",
                        appearance: "auto",
                        WebkitAppearance: "auto",
                        MozAppearance: "auto",
                        display: "block",
                        zIndex: 2,
                      }}
                    />
                  </div>

                  {/* ✅ tombol center vertikal */}
                  <button
                    className="btn btn-sm cvant-month-btn"
                    style={{
                      border: "1px solid rgba(255,255,255,0.14)",
                      color: btnTextColor,
                    }}
                    onClick={goNextMonth}
                    type="button"
                  >
                    <Icon icon="solar:alt-arrow-right-linear" />
                  </button>
                </div>

                <div className="d-flex flex-column gap-10">
                  {mobileDays.map((d) => {
                    const items = mobileEventsByDate.get(d.iso) || [];
                    return (
                      <div
                        key={d.iso}
                        className="radius-12 p-16"
                        style={{
                          border: "1px solid rgba(255,255,255,0.10)",
                        }}
                      >
                        <div className="d-flex align-items-center justify-content-between mb-8">
                          <div className="d-flex align-items-center gap-10">
                            <span
                              className="fw-semibold"
                              style={{ fontSize: "14px", color: btnTextColor }}
                            >
                              {d.day}
                            </span>

                            <span
                              className="text-secondary-light"
                              style={{ fontSize: "13px" }}
                            >
                              {weekNames[d.weekDay]}
                            </span>
                          </div>

                          <span
                            className="text-secondary-light"
                            style={{ fontSize: "12px" }}
                          >
                            {toDisplayDDMMYYYY(d.iso)}
                          </span>
                        </div>

                        {items.length === 0 ? (
                          <div
                            className="text-secondary-light"
                            style={{ fontSize: "12px", opacity: 0.85 }}
                          >
                            No data
                          </div>
                        ) : (
                          <div className="d-flex flex-column gap-8">
                            {items.map((ev, idx) => (
                              <button
                                key={`${ev.type}-${ev.id}-${idx}`}
                                className="btn p-0 text-start border-0 bg-transparent"
                                onClick={() =>
                                  (window.location.href =
                                    ev.type === "income"
                                      ? `/invoice-preview?id=${ev.id}`
                                      : ev.type === "expense"
                                      ? `/expense-preview?id=${ev.id}`
                                      : `/invoice-preview?id=${ev.id}`)
                                }
                                style={{ cursor: "pointer" }}
                                type="button"
                              >
                                <div className="d-flex align-items-center justify-content-between gap-2">
                                  <div className="d-flex align-items-center gap-10">
                                    <span
                                      className="w-10-px h-10-px rounded-circle"
                                      style={{
                                        background:
                                          ev.type === "armada"
                                            ? ev.dotColor
                                            : ev.color,
                                        display: "inline-block",
                                      }}
                                    />

                                    <span
                                      style={{
                                        fontWeight: 700,
                                        fontSize: "13px",
                                        color: ev.color,
                                      }}
                                    >
                                      {ev.title}
                                    </span>
                                  </div>

                                  {ev.type !== "armada" && (
                                    <span
                                      className="text-secondary-light"
                                      style={{ fontSize: "12px" }}
                                    >
                                      Rp{" "}
                                      {Number(ev.total || 0).toLocaleString(
                                        "id-ID"
                                      )}
                                    </span>
                                  )}
                                </div>

                                {ev.type === "armada" && (
                                  <div
                                    className="text-secondary-light mt-1"
                                    style={{ fontSize: "12px" }}
                                  >
                                    {toDisplayDDMMYYYY(ev.startOriginal)} →{" "}
                                    {toDisplayDDMMYYYY(ev.endOriginal)}
                                  </div>
                                )}
                              </button>
                            ))}
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* ✅ DESKTOP FULLCALENDAR (TIDAK UBAH STYLE NAMA HARI) */}
              <div
                className="apexcharts-tooltip-style-1 d-none d-lg-block"
                style={{ height: "100%" }}
              >
                <FullCalendar
                  plugins={[dayGridPlugin]}
                  initialView="dayGridMonth"
                  headerToolbar={{
                    left: "prev",
                    center: "title",
                    right: "next",
                  }}
                  events={calendarEvents}
                  displayEventTime={false}
                  eventDisplay="block"
                  height="auto"
                  contentHeight="auto"
                  expandRows={true}
                  datesSet={(arg) => {
                    const startDate = arg?.view?.currentStart || arg.start;
                    const endDate = arg?.view?.currentEnd || arg.end;
                    setCurrentRange({
                      start: startDate?.toISOString
                        ? startDate.toISOString()
                        : arg.startStr,
                      end: endDate?.toISOString
                        ? endDate.toISOString()
                        : arg.endStr,
                    });
                    if (startDate) {
                      setMobileMonth(
                        new Date(
                          startDate.getFullYear(),
                          startDate.getMonth(),
                          1
                        )
                      );
                    }
                    attachTitleMonthPicker();
                  }}
                  ref={(el) => {
                    if (!el) return;
                    // store calendar api
                    try {
                      calendarApiRef.current = el.getApi();
                    } catch {}
                  }}
                  viewDidMount={() => {
                    attachTitleMonthPicker();
                  }}
                  eventDidMount={(info) => {
                    info.el.removeAttribute("title");

                    const type = info.event.extendedProps.type;

                    const makeLines = () => {
                      if (type === "income") {
                        return [
                          `Total: Rp ${Number(
                            info.event.extendedProps.total
                          ).toLocaleString("id-ID")}`,
                        ];
                      }
                      if (type === "expense") {
                        return [
                          `Total: Rp ${Number(
                            info.event.extendedProps.total
                          ).toLocaleString("id-ID")}`,
                        ];
                      }
                      if (type === "armada") {
                        return [
                          `${toDisplayDDMMYYYY(
                            info.event.extendedProps.startOriginal
                          )} → ${toDisplayDDMMYYYY(
                            info.event.extendedProps.endOriginal
                          )}`,
                        ];
                      }
                      return [];
                    };

                    const onMove = (e) => {
                      showTooltip(
                        buildTooltipHtmlFromLines(
                          info.event.title,
                          makeLines()
                        ),
                        e.clientX,
                        e.clientY
                      );
                    };

                    const onEnter = (e) => onMove(e);
                    const onLeave = () => hideTooltip();

                    info.el.addEventListener("mousemove", onMove);
                    info.el.addEventListener("mouseenter", onEnter);
                    info.el.addEventListener("mouseleave", onLeave);

                    return () => {
                      info.el.removeEventListener("mousemove", onMove);
                      info.el.removeEventListener("mouseenter", onEnter);
                      info.el.removeEventListener("mouseleave", onLeave);
                    };
                  }}
                  eventContent={(arg) => {
                    const type = arg.event.extendedProps.type;

                    if (type === "armada") {
                      return {
                        html: `
                          <div style="
                            width:100%;height:100%;
                            display:flex;justify-content:center;align-items:center;
                            font-size:0.78rem;font-weight:600;text-align:center;
                            color:${arg.event.textColor};
                          ">
                            ${arg.event.title}
                          </div>
                        `,
                      };
                    }

                    let color = "inherit";
                    if (type === "income") color = "#0d6efd";
                    if (type === "expense") color = "#dc3545";

                    return {
                      html: `
                        <div style="font-weight:600;font-size:0.83rem;color:${color}">
                          ${arg.event.title}
                        </div>
                      `,
                    };
                  }}
                />
              </div>

              <div style={{ clear: "both" }} />
            </div>
          </div>
        </div>
      </div>

      {/* ✅ CSS animasi scoped (bukan global.css) */}
      <style jsx global>{`
        .cvant-eye-btn:hover .cvant-eye-icon {
          color: var(--primary-600, #487fff) !important;
        }

        /* ✅ tombol prev/next mobile center vertikal */
        .cvant-month-btn {
          width: 38px !important;
          height: 34px !important;
          padding: 0 !important;
          display: inline-flex !important;
          align-items: center !important;
          justify-content: center !important;
          line-height: 1 !important;
        }

        .cvant-fc-native-tooltip {
          white-space: nowrap;
          max-width: 320px;

          border: 1px solid
            var(--neutral-300, rgba(255, 255, 255, 0.18)) !important;
          box-shadow: 0 10px 25px rgba(0, 0, 0, 0.18) !important;
          border-radius: 10px !important;
          overflow: hidden;
        }

        .cvant-fc-native-tooltip .cvant-tooltip-pad {
          padding: 12px 14px !important;
        }

        html[data-bs-theme="light"] .cvant-fc-native-tooltip,
        html[data-theme="light"] .cvant-fc-native-tooltip {
          background: #ffffff !important;
          color: #111827 !important;
          border-color: rgba(15, 23, 42, 0.14) !important;
        }

        html[data-bs-theme="dark"] .cvant-fc-native-tooltip,
        html[data-theme="dark"] .cvant-fc-native-tooltip {
          background: #0b1220 !important;
          color: #ffffff !important;
          border-color: rgba(255, 255, 255, 0.14) !important;
        }

        .fc .fc-button {
          background: transparent !important;
          background-color: transparent !important;
          box-shadow: none !important;
          border: 1px solid
            var(--neutral-300, rgba(255, 255, 255, 0.18)) !important;
          color: ${btnTextColor} !important;
        }

        .fc .fc-button:hover {
          background: var(--primary-600, #487fff) !important;
          border-color: var(--primary-600, #487fff) !important;
          color: #ffffff !important;
        }

        .fc .fc-button:focus,
        .fc .fc-button:active {
          background: transparent !important;
          box-shadow: none !important;
          outline: none !important;
        }

        .fc .fc-toolbar-title {
          color: ${btnTextColor} !important;
        }

        .fc .fc-scroller {
          overflow: visible !important;
          height: auto !important;
        }
        .fc .fc-view-harness {
          height: auto !important;
        }
        .fc .fc-daygrid-body {
          height: auto !important;
        }
        .fc .fc-scrollgrid-section-body > td {
          height: auto !important;
        }

        /* ✅ HATI-HATI: jangan ubah style warna hari */
        html[data-bs-theme="light"] .fc .fc-col-header-cell,
        html[data-theme="light"] .fc .fc-col-header-cell {
          background: #ffffff !important;
        }
        html[data-bs-theme="light"] .fc .fc-col-header-cell a,
        html[data-theme="light"] .fc .fc-col-header-cell a {
          color: #111827 !important;
        }

        html[data-bs-theme="dark"] .fc .fc-col-header-cell,
        html[data-theme="dark"] .fc .fc-col-header-cell {
          background: #000000 !important;
        }
        html[data-bs-theme="dark"] .fc .fc-col-header-cell a,
        html[data-theme="dark"] .fc .fc-col-header-cell a {
          color: #ffffff !important;
        }

        /* ✅ pastikan wrapper header ikut bg juga */
        html[data-bs-theme="light"]
          .fc
          .fc-col-header-cell
          .fc-scrollgrid-sync-inner,
        html[data-theme="light"]
          .fc
          .fc-col-header-cell
          .fc-scrollgrid-sync-inner {
          background: #ffffff !important;
        }
        html[data-bs-theme="dark"]
          .fc
          .fc-col-header-cell
          .fc-scrollgrid-sync-inner,
        html[data-theme="dark"]
          .fc
          .fc-col-header-cell
          .fc-scrollgrid-sync-inner {
          background: #273142 !important;
        }
      `}</style>
    </>
  );
}
