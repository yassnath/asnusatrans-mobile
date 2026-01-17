"use client";

let API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080";

API_URL = API_URL.replace(/\/+$/, "");

const buildUrl = (url) => {
  const path = url.startsWith("/") ? url : `/${url}`;
  return `${API_URL}/api${path}`;
};

const parseResponse = async (res) => {
  const text = await res.text();
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
};

const getToken = () => {
  if (typeof window === "undefined") return null;
  return localStorage.getItem("cvant_customer_token");
};

const clearToken = () => {
  if (typeof window === "undefined") return;
  localStorage.removeItem("cvant_customer_token");
  localStorage.removeItem("cvant_customer_user");
  document.cookie =
    "customer_token=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT; SameSite=Lax;";
};

const defaultHeaders = () => {
  const token = getToken();
  return {
    "Content-Type": "application/json",
    Accept: "application/json",
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };
};

const handleResponse = async (res) => {
  const data = await parseResponse(res);

  if (res.status === 401) {
    clearToken();
    if (typeof window !== "undefined") {
      window.location.href = "/sign-in";
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
};

export const customerApi = {
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
};
