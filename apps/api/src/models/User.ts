import { Schema, model, InferSchemaType } from "mongoose";
import { UserRole } from "../types";

const userSchema = new Schema(
  {
    role: {
      type: String,
      enum: ["USER", "MEMBER", "ADMIN"],
      default: "USER"
    },
    fullName: { type: String, required: true },
    email: { type: String, required: true, unique: true, lowercase: true },
    phone: { type: String, required: true },
    campusId: { type: String, required: true },
    department: { type: String, default: "" },
    passwordHash: { type: String, required: true },
    isActive: { type: Boolean, default: true }
  },
  { timestamps: true }
);

export type UserDocument = InferSchemaType<typeof userSchema> & {
  _id: string;
  role: UserRole;
};

export const UserModel = model("User", userSchema);
