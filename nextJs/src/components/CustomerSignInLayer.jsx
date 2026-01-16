"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Icon } from "@iconify/react/dist/iconify.js";
import CustomerAuthShell from "./CustomerAuthShell";

const accountsKey = "cvant_customer_accounts";
const tokenKey = "cvant_customer_token";
const userKey = "cvant_customer_user";

const CustomerSignInLayer = () => {
  const router = useRouter();
  const [form, setForm] = useState({ email: "", password: "" });
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

  const handleSubmit = (event) => {
    event.preventDefault();
    setMessage(null);

    const email = form.email.trim().toLowerCase();
    const password = form.password.trim();

    if (!email || !password) {
      setMessage({ type: "error", text: "Email dan password wajib diisi." });
      return;
    }

    setLoading(true);

    try {
      const accounts = JSON.parse(localStorage.getItem(accountsKey) || "[]");
      const account = accounts.find(
        (item) => (item.email || "").toLowerCase() === email
      );

      if (!account) {
        setMessage({ type: "error", text: "Akun belum terdaftar. Silakan daftar dulu." });
        return;
      }

      if (account.password !== password) {
        setMessage({ type: "error", text: "Password salah. Coba lagi." });
        return;
      }

      const token = `cust_${Date.now().toString(36)}${Math.random()
        .toString(36)
        .slice(2, 8)}`;

      localStorage.setItem(tokenKey, token);
      localStorage.setItem(userKey, JSON.stringify(account));
      setCustomerCookie(token);
      setMessage({ type: "success", text: "Login berhasil. Mengarahkan ke halaman order..." });

      setTimeout(() => {
        router.replace("/order");
      }, 600);
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
          <label className="cvant-auth-label">Email</label>
          <div className="cvant-auth-field">
            <span className="cvant-auth-icon">
              <Icon icon="solar:user-linear" />
            </span>
            <input
              type="email"
              className="cvant-auth-input"
              placeholder="nama@email.com"
              value={form.email}
              onChange={onChange("email")}
              autoComplete="email"
            />
          </div>
        </div>

        <div>
          <label className="cvant-auth-label">Password</label>
          <div className="cvant-auth-field">
            <span className="cvant-auth-icon">
              <Icon icon="solar:lock-password-outline" />
            </span>
            <input
              type={showPassword ? "text" : "password"}
              className="cvant-auth-input"
              placeholder="Password"
              value={form.password}
              onChange={onChange("password")}
              autoComplete="current-password"
              style={{ paddingRight: "44px" }}
            />
            <button
              type="button"
              className="cvant-auth-eye"
              onClick={() => setShowPassword((value) => !value)}
              aria-label={showPassword ? "Hide password" : "Show password"}
            >
              <Icon icon={showPassword ? "solar:eye-closed-linear" : "solar:eye-linear"} />
            </button>
          </div>
        </div>

        <button type="submit" className="cvant-auth-btn" disabled={loading}>
          {loading ? "Memproses..." : "Masuk"}
        </button>

        <div className="text-center" style={{ color: "#94a3b8", fontSize: "13px" }}>
          Lupa password?{" "}
          <Link href="https://wa.me/+6285771753354" style={{ color: "#c7d2fe" }}>
            Hubungi admin
          </Link>
        </div>
      </form>
    </CustomerAuthShell>
  );
};

export default CustomerSignInLayer;
