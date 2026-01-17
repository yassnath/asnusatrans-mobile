// nextJs/src/lib/auth.js
import { api } from "@/lib/api";

export async function loginRequest(username, password) {
  const res = await api.post("/login", { username, password });

  const { token, user } = res || {};

  if (!token || !user) {
    throw new Error("Login failed. Username / password tidak valid.");
  }

  // ✅ Simpan token memakai helper dari api.js (biar konsisten)
  api.setToken(token);

  // ✅ Simpan data user
  localStorage.setItem("user", JSON.stringify(user));
  localStorage.setItem("role", user.role || "");
  localStorage.setItem("username", user.username || "");

  return res;
}

export async function me() {
  try {
    const data = await api.get("/me");
    return data;
  } catch {
    return { authenticated: false };
  }
}

export async function logoutRequest() {
  try {
    await api.post("/logout", {});
  } catch {
    // ignore error
  } finally {
    api.clearToken();
    window.location.href = "/sign-in";
  }
}
