"use client";

import { Icon } from "@iconify/react/dist/iconify.js";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";

function useCvAntPageIn() {
  const [pageIn, setPageIn] = useState(false);

  useEffect(() => {
    const t = requestAnimationFrame(() => setPageIn(true));
    return () => cancelAnimationFrame(t);
  }, []);

  return pageIn;
}

function isLightModeNow() {
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
}

export default function ArmadaAddLayer() {
  const pageIn = useCvAntPageIn();
  const router = useRouter();

  const [form, setForm] = useState({
    nama_truk: "",
    plat_nomor: "",
    kapasitas: "",
    status: "Ready",
  });

  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState("");

  const [isLightMode, setIsLightMode] = useState(false);

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

  const [popup, setPopup] = useState({
    show: false,
    type: "success",
    message: "",
  });

  const showPopup = (type, message, autoCloseMs = 0) => {
    setPopup({ show: true, type, message });

    window.clearTimeout(showPopup._t);

    if (autoCloseMs > 0) {
      showPopup._t = window.setTimeout(() => {
        setPopup((p) => ({ ...p, show: false }));
      }, autoCloseMs);
    }
  };

  const closePopup = () => setPopup((p) => ({ ...p, show: false }));

  // ✅ POPUP CONFIRM DUPLICATE PLATE (WARNING)
  const [duplicateConfirm, setDuplicateConfirm] = useState({
    show: false,
    plat: "",
    savingAnyway: false,
  });

  const openDuplicateConfirm = (plat) => {
    setDuplicateConfirm({ show: true, plat, savingAnyway: false });
  };

  const closeDuplicateConfirm = () => {
    setDuplicateConfirm({ show: false, plat: "", savingAnyway: false });
  };

  const popupAccent =
    popup.type === "success"
      ? "#22c55e"
      : popup.type === "warning"
      ? "#d97706"
      : "#ef4444";

  const controlBg = isLightMode ? "#ffffff" : "#273142";
  const controlText = isLightMode ? "#0b1220" : "#ffffff";
  const controlBorder = isLightMode ? "#c7c8ca" : "#6c757d";
  const optionBg = controlBg;
  const optionText = controlText;

  const onChange = (k) => (e) => {
    let v = e.target.value;
    if (k === "kapasitas") v = v === "" ? "" : Number(v);
    setForm((s) => ({ ...s, [k]: v }));
  };

  // ✅ VALIDASI FIELD KOSONG (GENERAL POPUP)
  const validate = () => {
    const msgGeneral = "Data is still incomplete, please complete it first!";

    if (
      !String(form.nama_truk || "").trim() ||
      !String(form.plat_nomor || "").trim() ||
      !String(form.kapasitas || "").trim()
    ) {
      setErr("");
      showPopup("danger", msgGeneral, 0);
      return false;
    }
    return true;
  };

  // ✅ FUNCTION SAVE FINAL (dipakai juga saat Save Anyway)
  const doSave = async () => {
    setSaving(true);
    setErr("");

    try {
      await api.post("/armadas", form);

      showPopup(
        "success",
        "Fleet successfully added! Redirecting to Fleet List Page...",
        3000
      );
      setTimeout(() => {
        router.push("/armada-list");
      }, 3000);
    } catch (e) {
      console.error("Error saving armada:", e);
      const msg = e?.message || "Failed to save fleet.";
      setErr(msg);
      showPopup("danger", msg, 0);
    } finally {
      setSaving(false);
      closeDuplicateConfirm();
    }
  };

  const onSave = async () => {
    if (!validate()) return;

    try {
      // ✅ cek duplicate plat nomor
      const allArmadas = await api.get("/armadas");
      const list = Array.isArray(allArmadas) ? allArmadas : [];

      const inputPlat = String(form.plat_nomor || "").trim().toLowerCase();

      const exists = list.some((a) => {
        const plat = String(a?.plat_nomor || "").trim().toLowerCase();
        return plat === inputPlat;
      });

      if (exists) {
        // ✅ tampilkan popup warning duplicate
        openDuplicateConfirm(form.plat_nomor);
        return;
      }

      // ✅ kalau tidak duplicate lanjut save normal
      await doSave();
    } catch (e) {
      const msg = e?.message || "Failed to check fleet list.";
      showPopup("danger", msg, 0);
    }
  };

  return (
    <>
      <div className={`cvant-page-in ${pageIn ? "is-in" : ""}`}>
        {/* ✅ POPUP GENERAL (SUCCESS / ERROR) */}
        {popup.show && (
          <div
            className="position-fixed top-0 start-0 w-100 h-100 d-flex align-items-center justify-content-center"
            style={{
              zIndex: 9999,
              background: "rgba(0,0,0,0.55)",
              padding: "16px",
            }}
            onClick={closePopup}
          >
            <div
              className="radius-12 shadow-sm p-24"
              style={{
                width: "100%",
                maxWidth: "600px",
                backgroundColor: "#1b2431",
                border: `2px solid ${popupAccent}`,
              }}
              onClick={(e) => e.stopPropagation()}
            >
              <div className="d-flex align-items-start justify-content-between gap-2">
                <div className="d-flex align-items-start gap-12">
                  <span style={{ marginTop: "2px" }}>
                    <Icon
                      icon={
                        popup.type === "success"
                          ? "solar:check-circle-linear"
                          : "solar:danger-triangle-linear"
                      }
                      style={{
                        fontSize: "28px",
                        color: popupAccent,
                      }}
                    />
                  </span>

                  <div>
                    <h5 className="mb-8 fw-bold" style={{ color: "#ffffff" }}>
                      {popup.type === "success" ? "Success" : "Error"}
                    </h5>
                    <p
                      className="mb-0"
                      style={{ color: "#cbd5e1", fontSize: "15px" }}
                    >
                      {popup.message}
                    </p>
                  </div>
                </div>

                <button
                  type="button"
                  className="btn p-0"
                  aria-label="Close"
                  onClick={closePopup}
                  style={{
                    border: "none",
                    background: "transparent",
                    lineHeight: 1,
                  }}
                >
                  <Icon
                    icon="solar:close-circle-linear"
                    style={{ fontSize: 24, color: "#94a3b8" }}
                  />
                </button>
              </div>

              <div className="d-flex justify-content-end mt-20">
                <button
                  type="button"
                  className={`btn btn-${
                    popup.type === "success" ? "primary" : "danger"
                  } radius-12 px-16`}
                  onClick={closePopup}
                  style={{
                    border: `2px solid ${popupAccent}`,
                  }}
                >
                  OK
                </button>
              </div>
            </div>
          </div>
        )}

        {/* ✅ POPUP WARNING DUPLICATE PLAT */}
        {duplicateConfirm.show && (
          <div
            className="position-fixed top-0 start-0 w-100 h-100 d-flex align-items-center justify-content-center"
            style={{
              zIndex: 9999,
              background: "rgba(0,0,0,0.55)",
              padding: "16px",
            }}
            onClick={() => {
              if (!saving) closeDuplicateConfirm();
            }}
          >
            <div
              className="radius-12 shadow-sm p-24"
              style={{
                width: "100%",
                maxWidth: "600px",
                backgroundColor: "#1b2431",
                border: "2px solid #d97706", // warning-600
              }}
              onClick={(e) => e.stopPropagation()}
            >
              <div className="d-flex align-items-start justify-content-between gap-2">
                <div className="d-flex align-items-start gap-12">
                  <span style={{ marginTop: "2px" }}>
                    <Icon
                      icon="solar:danger-triangle-linear"
                      style={{
                        fontSize: "28px",
                        color: "#d97706",
                      }}
                    />
                  </span>

                  <div>
                    <h5 className="mb-8 fw-bold" style={{ color: "#ffffff" }}>
                      Warning
                    </h5>
                    <p
                      className="mb-0"
                      style={{ color: "#cbd5e1", fontSize: "15px" }}
                    >
                      Vehicle plate number already exists! Please double-check!
                    </p>
                  </div>
                </div>

                <button
                  type="button"
                  className="btn p-0"
                  aria-label="Close"
                  onClick={() => {
                    if (!saving) closeDuplicateConfirm();
                  }}
                  style={{
                    border: "none",
                    background: "transparent",
                    lineHeight: 1,
                  }}
                  disabled={saving}
                >
                  <Icon
                    icon="solar:close-circle-linear"
                    style={{ fontSize: 24, color: "#94a3b8" }}
                  />
                </button>
              </div>

              <div className="d-flex justify-content-end mt-20 gap-2">
                <button
                  type="button"
                  className="btn btn-outline-secondary radius-12 px-16"
                  onClick={closeDuplicateConfirm}
                  disabled={saving}
                  style={{ border: "2px solid #64748b", color: "#e2e8f0" }}
                >
                  Cancel
                </button>

                <button
                  type="button"
                  className="btn btn-warning radius-12 px-16"
                  onClick={doSave}
                  disabled={saving}
                  style={{ border: "2px solid #d97706" }}
                >
                  {saving ? "Saving..." : "Save Anyway"}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* ✅ FORM */}
        <div className="card">
          <div className="card-header">
            <div className="d-flex flex-wrap align-items-center justify-content-end gap-2">
              <button
                type="button"
                disabled={saving}
                onClick={onSave}
                className="btn btn-sm btn-primary"
              >
                {saving ? "Saving..." : "Save"}
              </button>
            </div>
          </div>

          <div className="card-body">
            <div className="row g-3">
              <div className="col-md-4">
                <label className="form-label fw-semibold">Nama Truk</label>
                <input
                  value={form.nama_truk}
                  onChange={onChange("nama_truk")}
                  className="form-control"
                  placeholder="mis. Hino 300"
                />
              </div>

              <div className="col-md-4">
                <label className="form-label fw-semibold">Plat Nomor</label>
                <input
                  value={form.plat_nomor}
                  onChange={onChange("plat_nomor")}
                  className="form-control"
                  placeholder="mis. L 1234 XX"
                />
              </div>

              <div className="col-md-4">
                <label className="form-label fw-semibold">
                  Kapasitas (Tonase)
                </label>
                <input
                  type="number"
                  value={form.kapasitas}
                  onChange={onChange("kapasitas")}
                  className="form-control"
                  placeholder="mis. 10"
                />
              </div>

              <div className="col-md-4">
                <label className="form-label fw-semibold">Status</label>

                <select
                  value={form.status}
                  onChange={onChange("status")}
                  className="form-select"
                  style={{
                    backgroundColor: controlBg,
                    color: controlText,
                    borderColor: controlBorder,
                  }}
                >
                  <option
                    value="Ready"
                    style={{ backgroundColor: optionBg, color: optionText }}
                  >
                    Ready
                  </option>
                  <option
                    value="Full"
                    style={{ backgroundColor: optionBg, color: optionText }}
                  >
                    Full
                  </option>
                </select>
              </div>
            </div>
          </div>
        </div>
      </div>
</>
  );
}
