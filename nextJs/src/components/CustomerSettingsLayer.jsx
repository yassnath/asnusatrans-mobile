"use client";

import { useEffect, useState } from "react";
import { customerApi } from "@/lib/customerApi";

const CustomerSettingsLayer = () => {
  const [profileForm, setProfileForm] = useState({
    name: "",
    email: "",
    phone: "",
    company: "",
    address: "",
    city: "",
  });
  const [passwordForm, setPasswordForm] = useState({
    currentPassword: "",
    newPassword: "",
    confirmPassword: "",
  });
  const [profileMsg, setProfileMsg] = useState(null);
  const [passwordMsg, setPasswordMsg] = useState(null);
  const [savingProfile, setSavingProfile] = useState(false);
  const [savingPassword, setSavingPassword] = useState(false);

  useEffect(() => {
    const loadProfile = async () => {
      try {
        const res = await customerApi.get("/customer/me");
        const customer = res?.customer;
        if (!customer) return;
        setProfileForm({
          name: customer.name || "",
          email: customer.email || "",
          phone: customer.phone || "",
          company: customer.company || "",
          address: customer.address || "",
          city: customer.city || "",
        });
      } catch {
        // ignore
      }
    };

    loadProfile();
  }, []);

  const onProfileChange = (field) => (event) => {
    setProfileMsg(null);
    setProfileForm((prev) => ({ ...prev, [field]: event.target.value }));
  };

  const onPasswordChange = (field) => (event) => {
    setPasswordMsg(null);
    setPasswordForm((prev) => ({ ...prev, [field]: event.target.value }));
  };

  const handleProfileSubmit = async (event) => {
    event.preventDefault();
    setProfileMsg(null);

    if (!profileForm.name || !profileForm.email) {
      setProfileMsg({ type: "error", text: "Nama dan email wajib diisi." });
      return;
    }

    setSavingProfile(true);

    try {
      const res = await customerApi.put("/customer/profile", {
        name: profileForm.name.trim(),
        email: profileForm.email.trim().toLowerCase(),
        phone: profileForm.phone.trim(),
        company: profileForm.company.trim(),
        address: profileForm.address.trim(),
        city: profileForm.city.trim(),
      });

      const updated = res?.customer;
      if (updated) {
        localStorage.setItem("cvant_customer_user", JSON.stringify(updated));
      }

      setProfileMsg({ type: "success", text: "Profil berhasil diperbarui." });
    } catch (err) {
      setProfileMsg({
        type: "error",
        text: err?.message || "Gagal memperbarui profil.",
      });
    } finally {
      setSavingProfile(false);
    }
  };

  const handlePasswordSubmit = async (event) => {
    event.preventDefault();
    setPasswordMsg(null);

    if (!passwordForm.currentPassword || !passwordForm.newPassword) {
      setPasswordMsg({ type: "error", text: "Lengkapi data password." });
      return;
    }

    if (passwordForm.newPassword.length < 6) {
      setPasswordMsg({ type: "error", text: "Password minimal 6 karakter." });
      return;
    }

    if (passwordForm.newPassword !== passwordForm.confirmPassword) {
      setPasswordMsg({ type: "error", text: "Konfirmasi password tidak sama." });
      return;
    }

    setSavingPassword(true);

    try {
      await customerApi.put("/customer/password", {
        current_password: passwordForm.currentPassword,
        password: passwordForm.newPassword,
        password_confirmation: passwordForm.confirmPassword,
      });
      setPasswordForm({ currentPassword: "", newPassword: "", confirmPassword: "" });
      setPasswordMsg({ type: "success", text: "Password berhasil diperbarui." });
    } catch (err) {
      setPasswordMsg({
        type: "error",
        text: err?.message || "Gagal memperbarui password.",
      });
    } finally {
      setSavingPassword(false);
    }
  };

  return (
    <div className="container-fluid py-4">
      <div className="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-4">
        <div>
          <h4 className="mb-1">Settings</h4>
          <p className="text-secondary-light mb-0">
            Perbarui profil dan keamanan akun Anda.
          </p>
        </div>
      </div>

      <div className="row g-4">
        <div className="col-lg-7">
          <div className="card shadow-sm border-0">
            <div className="card-header bg-transparent">
              <h6 className="mb-0">Profil Customer</h6>
            </div>
            <div className="card-body">
              {profileMsg && (
                <div
                  className={`alert ${
                    profileMsg.type === "success" ? "alert-success" : "alert-danger"
                  }`}
                >
                  {profileMsg.text}
                </div>
              )}

              <form onSubmit={handleProfileSubmit}>
                <div className="row g-3">
                  <div className="col-md-6">
                    <label className="form-label fw-semibold">Username</label>
                    <input
                      className="form-control"
                      value={profileForm.name}
                      onChange={onProfileChange("name")}
                    />
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-semibold">Email</label>
                    <input
                      type="email"
                      className="form-control"
                      value={profileForm.email}
                      onChange={onProfileChange("email")}
                    />
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-semibold">Nomor HP</label>
                    <input
                      className="form-control"
                      value={profileForm.phone}
                      onChange={onProfileChange("phone")}
                    />
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-semibold">Perusahaan</label>
                    <input
                      className="form-control"
                      value={profileForm.company}
                      onChange={onProfileChange("company")}
                    />
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-semibold">Alamat</label>
                    <input
                      className="form-control"
                      value={profileForm.address}
                      onChange={onProfileChange("address")}
                    />
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-semibold">Kota</label>
                    <input
                      className="form-control"
                      value={profileForm.city}
                      onChange={onProfileChange("city")}
                    />
                  </div>
                </div>

                <div className="d-flex justify-content-end mt-4">
                  <button
                    type="submit"
                    className="btn btn-primary px-24"
                    disabled={savingProfile}
                  >
                    {savingProfile ? "Menyimpan..." : "Simpan Perubahan"}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>

        <div className="col-lg-5">
          <div className="card shadow-sm border-0">
            <div className="card-header bg-transparent">
              <h6 className="mb-0">Ganti Password</h6>
            </div>
            <div className="card-body">
              {passwordMsg && (
                <div
                  className={`alert ${
                    passwordMsg.type === "success" ? "alert-success" : "alert-danger"
                  }`}
                >
                  {passwordMsg.text}
                </div>
              )}

              <form onSubmit={handlePasswordSubmit}>
                <div className="mb-3">
                  <label className="form-label fw-semibold">Password Lama</label>
                  <input
                    type="password"
                    className="form-control"
                    value={passwordForm.currentPassword}
                    onChange={onPasswordChange("currentPassword")}
                  />
                </div>
                <div className="mb-3">
                  <label className="form-label fw-semibold">Password Baru</label>
                  <input
                    type="password"
                    className="form-control"
                    value={passwordForm.newPassword}
                    onChange={onPasswordChange("newPassword")}
                  />
                </div>
                <div className="mb-3">
                  <label className="form-label fw-semibold">
                    Konfirmasi Password
                  </label>
                  <input
                    type="password"
                    className="form-control"
                    value={passwordForm.confirmPassword}
                    onChange={onPasswordChange("confirmPassword")}
                  />
                </div>

                <button
                  type="submit"
                  className="btn btn-primary w-100"
                  disabled={savingPassword}
                >
                  {savingPassword ? "Memperbarui..." : "Update Password"}
                </button>
              </form>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default CustomerSettingsLayer;
