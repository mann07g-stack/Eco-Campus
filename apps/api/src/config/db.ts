import mongoose from "mongoose";
import { env } from "./env";

export async function connectDb() {
  await mongoose.connect(env.mongodbUri, { dbName: env.mongodbDbName });
  // eslint-disable-next-line no-console
  console.log("MongoDB connected");
}
