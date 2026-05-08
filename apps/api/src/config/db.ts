import mongoose from "mongoose";
import { env } from "./env";

let connectionPromise: Promise<typeof mongoose> | null = null;

export async function connectDb() {
  if (!connectionPromise) {
    connectionPromise = mongoose.connect(env.mongodbUri, { dbName: env.mongodbDbName });
  }

  await connectionPromise;

  // eslint-disable-next-line no-console
  console.log("MongoDB connected");
}
