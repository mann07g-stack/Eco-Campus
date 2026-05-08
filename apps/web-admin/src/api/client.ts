import axios from "axios";

export const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || "http://localhost:5000/api",
  timeout: 20000
});

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
