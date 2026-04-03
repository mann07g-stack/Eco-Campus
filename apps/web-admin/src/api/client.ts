import axios from "axios";

export const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || "http://localhost:5000/api"
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
