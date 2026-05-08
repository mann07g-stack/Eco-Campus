import axios from "axios";

export const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || "http://localhost:5000/api",
  timeout: 20000
});

export function describeApiError(error: unknown, fallback: string) {
  if (!axios.isAxiosError(error)) {
    return fallback;
  }

  const status = error.response?.status;
  if (!status) {
    if (error.code === "ECONNABORTED") {
      return "The API is taking longer than usual to respond. Retry in a few seconds.";
    }

    return "The API is unreachable right now. Check the deployment and try again.";
  }

  if (status === 401) {
    return "Your admin session is invalid or expired. Sign in again.";
  }

  if (status === 403) {
    return "You do not have permission for that action.";
  }

  if (status === 404) {
    return "The requested API route was not found.";
  }

  if (status === 429) {
    return "The API is rate-limiting requests. Retry shortly.";
  }

  if (status >= 500) {
    return "The API is temporarily unavailable. It may still be waking up.";
  }

  const responseMessage = error.response?.data as { message?: unknown } | undefined;
  if (typeof responseMessage?.message === "string" && responseMessage.message.trim()) {
    return responseMessage.message;
  }

  return fallback;
}

const authTokenKey = "eco-campus-admin-token";

export function getAuthToken() {
  return localStorage.getItem(authTokenKey) || "";
}

export function setAuthToken(token: string) {
  localStorage.setItem(authTokenKey, token);
  api.defaults.headers.common.Authorization = `Bearer ${token}`;
}

export function clearAuthToken() {
  localStorage.removeItem(authTokenKey);
  delete api.defaults.headers.common.Authorization;
}

const savedToken = getAuthToken();
if (savedToken) {
  api.defaults.headers.common.Authorization = `Bearer ${savedToken}`;
}

api.interceptors.request.use((config) => {
  const token = getAuthToken();

  if (token) {
    config.headers = config.headers ?? {};
    config.headers.Authorization = `Bearer ${token}`;
  }

  return config;
});

api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const config = error.config as (typeof error.config & { __retryCount?: number }) | undefined;
    if (!config) throw error;

    const method = String(config.method || "get").toLowerCase();
    const status = error.response?.status;
    const retryableStatus = status === 429 || status === 502 || status === 503 || status === 504;
    const networkIssue = !error.response;
    const shouldRetry = method === "get" && (retryableStatus || networkIssue);

    if (!shouldRetry) throw error;

    const retries = Number(config.__retryCount || 0);
    if (retries >= 1) throw error;

    config.__retryCount = retries + 1;
    await new Promise((resolve) => setTimeout(resolve, 600));
    return api.request(config);
  }
);

export type OverviewResponse = {
  totalRequests: number;
  collected: number;
  users: number;
  members: number;
  byStatus: { _id: string; count: number }[];
};

export type MemberPayload = {
  fullName: string;
  email: string;
  phone: string;
  campusId: string;
  department: string;
  password: string;
};

export type LoginResponse = {
  accessToken: string;
  user: {
    id: string;
    fullName: string;
    email: string;
    role: string;
    campusId: string;
  };
};
