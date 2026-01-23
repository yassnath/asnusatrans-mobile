"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Icon } from "@iconify/react/dist/iconify.js";
import Link from "next/link";
import { api } from "@/lib/api";
import { publicApi } from "@/lib/publicApi";
import AuthShell from "@/components/AuthShell";

const LoginLayer = () => {
  const router = useRouter();
  const [form, setForm] = useState({
    login: "",
    password: "",
  });
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);

  const [popup, setPopup] = useState({
    show: false,
    type: "success",
    message: "",
  });

  const customerTokenKey = "cvant_customer_token";
  const customerUserKey = "cvant_customer_user";

  const onChange = (field) => (e) => {
    setPopup((p) => ({ ...p, show: false }));
    setForm((prev) => ({ ...prev, [field]: e.target.value }));
  };

  const showPopup = (type, message, autoCloseMs = 0) => {
    setPopup({ show: true, type, message });

    if (showPopup._t) window.clearTimeout(showPopup._t);

    if (autoCloseMs > 0) {
      showPopup._t = window.setTimeout(() => {
        setPopup((p) => ({ ...p, show: false }));
      }, autoCloseMs);
    }
  };

  const sanitizeLoginError = (rawMsg) => {
    const msg = (rawMsg || "").toLowerCase();

    if (
      (msg.includes("username") || msg.includes("email")) &&
      msg.includes("password") &&
      msg.includes("tidak sesuai")
    ) {
      return "Login gagal. Periksa email/username dan password.";
    }

    return rawMsg || "Login gagal. Periksa email/username dan password.";
  };

  const setCustomerCookie = (token) => {
    const isHttps = window.location.protocol === "https:";
    document.cookie = [
      `customer_token=${token}`,
      "path=/",
      "SameSite=Lax",
      "max-age=86400",
      isHttps ? "Secure" : "",
    ]
      .filter(Boolean)
      .join("; ");
  };

  const clearCustomerSession = () => {
    if (typeof window === "undefined") return;
    localStorage.removeItem(customerTokenKey);
    localStorage.removeItem(customerUserKey);
    document.cookie =
      "customer_token=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT; SameSite=Lax;";
  };

  const loginAdmin = async (login, password) => {
    const res = await publicApi.post("/login", {
      username: login,
      password,
    });

    const { token, user } = res || {};

    if (!token || !user) {
      throw new Error("Login gagal. Periksa email/username dan password.");
    }

    api.clearToken();
    clearCustomerSession();

    localStorage.setItem("token", token);
    localStorage.setItem("user", JSON.stringify(user));
    localStorage.setItem("role", user.role || "");
    localStorage.setItem("username", user.username || "");

    const isHttps = window.location.protocol === "https:";
    document.cookie = [
      `token=${token}`,
      "path=/",
      "SameSite=Lax",
      "max-age=86400",
      isHttps ? "Secure" : "",
    ]
      .filter(Boolean)
      .join("; ");

    showPopup("success", "Login berhasil! Mengarahkan ke dashboard...", 3000);

    setTimeout(() => {
      router.replace("/dashboard");
      router.refresh();
    }, 1000);
  };

  const loginCustomer = async (login, password) => {
    const res = await publicApi.post("/customer/login", {
      login,
      password,
    });

    const { token, customer } = res || {};

    if (!token || !customer) {
      throw new Error("Login gagal. Periksa email/username dan password.");
    }

    api.clearToken();

    localStorage.setItem(customerTokenKey, token);
    localStorage.setItem(customerUserKey, JSON.stringify(customer));
    setCustomerCookie(token);

    showPopup(
      "success",
      "Login berhasil! Mengarahkan ke dashboard customer...",
      3000
    );

    setTimeout(() => {
      router.replace("/customer/dashboard");
      router.refresh();
    }, 1000);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setPopup((p) => ({ ...p, show: false }));

    const rawLogin = (form.login || "").trim();
    const login = rawLogin.toLowerCase();
    const password = (form.password || "").trim();

    if (!login && !password) {
      showPopup("danger", "Email/username dan password wajib diisi.", 0);
      return;
    }
    if (!login) {
      showPopup("danger", "Email/username masih kosong, harap diisi.", 0);
      return;
    }
    if (!password) {
      showPopup("danger", "Password masih kosong, harap diisi.", 0);
      return;
    }

    setLoading(true);

    try {
      const looksLikeEmail = login.includes("@");
      const attempts = looksLikeEmail
        ? [loginCustomer, loginAdmin]
        : [loginAdmin, loginCustomer];
      let lastError = null;

      for (const attempt of attempts) {
        try {
          await attempt(login, password);
          return;
        } catch (err) {
          lastError = err;
        }
      }

      const msg = sanitizeLoginError(
        lastError?.message || "Login gagal. Periksa email/username dan password."
      );
      showPopup("danger", msg, 0);
    } finally {
      setLoading(false);
    }
  };

  const popupAccent = popup.type === "success" ? "#22c55e" : "#ef4444";

  return (
    <>

      {/* POPUP */}
      {popup.show && (
        <div
          className="position-fixed top-0 start-0 w-100 h-100 d-flex align-items-center justify-content-center"
          style={{
            zIndex: 9999,
            background: "rgba(0,0,0,0.55)",
            padding: "16px",
          }}
          onClick={() => setPopup((p) => ({ ...p, show: false }))}
        >
          <div
            className="radius-12 shadow-sm p-24"
            style={{
              width: "100%",
              maxWidth: "600px",
              backgroundColor: "#1b2431",
              border: `2px solid ${popupAccent}`,
              boxShadow: "0 22px 55px rgba(0,0,0,0.55)",
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
                    {popup.type === "success" ? "Login Success" : "Login Failed"}
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
                onClick={() => setPopup((p) => ({ ...p, show: false }))}
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
                onClick={() => setPopup((p) => ({ ...p, show: false }))}
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

      {/* PAGE */}
      <AuthShell
        title="Sign In"
        subtitle="Masukkan email atau username dan password Anda."
      >
        <form onSubmit={handleSubmit}>
          <div className="cvant-field mb-16">
            <span className="cvant-icon-wrap">
              <Icon icon="solar:user-linear" fontSize={20} />
            </span>
            <input
              type="text"
              className="form-control bg-neutral-50 radius-12 cvant-input"
              placeholder="Email / Username"
              aria-label="Email atau Username"
              value={form.login}
              onChange={onChange("login")}
              autoComplete="username"
            />
          </div>

          <div className="cvant-field mb-18">
            <span className="cvant-icon-wrap">
              <Icon icon="solar:lock-password-outline" fontSize={20} />
            </span>

            <input
              type={showPassword ? "text" : "password"}
              className="form-control bg-neutral-50 radius-12 cvant-input"
              placeholder="Password"
              aria-label="Password"
              value={form.password}
              onChange={onChange("password")}
              autoComplete="current-password"
              style={{ paddingRight: "58px" }}
            />

            <button
              type="button"
              onClick={() => setShowPassword((v) => !v)}
              aria-label={showPassword ? "Hide password" : "Show password"}
              className="cvant-eye-btn"
            >
              <Icon
                icon={
                  showPassword
                    ? "solar:eye-closed-linear"
                    : "solar:eye-linear"
                }
                fontSize={20}
                style={{ color: "#6b7280" }}
              />
            </button>
          </div>

          <button
            type="submit"
            className="btn text-sm btn-sm px-12 py-16 w-100 radius-12 mt-5 cvant-login-btn"
            disabled={loading}
          >
            {loading ? "Memproses..." : "Login"}
          </button>

          <div className="mt-3 text-center text-m">
            <p className="mb-0 text-neutral-400">
              Forgot Password?{" "}
              <Link
                href="https://wa.me//+6285771753354"
                className="text-primary-600 fw-semibold"
              >
                Click here!
              </Link>
            </p>
            <p className="mb-0 text-neutral-400 mt-1">
              Belum punya akun?{" "}
              <Link href="/customer/sign-up" className="text-primary-600 fw-semibold">
                Daftar sekarang
              </Link>
            </p>
          </div>
        </form>
      </AuthShell>
    </>
  );
};

export default LoginLayer;
