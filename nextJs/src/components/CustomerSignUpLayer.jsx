"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Icon } from "@iconify/react/dist/iconify.js";
import { publicApi } from "@/lib/publicApi";
import AuthShell from "@/components/AuthShell";

const CustomerSignUpLayer = () => {
  const router = useRouter();
  const [form, setForm] = useState({
    name: "",
    username: "",
    email: "",
    phone: "",
    gender: "",
    birthDate: "",
    address: "",
    city: "",
    company: "",
    password: "",
    confirmPassword: "",
  });
  const [showPassword, setShowPassword] = useState(false);
  const [popup, setPopup] = useState({
    show: false,
    type: "success",
    message: "",
  });
  const [loading, setLoading] = useState(false);

  const onChange = (field) => (event) => {
    setPopup((p) => ({ ...p, show: false }));
    setForm((prev) => ({ ...prev, [field]: event.target.value }));
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

  const handleSubmit = async (event) => {
    event.preventDefault();
    setPopup((p) => ({ ...p, show: false }));

    const name = form.name.trim();
    const username = form.username.trim();
    const email = form.email.trim().toLowerCase();
    const phone = form.phone.trim();
    const gender = form.gender.trim();
    const birthDate = form.birthDate.trim();
    const address = form.address.trim();
    const city = form.city.trim();
    const company = form.company.trim();
    const password = form.password.trim();
    const confirmPassword = form.confirmPassword.trim();

    if (
      !name ||
      !username ||
      !email ||
      !phone ||
      !gender ||
      !birthDate ||
      !address ||
      !city ||
      !password ||
      !confirmPassword
    ) {
      showPopup("danger", "Lengkapi semua biodata wajib.", 0);
      return;
    }

    if (password.length < 6) {
      showPopup("danger", "Password minimal 6 karakter.", 0);
      return;
    }

    if (password !== confirmPassword) {
      showPopup("danger", "Konfirmasi password tidak sama.", 0);
      return;
    }

    setLoading(true);

    try {
      await publicApi.post("/customer/register", {
        name,
        username,
        email,
        phone,
        gender,
        birth_date: birthDate,
        address,
        city,
        company,
        password,
      });

      showPopup("success", "Akun berhasil dibuat. Silakan login.", 3000);

      setTimeout(() => {
        router.push("/sign-in");
      }, 900);
    } catch (error) {
      showPopup("danger", error?.message || "Gagal membuat akun. Coba lagi.", 0);
    } finally {
      setLoading(false);
    }
  };

  const popupAccent = popup.type === "success" ? "#22c55e" : "#ef4444";

  return (
    <>
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
                    {popup.type === "success"
                      ? "Registrasi Berhasil"
                      : "Registrasi Gagal"}
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

      <AuthShell
        title="Daftar Customer"
        subtitle="Buat akun customer untuk akses order dan pembayaran."
      >
        <form onSubmit={handleSubmit}>
          <div className="cvant-field mb-16">
            <span className="cvant-icon-wrap">
              <Icon icon="solar:user-linear" fontSize={20} />
            </span>
            <input
              type="text"
              className="form-control bg-neutral-50 radius-12 cvant-input"
              placeholder="Nama lengkap"
              value={form.name}
              onChange={onChange("name")}
              autoComplete="name"
            />
          </div>

          <div className="cvant-field mb-16">
            <span className="cvant-icon-wrap">
              <Icon icon="solar:user-linear" fontSize={20} />
            </span>
            <input
              type="text"
              className="form-control bg-neutral-50 radius-12 cvant-input"
              placeholder="Username"
              value={form.username}
              onChange={onChange("username")}
              autoComplete="username"
            />
          </div>

          <div className="cvant-field mb-16">
            <span className="cvant-icon-wrap">
              <Icon icon="solar:mailbox-linear" fontSize={20} />
            </span>
            <input
              type="email"
              className="form-control bg-neutral-50 radius-12 cvant-input"
              placeholder="nama@email.com"
              value={form.email}
              onChange={onChange("email")}
              autoComplete="email"
            />
          </div>

          <div className="cvant-field mb-16">
            <span className="cvant-icon-wrap">
              <Icon icon="solar:phone-calling-linear" fontSize={20} />
            </span>
            <input
              type="tel"
              className="form-control bg-neutral-50 radius-12 cvant-input"
              placeholder="08xxxxxxxxxx"
              value={form.phone}
              onChange={onChange("phone")}
              autoComplete="tel"
            />
          </div>

          <div className="cvant-field mb-16">
            <span className="cvant-icon-wrap">
              <Icon icon="solar:user-linear" fontSize={20} />
            </span>
            <select
              className="form-select bg-neutral-50 radius-12 cvant-input cvant-select"
              value={form.gender}
              onChange={onChange("gender")}
              aria-label="Jenis kelamin"
            >
              <option value="">Pilih jenis kelamin</option>
              <option value="Laki-laki">Laki-laki</option>
              <option value="Perempuan">Perempuan</option>
              <option value="Lainnya">Lainnya</option>
            </select>
            <span className="cvant-select-caret" aria-hidden="true">
              <Icon icon="solar:alt-arrow-down-linear" fontSize={18} />
            </span>
          </div>

          <div className="cvant-field mb-16">
            <span className="cvant-icon-wrap">
              <Icon icon="solar:calendar-outline" fontSize={20} />
            </span>
            <input
              type="date"
              className="form-control bg-neutral-50 radius-12 cvant-input"
              value={form.birthDate}
              onChange={onChange("birthDate")}
              autoComplete="bday"
            />
          </div>

          <div className="cvant-field mb-16">
            <span className="cvant-icon-wrap">
              <Icon icon="solar:map-point-linear" fontSize={20} />
            </span>
            <input
              type="text"
              className="form-control bg-neutral-50 radius-12 cvant-input"
              placeholder="Alamat lengkap"
              value={form.address}
              onChange={onChange("address")}
              autoComplete="street-address"
            />
          </div>

          <div className="cvant-field mb-16">
            <span className="cvant-icon-wrap">
              <Icon icon="solar:buildings-linear" fontSize={20} />
            </span>
            <input
              type="text"
              className="form-control bg-neutral-50 radius-12 cvant-input"
              placeholder="Nama kota"
              value={form.city}
              onChange={onChange("city")}
              autoComplete="address-level2"
            />
          </div>

          <div className="cvant-field mb-16">
            <span className="cvant-icon-wrap">
              <Icon icon="solar:buildings-linear" fontSize={20} />
            </span>
            <input
              type="text"
              className="form-control bg-neutral-50 radius-12 cvant-input"
              placeholder="Nama perusahaan"
              value={form.company}
              onChange={onChange("company")}
              autoComplete="organization"
            />
          </div>

          <div className="cvant-field mb-16">
            <span className="cvant-icon-wrap">
              <Icon icon="solar:lock-password-outline" fontSize={20} />
            </span>
            <input
              type={showPassword ? "text" : "password"}
              className="form-control bg-neutral-50 radius-12 cvant-input"
              placeholder="Password"
              value={form.password}
              onChange={onChange("password")}
              autoComplete="new-password"
              style={{ paddingRight: "58px" }}
            />
            <button
              type="button"
              className="cvant-eye-btn"
              onClick={() => setShowPassword((value) => !value)}
              aria-label={showPassword ? "Hide password" : "Show password"}
            >
              <Icon
                icon={
                  showPassword ? "solar:eye-closed-linear" : "solar:eye-linear"
                }
                fontSize={20}
                style={{ color: "#6b7280" }}
              />
            </button>
          </div>

          <div className="cvant-field mb-18">
            <span className="cvant-icon-wrap">
              <Icon icon="solar:lock-password-outline" fontSize={20} />
            </span>
            <input
              type={showPassword ? "text" : "password"}
              className="form-control bg-neutral-50 radius-12 cvant-input"
              placeholder="Konfirmasi password"
              value={form.confirmPassword}
              onChange={onChange("confirmPassword")}
              autoComplete="new-password"
              style={{ paddingRight: "58px" }}
            />
          </div>

          <button
            type="submit"
            className="btn text-sm btn-sm px-12 py-16 w-100 radius-12 mt-5 cvant-login-btn"
            disabled={loading}
          >
            {loading ? "Mendaftar..." : "Daftar"}
          </button>

          <div className="mt-3 text-center text-m">
            <p className="mb-0 text-neutral-400">
              Sudah punya akun?{" "}
              <Link href="/sign-in" className="text-primary-600 fw-semibold">
                Masuk di sini
              </Link>
            </p>
          </div>
        </form>
      </AuthShell>
    </>
  );
};

export default CustomerSignUpLayer;
