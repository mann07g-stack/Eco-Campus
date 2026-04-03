import { Schema, model, InferSchemaType, Types } from "mongoose";

const qrTokenSchema = new Schema(
  {
    requestId: { type: Types.ObjectId, ref: "Request", required: true, unique: true },
    tokenHash: { type: String, required: true },
    expiresAt: { type: Date, required: true },
    isUsed: { type: Boolean, default: false },
    usedAt: { type: Date, default: null },
    usedByMemberId: { type: Types.ObjectId, ref: "User", default: null }
  },
  { timestamps: true }
);

export type QrTokenDocument = InferSchemaType<typeof qrTokenSchema> & {
  _id: string;
};

export const QrTokenModel = model("QrToken", qrTokenSchema);
