import { NextFunction, Request, Response } from "express";
import { Ratelimit } from "@upstash/ratelimit";
import { Redis } from "@upstash/redis";

import { env } from "../config/env";

type RateLimitOptions = {
  prefix: string;
  limit: number;
  window: string;
};

const hasUpstashConfig = Boolean(env.upstashRedisRestUrl && env.upstashRedisRestToken);

const redis = hasUpstashConfig
  ? new Redis({
      url: env.upstashRedisRestUrl,
      token: env.upstashRedisRestToken
    })
  : null;

function getClientIdentifier(req: Request) {
  const forwardedFor = req.headers["x-forwarded-for"];

  if (typeof forwardedFor === "string" && forwardedFor.trim()) {
    return forwardedFor.split(",")[0].trim();
  }

  return req.ip || req.socket.remoteAddress || "anonymous";
}

export function createRateLimiter({ prefix, limit, window }: RateLimitOptions) {
  if (!redis) {
    return (_req: Request, _res: Response, next: NextFunction) => next();
  }

  const ratelimit = new Ratelimit({
    redis,
    // cast window to any to satisfy type differences between versions
    limiter: Ratelimit.slidingWindow(limit, window as any),
    analytics: true,
    prefix
  });

  return async (req: Request, res: Response, next: NextFunction) => {
    const identifier = `${prefix}:${getClientIdentifier(req)}`;
    const result = await ratelimit.limit(identifier);

    res.setHeader("X-RateLimit-Limit", String(limit));
    res.setHeader("X-RateLimit-Remaining", String(result.remaining));
    res.setHeader("X-RateLimit-Reset", String(result.reset));

    if (!result.success) {
      return res.status(429).json({
        message: "Too many requests. Please try again later."
      });
    }

    return next();
  };
}
