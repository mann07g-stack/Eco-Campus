import jwt from "jsonwebtoken";
import { env } from "../config/env";

type QrPayload = {
  requestId: string;
  userId: string;
  agreedQuote: number;
  tokenId: string;
};

export function signQrPayload(payload: QrPayload) {
  return jwt.sign(payload, env.accessSecret, { expiresIn: "2d" });
}

export function verifyQrPayload(token: string) {
  return jwt.verify(token, env.accessSecret) as QrPayload;
}
