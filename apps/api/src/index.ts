import express from "express";
import cors from "cors";
import morgan from "morgan";
import { env, validateEnv } from "./config/env";
import { connectDb } from "./config/db";
import { authRouter } from "./routes/auth";
import { requestRouter } from "./routes/requests";
import { adminRouter } from "./routes/admin";
import { memberRouter } from "./routes/member";

async function bootstrap() {
  validateEnv();
  await connectDb();

  const app = express();

  const allowedOrigins = new Set([
    env.clientUrl,
    "http://localhost:5173",
    "http://127.0.0.1:5173"
  ]);

  app.use(
    cors({
      origin(origin, callback) {
        if (!origin || allowedOrigins.has(origin) || /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) {
          return callback(null, true);
        }

        return callback(new Error(`CORS blocked for origin: ${origin}`));
      },
      credentials: true
    })
  );
  app.use(express.json({ limit: "5mb" }));
  app.use(morgan("dev"));

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

  app.listen(env.port, () => {
    // eslint-disable-next-line no-console
    console.log(`API running on http://localhost:${env.port}`);
  });
}

bootstrap().catch((error) => {
  // eslint-disable-next-line no-console
  console.error(error);
  process.exit(1);
});
