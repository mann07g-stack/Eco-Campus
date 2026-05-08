import express from "express";
import cors from "cors";
import morgan from "morgan";
import { env, validateEnv } from "./config/env";
import { connectDb } from "./config/db";
import { authRouter } from "./routes/auth";
import { requestRouter } from "./routes/requests";
import { adminRouter } from "./routes/admin";
import { memberRouter } from "./routes/member";

function normalizeOrigin(origin: string) {
  return origin.replace(/\/+$/, "");
}

function buildAllowedOrigins() {
  return new Set(
    [
      env.clientUrl,
      ...env.clientUrls,
      "http://localhost:5173",
      "http://127.0.0.1:5173"
    ].map(normalizeOrigin)
  );
}

async function createApp() {
  validateEnv();
  await connectDb();

  const app = express();
  const allowedOrigins = buildAllowedOrigins();

  app.use(
    cors({
      origin(origin, callback) {
        const normalizedOrigin = origin ? normalizeOrigin(origin) : "";

        if (!origin || allowedOrigins.has(normalizedOrigin) || /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(normalizedOrigin)) {
          return callback(null, true);
        }

        return callback(new Error(`CORS blocked for origin: ${origin}`));
      },
      credentials: true
    })
  );
  app.use(express.json({ limit: "5mb" }));
  app.use(morgan("dev", { skip: (req) => req.method === "OPTIONS" }));

  app.get("/api/health", (_req, res) => {
    res.json({ status: "ok", service: "eco-campus-api" });
  });

  app.use("/api/auth", authRouter);
  app.use("/api/requests", requestRouter);
  app.use("/api/admin", adminRouter);
  app.use("/api/member", memberRouter);

  app.use((_req, res) => {
    res.status(404).json({ message: "Route not found" });
  });

  return app;
}

let appPromise: Promise<express.Express> | null = null;

function getApp() {
  if (!appPromise) {
    appPromise = createApp();
  }

  return appPromise;
}

async function handler(req: express.Request, res: express.Response) {
  const app = await getApp();
  return app(req, res);
}

if (!process.env.VERCEL) {
  void getApp()
    .then((app) => {
      app.listen(env.port, () => {
        // eslint-disable-next-line no-console
        console.log(`API running on http://localhost:${env.port}`);
      });
    })
    .catch((error) => {
      // eslint-disable-next-line no-console
      console.error(error);
      process.exit(1);
    });
}

export = handler;
