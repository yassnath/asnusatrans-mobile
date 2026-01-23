let API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080";

API_URL = API_URL.replace(/\/+$/, "");

const buildUrl = (url) => {
  const path = url.startsWith("/") ? url : `/${url}`;
  if (API_URL.endsWith("/api")) {
    return `${API_URL}${path}`;
  }
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

export const publicApi = {
  get: async (url) => {
    const res = await fetch(buildUrl(url), {
      method: "GET",
      headers: {
        Accept: "application/json",
      },
    });

    const data = await parseResponse(res);
    if (!res.ok) {
      const msg =
        (data && (data.message || data.error)) ||
        `Request failed with status ${res.status}`;
      throw new Error(msg);
    }

    return data;
  },
  post: async (url, body) => {
    const res = await fetch(buildUrl(url), {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    const data = await parseResponse(res);
    if (!res.ok) {
      const msg =
        (data && (data.message || data.error)) ||
        `Request failed with status ${res.status}`;
      throw new Error(msg);
    }

    return data;
  },
};
