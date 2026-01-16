// nextJs/src/lib/api.js

let API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080";

// ✅ Hapus trailing slash jika ada
API_URL = API_URL.replace(/\/+$/, "");

/**
 * Semua request otomatis menuju:
 *   `${API_URL}/api/...`
 */
const buildUrl = (url) => {
  const path = url.startsWith("/") ? url : `/${url}`;
  return `${API_URL}/api${path}`;
};

const getToken = () => {
  if (typeof window === "undefined") return null;
  return localStorage.getItem("token");
};

const setToken = (token) => {
  if (typeof window === "undefined") return;
  if (!token) return;
  localStorage.setItem("token", token);

  // ✅ cookie untuk middleware Next (optional)
  document.cookie = `token=${token}; path=/; SameSite=Lax;`;
};

const clearToken = () => {
  if (typeof window === "undefined") return;
  localStorage.removeItem("token");
  localStorage.removeItem("user");
  localStorage.removeItem("role");
  localStorage.removeItem("username");

  // delete cookie token
  document.cookie =
    "token=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT; SameSite=Lax;";
};

const defaultHeaders = () => {
  const token = getToken();
  return {
    "Content-Type": "application/json",
    Accept: "application/json",
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };
};

async function handleResponse(res) {
  const text = await res.text();

  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }

  // ✅ Jika token invalid / expired → auto logout
  if (res.status === 401) {
    clearToken();
    if (typeof window !== "undefined") {
      window.location.href = "/login";
    }
    throw new Error("Unauthorized. Please login again.");
  }

  if (!res.ok) {
    const msg =
      (data && (data.message || data.error)) ||
      `Request failed with status ${res.status}`;
    throw new Error(msg);
  }

  return data;
}

export const api = {
  // ✅ expose supaya auth.js bisa set token
  setToken,
  clearToken,

  get: async (url) => {
    const res = await fetch(buildUrl(url), {
      method: "GET",
      headers: defaultHeaders(),
    });
    return handleResponse(res);
  },

  post: async (url, body) => {
    const res = await fetch(buildUrl(url), {
      method: "POST",
      headers: defaultHeaders(),
      body: JSON.stringify(body),
    });
    return handleResponse(res);
  },

  put: async (url, body) => {
    const res = await fetch(buildUrl(url), {
      method: "PUT",
      headers: defaultHeaders(),
      body: JSON.stringify(body),
    });
    return handleResponse(res);
  },
  patch: async (url, body) => {
    const res = await fetch(buildUrl(url), {
      method: "PATCH",
      headers: defaultHeaders(),
      body: JSON.stringify(body),
    });
    return handleResponse(res);
  },

  delete: async (url) => {
    const res = await fetch(buildUrl(url), {
      method: "DELETE",
      headers: defaultHeaders(),
    });
    return handleResponse(res);
  },
};
