import { Router } from "express";
import bcrypt from "bcryptjs";
import { z } from "zod";
import { UserModel } from "../models/User";
import { createAccessToken } from "../utils/jwt";
import { createRateLimiter } from "../middleware/rateLimiter";

const registerSchema = z.object({
  fullName: z.string().min(2),
  email: z.string().email(),
  phone: z.string().min(5),
  campusId: z.string().min(2),
  department: z.string().optional().default(""),
  password: z.string().min(6)
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6)
});

export const authRouter = Router();

const authWriteLimiter = createRateLimiter({ prefix: "auth-write", limit: 10, window: "1 m" });

authRouter.post("/register-user", authWriteLimiter, async (req, res) => {
  const parsed = registerSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: parsed.error.flatten() });
  }

  const exists = await UserModel.findOne({ email: parsed.data.email.toLowerCase() });
  if (exists) {
    return res.status(409).json({ message: "Email already exists" });
  }

  const passwordHash = await bcrypt.hash(parsed.data.password, 10);
  const user = await UserModel.create({
    ...parsed.data,
    email: parsed.data.email.toLowerCase(),
    passwordHash,
    role: "USER"
  });

  return res.status(201).json({
    message: "User registered",
    user: {
      id: user._id,
      fullName: user.fullName,
      email: user.email,
      role: user.role
    }
  });
});

authRouter.post("/login", authWriteLimiter, async (req, res) => {
  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: parsed.error.flatten() });
  }

  const user = await UserModel.findOne({ email: parsed.data.email.toLowerCase() });
  if (!user) {
    return res.status(401).json({ message: "Invalid credentials" });
  }

  const ok = await bcrypt.compare(parsed.data.password, user.passwordHash);
  if (!ok) {
    return res.status(401).json({ message: "Invalid credentials" });
  }

  const accessToken = createAccessToken({
    sub: String(user._id),
    email: user.email,
    role: user.role
  });

  return res.json({
    accessToken,
    user: {
      id: user._id,
      fullName: user.fullName,
      email: user.email,
      role: user.role,
      campusId: user.campusId
    }
  });
});
