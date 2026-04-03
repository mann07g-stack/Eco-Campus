import { Router } from "express";
import { z } from "zod";
import { requireAuth, requireRole, AuthRequest } from "../middleware/auth";
import { verifyQrPayload } from "../utils/qr";
import { QrTokenModel } from "../models/QrToken";
import { RequestModel } from "../models/Request";

const scanSchema = z.object({
  qrToken: z.string().min(20)
});

export const memberRouter = Router();
memberRouter.use(requireAuth, requireRole("MEMBER"));

memberRouter.get("/assigned", async (req: AuthRequest, res) => {
  const requests = await RequestModel.find({
    assignedMemberId: req.user!.id,
    status: "QR_ISSUED"
  })
    .sort({ assignedAt: -1, createdAt: -1 })
    .populate("userId", "fullName phone campusId")
    .lean();

  return res.json({ requests });
});

memberRouter.get("/history", async (req: AuthRequest, res) => {
  const requests = await RequestModel.find({ collectedByMemberId: req.user!.id })
    .sort({ collectedAt: -1 })
    .populate("userId", "fullName email phone campusId")
    .lean();

  return res.json({ requests });
});

memberRouter.post("/scan", async (req: AuthRequest, res) => {
  const parsed = scanSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: parsed.error.flatten() });
  }

  try {
    const qr = verifyQrPayload(parsed.data.qrToken);
    const tokenDoc = await QrTokenModel.findById(qr.tokenId);
    if (!tokenDoc) {
      return res.status(404).json({ message: "QR token record not found" });
    }

    if (tokenDoc.isUsed) {
      return res.status(400).json({ message: "QR already used" });
    }

    if (tokenDoc.expiresAt.getTime() < Date.now()) {
      return res.status(400).json({ message: "QR expired" });
    }

    const request = await RequestModel.findById(qr.requestId);
    if (!request) {
      return res.status(404).json({ message: "Request not found" });
    }

    if (request.assignedMemberId && String(request.assignedMemberId) !== req.user!.id) {
      return res.status(403).json({ message: "This pickup is assigned to another member" });
    }

    tokenDoc.isUsed = true;
    tokenDoc.usedAt = new Date();
    tokenDoc.usedByMemberId = req.user!.id;
    await tokenDoc.save();

    request.status = "COLLECTED";
    request.collectedByMemberId = req.user!.id;
    request.collectedAt = new Date();
    await request.save();

    return res.json({
      message: "Collection confirmed",
      requestId: request._id,
      agreedQuote: request.agreedQuote,
      collectedAt: request.collectedAt
    });
  } catch {
    return res.status(400).json({ message: "Invalid QR token" });
  }
});
