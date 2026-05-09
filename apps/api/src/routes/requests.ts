import { Router } from "express";
import { z } from "zod";
import { requireAuth, requireRole, AuthRequest } from "../middleware/auth";
import { RequestModel } from "../models/Request";
import { NegotiationModel } from "../models/Negotiation";
import { QrTokenModel } from "../models/QrToken";
import { UserModel } from "../models/User";
import { signQrPayload } from "../utils/qr";
import { createRateLimiter } from "../middleware/rateLimiter";

const createRequestSchema = z.object({
  imageUrl: z.string().min(1).optional(),
  imageUrls: z.array(z.string().min(1)).min(1).optional().default([]),
  description: z.string().min(5),
  categoriesDetected: z.array(z.string()).optional().default([])
}).refine((value) => Boolean(value.imageUrl || value.imageUrls.length > 0), {
  message: "At least one photo is required"
});

const quoteSchema = z.object({
  amount: z.number().positive(),
  message: z.string().optional().default("")
});

const counterSchema = z.object({
  amount: z.number().positive(),
  message: z.string().optional().default("")
});

const cancelSchema = z.object({
  reason: z.string().optional().default("Cancelled by user")
});

export const requestRouter = Router();

const requestCreateLimiter = createRateLimiter({ prefix: "request-create", limit: 5, window: "1 m" });

requestRouter.post("/", requestCreateLimiter, requireAuth, requireRole("USER"), async (req: AuthRequest, res) => {
  const parsed = createRequestSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: parsed.error.flatten() });
  }

  const user = await UserModel.findById(req.user!.id);
  if (!user) {
    return res.status(404).json({ message: "User not found" });
  }

  const request = await RequestModel.create({
    userId: req.user!.id,
    campusId: user.campusId,
    imageUrl: parsed.data.imageUrl || parsed.data.imageUrls[0],
    imageUrls: parsed.data.imageUrls.length > 0 ? parsed.data.imageUrls : parsed.data.imageUrl ? [parsed.data.imageUrl] : [],
    description: parsed.data.description,
    categoriesDetected: parsed.data.categoriesDetected,
    adminQuote: 0,
    adminQuoteMessage: "",
    lastUserCounterMessage: "",
    quotePendingForUser: false,
    status: "SUBMITTED"
  });

  return res.status(201).json({ request });
});

requestRouter.get("/my", requireAuth, async (req: AuthRequest, res) => {
  const query = req.user!.role === "USER" ? { userId: req.user!.id } : {};
  const requests = await RequestModel.find(query)
    .sort({ createdAt: -1 })
    .populate("assignedMemberId", "fullName phone campusId")
    .lean();
  return res.json({ requests });
});

requestRouter.get("/:id", requireAuth, async (req: AuthRequest, res) => {
  const request = await RequestModel.findById(req.params.id);
  if (!request) {
    return res.status(404).json({ message: "Request not found" });
  }

  if (req.user!.role === "USER" && String(request.userId) !== req.user!.id) {
    return res.status(403).json({ message: "Forbidden" });
  }

  const negotiation = await NegotiationModel.find({ requestId: request._id }).sort({ createdAt: 1 });
  return res.json({ request, negotiation });
});

requestRouter.patch("/:id/quote", requireAuth, requireRole("ADMIN"), async (req: AuthRequest, res) => {
  const parsed = quoteSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: parsed.error.flatten() });
  }

  const request = await RequestModel.findById(req.params.id);
  if (!request) {
    return res.status(404).json({ message: "Request not found" });
  }

  if (["AGREED", "QR_ISSUED", "COLLECTED", "CANCELLED"].includes(request.status)) {
    return res.status(400).json({ message: "Request is no longer open for admin quote" });
  }

  request.currentQuote = parsed.data.amount;
  request.adminQuote = parsed.data.amount;
  request.adminQuoteMessage = parsed.data.message;
  request.quotePendingForUser = true;
  request.status = request.status === "SUBMITTED" ? "QUOTED" : "BARGAINING";
  await request.save();

  await NegotiationModel.create({
    requestId: request._id,
    senderRole: "ADMIN",
    senderId: req.user!.id,
    offeredAmount: parsed.data.amount,
    message: parsed.data.message
  });

  return res.json({ request });
});

requestRouter.patch("/:id/counter-offer", requireAuth, requireRole("USER"), async (req: AuthRequest, res) => {
  const parsed = counterSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: parsed.error.flatten() });
  }

  const request = await RequestModel.findById(req.params.id);
  if (!request) {
    return res.status(404).json({ message: "Request not found" });
  }

  if (String(request.userId) !== req.user!.id) {
    return res.status(403).json({ message: "Forbidden" });
  }

  if (!["QUOTED", "BARGAINING"].includes(request.status)) {
    return res.status(400).json({ message: "Counter offer is allowed only after admin quote" });
  }

  request.currentQuote = parsed.data.amount;
  request.lastUserCounterMessage = parsed.data.message;
  request.quotePendingForUser = false;
  request.status = "BARGAINING";
  await request.save();

  await NegotiationModel.create({
    requestId: request._id,
    senderRole: "USER",
    senderId: req.user!.id,
    offeredAmount: parsed.data.amount,
    message: parsed.data.message
  });

  return res.json({ request });
});

requestRouter.patch("/:id/accept-quote", requireAuth, requireRole("USER"), async (req: AuthRequest, res) => {
  const request = await RequestModel.findById(req.params.id);
  if (!request) {
    return res.status(404).json({ message: "Request not found" });
  }

  if (String(request.userId) !== req.user!.id) {
    return res.status(403).json({ message: "Forbidden" });
  }

  if (!["QUOTED", "BARGAINING"].includes(request.status)) {
    return res.status(400).json({ message: "Request is not ready for acceptance" });
  }

  if (!request.quotePendingForUser) {
    return res.status(400).json({ message: "Awaiting updated admin quote before acceptance" });
  }

  request.status = "AGREED";
  request.agreedQuote = request.adminQuote || request.currentQuote;
  request.quotePendingForUser = false;
  request.agreedAt = new Date();
  await request.save();

  return res.json({ request });
});

requestRouter.patch("/:id/cancel", requireAuth, requireRole("USER"), async (req: AuthRequest, res) => {
  const parsed = cancelSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: parsed.error.flatten() });
  }

  const request = await RequestModel.findById(req.params.id);
  if (!request) {
    return res.status(404).json({ message: "Request not found" });
  }

  if (String(request.userId) !== req.user!.id) {
    return res.status(403).json({ message: "Forbidden" });
  }

  if (["COLLECTED", "CANCELLED", "AGREED", "QR_ISSUED"].includes(request.status)) {
    return res.status(400).json({ message: "This request cannot be cancelled" });
  }

  request.status = "CANCELLED";
  request.quotePendingForUser = false;
  await request.save();

  await NegotiationModel.create({
    requestId: request._id,
    senderRole: "USER",
    senderId: req.user!.id,
    offeredAmount: request.currentQuote || 0,
    message: parsed.data.reason
  });

  return res.json({ request, message: "Request cancelled" });
});

requestRouter.get("/:id/qr", requireAuth, requireRole("USER"), async (req: AuthRequest, res) => {
  const request = await RequestModel.findById(req.params.id);
  if (!request) {
    return res.status(404).json({ message: "Request not found" });
  }

  if (String(request.userId) !== req.user!.id) {
    return res.status(403).json({ message: "Forbidden" });
  }

  if (request.status !== "AGREED" && request.status !== "QR_ISSUED") {
    return res.status(400).json({ message: "Request must be agreed first" });
  }

  let tokenDoc = await QrTokenModel.findOne({ requestId: request._id });
  if (!tokenDoc) {
    tokenDoc = await QrTokenModel.create({
      requestId: request._id,
      tokenHash: `qr-${request._id}`,
      expiresAt: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000),
      isUsed: false
    });
  }

  if (!request.assignedMemberId) {
    const assignedMember = await UserModel.findOne({
      role: "MEMBER",
      isActive: true,
      campusId: request.campusId
    }).sort({ createdAt: 1 });

    if (!assignedMember) {
      return res.status(400).json({
        message: "No active member is available for this campus right now"
      });
    }

    request.assignedMemberId = String(assignedMember._id) as any;
    request.assignedAt = new Date();
  }

  const qrToken = signQrPayload({
    requestId: String(request._id),
    userId: String(request.userId),
    agreedQuote: request.agreedQuote,
    tokenId: String(tokenDoc._id)
  });

  request.status = "QR_ISSUED";
  request.qrTokenId = String(tokenDoc._id) as any;
  await request.save();

  const assignedMember = request.assignedMemberId
    ? await UserModel.findById(request.assignedMemberId).select("fullName phone campusId")
    : null;

  return res.json({
    qrToken,
    requestId: request._id,
    agreedQuote: request.agreedQuote,
    collector: assignedMember
      ? {
          fullName: assignedMember.fullName,
          phone: assignedMember.phone,
          campusId: assignedMember.campusId
        }
      : null
  });
});
