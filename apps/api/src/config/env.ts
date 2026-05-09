import dotenv from "dotenv";

dotenv.config();

function trimTrailingSlash(value: string) {
  return value.replace(/\/+$/, "");
}

function parseCsv(value: string) {
  return value
    .split(",")
    .map((entry) => trimTrailingSlash(entry.trim()))
    .filter(Boolean);
}

export const env = {
  port: Number(process.env.PORT || 5000),
  mongodbUri: process.env.MONGODB_URI || "",
  mongodbDbName: process.env.MONGODB_DB_NAME || "eco_campus",
  accessSecret: process.env.JWT_ACCESS_SECRET || "",
  refreshSecret: process.env.JWT_REFRESH_SECRET || "",
  accessTtl: process.env.ACCESS_TOKEN_TTL || "15m",
  refreshTtl: process.env.REFRESH_TOKEN_TTL || "7d",
  clientUrl: trimTrailingSlash(process.env.CLIENT_URL || "http://localhost:5173"),
  clientUrls: parseCsv(process.env.CLIENT_URLS || ""),
  upstashRedisRestUrl: process.env.UPSTASH_REDIS_REST_URL || "",
  upstashRedisRestToken: process.env.UPSTASH_REDIS_REST_TOKEN || ""
};

export function validateEnv() {
  const missing: string[] = [];

  if (!env.mongodbUri) missing.push("MONGODB_URI");
  if (!env.accessSecret) missing.push("JWT_ACCESS_SECRET");
  if (!env.refreshSecret) missing.push("JWT_REFRESH_SECRET");

  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(", ")}`);
  }
}
