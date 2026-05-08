import { Schema, model, InferSchemaType, Types } from "mongoose";
import { RequestStatus } from "../types";

const requestSchema = new Schema(
  {
    userId: { type: Types.ObjectId, ref: "User", required: true },
    campusId: { type: String, required: true },
    imageUrl: { type: String, required: true },
    imageUrls: { type: [String], default: [] },
    description: { type: String, required: true },
    categoriesDetected: { type: [String], default: [] },
    status: {
      type: String,
      enum: ["SUBMITTED", "QUOTED", "BARGAINING", "AGREED", "QR_ISSUED", "COLLECTED", "CANCELLED"],
      default: "SUBMITTED"
    },
    currentQuote: { type: Number, default: 0 },
    adminQuote: { type: Number, default: 0 },
    adminQuoteMessage: { type: String, default: "" },
    lastUserCounterMessage: { type: String, default: "" },
    quotePendingForUser: { type: Boolean, default: false },
    agreedQuote: { type: Number, default: 0 },
    qrTokenId: { type: Types.ObjectId, ref: "QrToken", default: null },
    assignedMemberId: { type: Types.ObjectId, ref: "User", default: null },
    assignedAt: { type: Date, default: null },
    collectedByMemberId: { type: Types.ObjectId, ref: "User", default: null },
    agreedAt: { type: Date, default: null },
    collectedAt: { type: Date, default: null }
  },
  { timestamps: true }
);

requestSchema.index({ userId: 1, createdAt: -1 });
requestSchema.index({ assignedMemberId: 1, status: 1, assignedAt: -1, createdAt: -1 });
requestSchema.index({ collectedByMemberId: 1, collectedAt: -1 });
requestSchema.index({ campusId: 1, status: 1, createdAt: -1 });

export type RequestDocument = InferSchemaType<typeof requestSchema> & {
  _id: string;
  status: RequestStatus;
};

export const RequestModel = model("Request", requestSchema);
