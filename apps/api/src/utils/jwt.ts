import jwt from "jsonwebtoken";
import { env } from "../config/env";
import { UserRole } from "../types";

type JwtPayload = {
  sub: string;
  role: UserRole;
  email: string;
};

export function createAccessToken(payload: JwtPayload) {
  return jwt.sign(payload, env.accessSecret, { expiresIn: env.accessTtl });
}

export function verifyAccessToken(token: string) {
  return jwt.verify(token, env.accessSecret) as JwtPayload;
}
