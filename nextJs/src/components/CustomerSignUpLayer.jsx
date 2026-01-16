"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Icon } from "@iconify/react/dist/iconify.js";
import CustomerAuthShell from "./CustomerAuthShell";

const accountsKey = "cvant_customer_accounts";

const CustomerSignUpLayer = () => {
  const router = useRouter();
  const [form, setForm] = useState({
    name: "",
    email: "",
    phone: "",
    company: "",
    password: "",
    confirmPassword: "",
  });
  const [showPassword, setShowPassword] = useState(false);
  const [message, setMessage] = useState(null);
  const [loading, setLoading] = useState(false);

  const onChange = (field) => (event) => {
    setMessage(null);
    setForm((prev) => ({ ...prev, [field]: event.target.value }));
  };

  const handleSubmit = (event) => {
    event.preventDefault();
    setMessage(null);

    const name = form.name.trim();
    const email = form.email.trim().toLowerCase();
    const phone = form.phone.trim();
    const company = form.company.trim();
    const password = form.password.trim();
    const confirmPassword = form.confirmPassword.trim();

    if (!name || !email || !phone || !password || !confirmPassword) {
      setMessage({ type: "error", text: "Lengkapi semua field wajib." });
      return;
    }

    if (password.length < 6) {
      setMessage({ type: "error", text: "Password minimal 6 karakter." });
      return;
    }

    if (password !== confirmPassword) {
      setMessage({ type: "error", text: "Konfirmasi password tidak sama." });
      return;
    }

    setLoading(true);

    try {
      const accounts = JSON.parse(localStorage.getItem(accountsKey) || "[]");
      const exists = accounts.some(
        (item) => (item.email || "").toLowerCase() === email
      );

      if (exists) {
        setMessage({ type: "error", text: "Email sudah terdaftar. Silakan masuk." });
        return;
      }

      const newAccount = {
        id: `cust_${Date.now()}`,
        name,
        email,
        phone,
        company,
        password,
        createdAt: new Date().toISOString(),
      };

      accounts.push(newAccount);
      localStorage.setItem(accountsKey, JSON.stringify(accounts));
      setMessage({ type: "success", text: "Akun berhasil dibuat. Silakan login." });

      setTimeout(() => {
        router.push("/customer/sign-in");
      }, 700);
    } finally {
      setLoading(false);
    }
  };

  return (
    <CustomerAuthShell
      title="Daftar Customer"
      subtitle="Buat akun untuk akses order dan pembayaran."
      footer={
        <>
          Sudah punya akun? <Link href="/customer/sign-in">Masuk</Link>
        </>
      }
    >
      {message && (
        <div className={`cvant-auth-alert ${message.type}`}>{message.text}</div>
      )}

      <form onSubmit={handleSubmit} className="cvant-auth-form">
        <div>
          <label className="cvant-auth-label">Nama Lengkap</label>
          <div className="cvant-auth-field">
            <span className="cvant-auth-icon">
              <Icon icon="solar:user-linear" />
            </span>
            <input
              type="text"
              className="cvant-auth-input"
              placeholder="Nama lengkap"
              value={form.name}
              onChange={onChange("name")}
              autoComplete="name"
            />
          </div>
        </div>

        <div>
          <label className="cvant-auth-label">Email</label>
          <div className="cvant-auth-field">
            <span className="cvant-auth-icon">
              <Icon icon="solar:mailbox-linear" />
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
          <label className="cvant-auth-label">Nomor HP</label>
          <div className="cvant-auth-field">
            <span className="cvant-auth-icon">
              <Icon icon="solar:phone-calling-linear" />
            </span>
            <input
              type="tel"
              className="cvant-auth-input"
              placeholder="08xxxxxxxxxx"
              value={form.phone}
              onChange={onChange("phone")}
              autoComplete="tel"
            />
          </div>
        </div>

        <div>
          <label className="cvant-auth-label">Perusahaan (opsional)</label>
          <div className="cvant-auth-field">
            <span className="cvant-auth-icon">
              <Icon icon="solar:buildings-linear" />
            </span>
            <input
              type="text"
              className="cvant-auth-input"
              placeholder="Nama perusahaan"
              value={form.company}
              onChange={onChange("company")}
              autoComplete="organization"
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
              autoComplete="new-password"
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

        <div>
          <label className="cvant-auth-label">Konfirmasi Password</label>
          <div className="cvant-auth-field">
            <span className="cvant-auth-icon">
              <Icon icon="solar:lock-password-outline" />
            </span>
            <input
              type={showPassword ? "text" : "password"}
              className="cvant-auth-input"
              placeholder="Konfirmasi password"
              value={form.confirmPassword}
              onChange={onChange("confirmPassword")}
              autoComplete="new-password"
              style={{ paddingRight: "44px" }}
            />
          </div>
        </div>

        <button type="submit" className="cvant-auth-btn" disabled={loading}>
          {loading ? "Mendaftar..." : "Daftar"}
        </button>
      </form>
    </CustomerAuthShell>
  );
};

export default CustomerSignUpLayer;
