import { Schema, model, InferSchemaType, Types } from "mongoose";

const negotiationSchema = new Schema(
  {
    requestId: { type: Types.ObjectId, ref: "Request", required: true, index: true },
    senderRole: { type: String, enum: ["USER", "ADMIN"], required: true },
    senderId: { type: Types.ObjectId, ref: "User", required: true },
    offeredAmount: { type: Number, required: true },
    message: { type: String, default: "" }
  },
  { timestamps: true }
);

export type NegotiationDocument = InferSchemaType<typeof negotiationSchema> & {
  _id: string;
};

export const NegotiationModel = model("Negotiation", negotiationSchema);
