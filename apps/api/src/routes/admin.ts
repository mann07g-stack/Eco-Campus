import { Router } from "express";
import bcrypt from "bcryptjs";
import { z } from "zod";
import { requireAuth, requireRole } from "../middleware/auth";
import { UserModel } from "../models/User";
import { RequestModel } from "../models/Request";
import { NegotiationModel } from "../models/Negotiation";

const createMemberSchema = z.object({
  fullName: z.string().min(2),
  email: z.string().email(),
  phone: z.string().min(5),
  campusId: z.string().min(2),
  department: z.string().optional().default(""),
  password: z.string().min(6)
});

const quoteSchema = z.object({
  amount: z.number().positive(),
  message: z.string().optional().default("")
});

const rejectSchema = z.object({
  reason: z.string().optional().default("Rejected by admin")
});

export const adminRouter = Router();

adminRouter.use(requireAuth, requireRole("ADMIN"));

adminRouter.get("/requests", async (_req, res) => {
  const requests = await RequestModel.find()
    .sort({ createdAt: -1 })
    .populate("userId", "fullName email phone campusId")
    .lean();

  const requestsWithNegotiation = await Promise.all(
    requests.map(async (request) => {
      const latestNegotiation = await NegotiationModel.findOne({ requestId: request._id })
        .sort({ createdAt: -1 })
        .lean();

      const negotiationCount = await NegotiationModel.countDocuments({ requestId: request._id });

      return {
        ...request,
        latestNegotiation,
        negotiationCount
      };
    })
  );
  return res.json({ requests: requestsWithNegotiation });
});

adminRouter.patch("/requests/:id/quote", async (req, res) => {
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

adminRouter.patch("/requests/:id/reject", async (req, res) => {
  const parsed = rejectSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: parsed.error.flatten() });
  }

  const request = await RequestModel.findById(req.params.id);
  if (!request) {
    return res.status(404).json({ message: "Request not found" });
  }

  if (["AGREED", "QR_ISSUED", "COLLECTED", "CANCELLED"].includes(request.status)) {
    return res.status(400).json({ message: "Request cannot be denied in current state" });
  }

  request.status = "CANCELLED";
  request.quotePendingForUser = false;
  await request.save();

  await NegotiationModel.create({
    requestId: request._id,
    senderRole: "ADMIN",
    senderId: req.user!.id,
    offeredAmount: request.currentQuote || 0,
    message: parsed.data.reason
  });

  return res.json({ request, message: "Request rejected" });
});

adminRouter.post("/members", async (req, res) => {
  const parsed = createMemberSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: parsed.error.flatten() });
  }

  const exists = await UserModel.findOne({ email: parsed.data.email.toLowerCase() });
  if (exists) {
    return res.status(409).json({ message: "Email already exists" });
  }

  const passwordHash = await bcrypt.hash(parsed.data.password, 10);
  const member = await UserModel.create({
    ...parsed.data,
    email: parsed.data.email.toLowerCase(),
    passwordHash,
    role: "MEMBER"
  });

  return res.status(201).json({
    message: "Member created",
    member: {
      id: member._id,
      fullName: member.fullName,
      email: member.email,
      role: member.role,
      campusId: member.campusId
    }
  });
});

adminRouter.get("/members", async (_req, res) => {
  const members = await UserModel.find({ role: "MEMBER" }).select("fullName email phone campusId department createdAt");
  return res.json({ members });
});

adminRouter.get("/analytics/overview", async (_req, res) => {
  const [totalRequests, collected, users, members] = await Promise.all([
    RequestModel.countDocuments(),
    RequestModel.countDocuments({ status: "COLLECTED" }),
    UserModel.countDocuments({ role: "USER" }),
    UserModel.countDocuments({ role: "MEMBER" })
  ]);

  const byStatus = await RequestModel.aggregate([
    { $group: { _id: "$status", count: { $sum: 1 } } }
  ]);

  return res.json({
    totalRequests,
    collected,
    users,
    members,
    byStatus
  });
});
