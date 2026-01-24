"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Icon } from "@iconify/react/dist/iconify.js";
import CustomerAuthShell from "./CustomerAuthShell";
import { publicApi } from "@/lib/publicApi";

const tokenKey = "cvant_customer_token";
const userKey = "cvant_customer_user";

const CustomerSignInLayer = () => {
  const router = useRouter();
  const [form, setForm] = useState({ login: "", password: "" });
  const [showPassword, setShowPassword] = useState(false);
  const [message, setMessage] = useState(null);
  const [loading, setLoading] = useState(false);

  const onChange = (field) => (event) => {
    setMessage(null);
    setForm((prev) => ({ ...prev, [field]: event.target.value }));
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

  const handleSubmit = async (event) => {
    event.preventDefault();
    setMessage(null);

    const rawLogin = form.login.trim();
    const login = rawLogin.includes("@") ? rawLogin.toLowerCase() : rawLogin;
    const password = form.password.trim();

    if (!login || !password) {
      setMessage({
        type: "error",
        text: "Email/username dan password wajib diisi.",
      });
      return;
    }

    setLoading(true);

    try {
      const res = await publicApi.post("/customer/login", { login, password });

      const token = res?.token;
      const customer = res?.customer;

      if (!token || !customer) {
        throw new Error("Login gagal. Periksa email/username dan password.");
      }

      localStorage.setItem(tokenKey, token);
      localStorage.setItem(userKey, JSON.stringify(customer));
      setCustomerCookie(token);
      setMessage({
        type: "success",
        text: "Login berhasil. Mengarahkan ke dashboard customer...",
      });

      setTimeout(() => {
        router.replace("/customer/dashboard");
      }, 600);
    } catch (error) {
      setMessage({
        type: "error",
        text:
          error?.message ||
          "Login gagal. Periksa email/username dan password.",
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <CustomerAuthShell
      title="Masuk sebagai Customer"
      subtitle="Gunakan akun customer untuk membuat order dan pembayaran."
      footer={
        <>
          Belum punya akun? <Link href="/customer/sign-up">Daftar sekarang</Link>
        </>
      }
    >
      {message && (
        <div className={`cvant-auth-alert ${message.type}`}>{message.text}</div>
      )}

      <form onSubmit={handleSubmit} className="cvant-auth-form">
        <div>
          <label className="cvant-auth-label">Email atau Username</label>
          <div className="cvant-field">
            <span className="cvant-icon-wrap">
              <Icon icon="solar:user-linear" />
            </span>
            <input
              type="text"
              className="form-control bg-neutral-50 radius-12 cvant-input"
              placeholder="email@domain.com atau username"
              value={form.login}
              onChange={onChange("login")}
              autoComplete="username"
            />
          </div>
        </div>

        <div>
          <label className="cvant-auth-label">Password</label>
          <div className="cvant-field">
            <span className="cvant-icon-wrap">
              <Icon icon="solar:lock-password-outline" />
            </span>
            <input
              type={showPassword ? "text" : "password"}
              className="form-control bg-neutral-50 radius-12 cvant-input"
              placeholder="Password"
              value={form.password}
              onChange={onChange("password")}
              autoComplete="current-password"
              style={{ paddingRight: "58px" }}
            />
            <button
              type="button"
              className="cvant-eye-btn"
              onClick={() => setShowPassword((value) => !value)}
              aria-label={showPassword ? "Hide password" : "Show password"}
            >
              <Icon icon={showPassword ? "solar:eye-closed-linear" : "solar:eye-linear"} />
            </button>
          </div>
        </div>

        <button
          type="submit"
          className="btn text-sm btn-sm px-12 py-16 w-100 radius-12 mt-5 cvant-login-btn"
          disabled={loading}
        >
          {loading ? "Memproses..." : "Masuk"}
        </button>

        <div className="cvant-auth-helper">
          Lupa password?{" "}
          <Link href="https://instagram.com/solvix.studio">ig: solvix.studio</Link>
        </div>
      </form>
    </CustomerAuthShell>
  );
};

export default CustomerSignInLayer;
