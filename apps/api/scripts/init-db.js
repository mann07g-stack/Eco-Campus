const path = require("path");
const dotenv = require("dotenv");
const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");

const apiEnvPath = path.resolve(__dirname, "../.env");
const rootEnvPath = path.resolve(__dirname, "../../.env");

const apiEnvResult = dotenv.config({ path: apiEnvPath });
if (apiEnvResult.error) {
  console.warn(`Could not load API env file at ${apiEnvPath}: ${apiEnvResult.error.message}`);
} else {
  console.log(`Loaded environment from: ${apiEnvPath}`);
}

// Fallback values only; does not override already-loaded variables from apps/api/.env.
const rootEnvResult = dotenv.config({ path: rootEnvPath });
if (!rootEnvResult.error) {
  console.log(`Loaded fallback environment from: ${rootEnvPath}`);
}

const mongoUri = process.env.MONGODB_URI;
const dbName = process.env.MONGODB_DB_NAME || "eco_campus";

if (!mongoUri) {
  console.error("Missing MONGODB_URI in environment.");
  process.exit(1);
}

console.log(`Using MongoDB database name: ${dbName}`);

const userSchema = new mongoose.Schema(
  {
    role: { type: String, enum: ["USER", "MEMBER", "ADMIN"], default: "USER" },
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

const requestSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    campusId: { type: String, required: true },
    imageUrl: { type: String, required: true },
    description: { type: String, required: true },
    categoriesDetected: { type: [String], default: [] },
    status: {
      type: String,
      enum: ["SUBMITTED", "QUOTED", "BARGAINING", "AGREED", "QR_ISSUED", "COLLECTED", "CANCELLED"],
      default: "SUBMITTED"
    },
    currentQuote: { type: Number, default: 0 },
    agreedQuote: { type: Number, default: 0 },
    qrTokenId: { type: mongoose.Schema.Types.ObjectId, ref: "QrToken", default: null },
    collectedByMemberId: { type: mongoose.Schema.Types.ObjectId, ref: "User", default: null },
    agreedAt: { type: Date, default: null },
    collectedAt: { type: Date, default: null }
  },
  { timestamps: true }
);

const negotiationSchema = new mongoose.Schema(
  {
    requestId: { type: mongoose.Schema.Types.ObjectId, ref: "Request", required: true, index: true },
    senderRole: { type: String, enum: ["USER", "ADMIN"], required: true },
    senderId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    offeredAmount: { type: Number, required: true },
    message: { type: String, default: "" }
  },
  { timestamps: true }
);

const qrTokenSchema = new mongoose.Schema(
  {
    requestId: { type: mongoose.Schema.Types.ObjectId, ref: "Request", required: true, unique: true },
    tokenHash: { type: String, required: true },
    expiresAt: { type: Date, required: true },
    isUsed: { type: Boolean, default: false },
    usedAt: { type: Date, default: null },
    usedByMemberId: { type: mongoose.Schema.Types.ObjectId, ref: "User", default: null }
  },
  { timestamps: true }
);

const campusSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, unique: true },
    code: { type: String, required: true, unique: true },
    address: { type: String, default: "" },
    city: { type: String, default: "" }
  },
  { timestamps: true }
);

const bootstrapSchema = new mongoose.Schema(
  {
    key: { type: String, required: true, unique: true },
    value: { type: mongoose.Schema.Types.Mixed, required: true }
  },
  { timestamps: true }
);

const User = mongoose.models.User || mongoose.model("User", userSchema);
const Request = mongoose.models.Request || mongoose.model("Request", requestSchema);
const Negotiation = mongoose.models.Negotiation || mongoose.model("Negotiation", negotiationSchema);
const QrToken = mongoose.models.QrToken || mongoose.model("QrToken", qrTokenSchema);
const Bootstrap = mongoose.models.Bootstrap || mongoose.model("Bootstrap", bootstrapSchema);
const Campus = mongoose.models.Campus || mongoose.model("Campus", campusSchema);

async function ensureAdmin() {
  const adminEmail = (process.env.ADMIN_EMAIL || "admin@eco-campus.local").toLowerCase();
  const adminPassword = process.env.ADMIN_PASSWORD || "Admin@12345";
  const adminName = process.env.ADMIN_NAME || "Eco Campus Admin";
  const adminPhone = process.env.ADMIN_PHONE || "9999999999";
  const adminCampusId = process.env.ADMIN_CAMPUS_ID || "MAIN-CAMPUS";
  const adminDepartment = process.env.ADMIN_DEPARTMENT || "Operations";

  const existing = await User.findOne({ email: adminEmail });
  if (existing) {
    const passwordHash = await bcrypt.hash(adminPassword, 10);
    existing.fullName = adminName;
    existing.phone = adminPhone;
    existing.campusId = adminCampusId;
    existing.department = adminDepartment;
    existing.passwordHash = passwordHash;
    if (existing.role !== "ADMIN") {
      existing.role = "ADMIN";
    }
    await existing.save();
    console.log(`Updated existing admin user and password: ${adminEmail}`);
    return existing;
  }

  const passwordHash = await bcrypt.hash(adminPassword, 10);
  const adminUser = await User.create({
    role: "ADMIN",
    fullName: adminName,
    email: adminEmail,
    phone: adminPhone,
    campusId: adminCampusId,
    department: adminDepartment,
    passwordHash,
    isActive: true
  });

  console.log(`Created default admin user: ${adminEmail}`);
  console.log("Default admin password is set from ADMIN_PASSWORD or fallback value. Change it immediately in production.");
  return adminUser;
}

async function ensureBootstrapDocument() {
  await Bootstrap.updateOne(
    { key: "project" },
    {
      $setOnInsert: {
        key: "project",
        value: {
          name: "Eco Campus",
          database: dbName,
          initializedAt: new Date().toISOString(),
          description: "Bootstrap metadata for campus e-waste system"
        }
      }
    },
    { upsert: true }
  );

  console.log("Created bootstrap metadata document.");
}

async function ensureCampusDocument() {
  const campus = await Campus.findOneAndUpdate(
    { code: "MAIN-CAMPUS" },
    {
      $setOnInsert: {
        name: "Eco Campus Main Campus",
        code: "MAIN-CAMPUS",
        address: "University Road, Campus Block A",
        city: "Campus City"
      }
    },
    { upsert: true, new: true }
  );

  console.log(`Created campus seed document: ${campus.code}`);
  return campus;
}

async function ensureSeedUser({ role, fullName, email, phone, campusId, department, password }) {
  const normalizedEmail = email.toLowerCase();
  const existing = await User.findOne({ email: normalizedEmail });
  if (existing) {
    if (existing.role !== role) {
      existing.role = role;
      existing.fullName = fullName;
      existing.phone = phone;
      existing.campusId = campusId;
      existing.department = department;
      await existing.save();
    }
    return existing;
  }

  const passwordHash = await bcrypt.hash(password, 10);
  return User.create({
    role,
    fullName,
    email: normalizedEmail,
    phone,
    campusId,
    department,
    passwordHash,
    isActive: true
  });
}

async function ensureSampleRequest(studentUser, memberUser) {
  const existingRequest = await Request.findOne({ userId: studentUser._id });
  if (existingRequest) {
    return existingRequest;
  }

  const request = await Request.create({
    userId: studentUser._id,
    campusId: studentUser.campusId,
    imageUrl: "https://example.com/uploads/sample-ewaste.jpg",
    description: "Sample laptop, charger, and old mouse for testing the eco campus workflow.",
    categoriesDetected: ["Laptop", "Charger", "Mouse"],
    status: "QR_ISSUED",
    currentQuote: 450,
    agreedQuote: 450,
    agreedAt: new Date(),
    qrTokenId: null,
    collectedByMemberId: memberUser._id,
    collectedAt: null
  });

  return request;
}

async function ensureNegotiation(request, adminUser, studentUser) {
  const existingNegotiation = await Negotiation.findOne({ requestId: request._id });
  if (existingNegotiation) {
    return existingNegotiation;
  }

  return Negotiation.create({
    requestId: request._id,
    senderRole: "ADMIN",
    senderId: adminUser._id,
    offeredAmount: 450,
    message: "Sample quote created during database bootstrap for testing."
  });
}

async function ensureQrToken(request, memberUser) {
  const existingToken = await QrToken.findOne({ requestId: request._id });
  if (existingToken) {
    request.qrTokenId = existingToken._id;
    await request.save();
    return existingToken;
  }

  const token = await QrToken.create({
    requestId: request._id,
    tokenHash: `qr-${request._id}`,
    expiresAt: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000),
    isUsed: false,
    usedAt: null,
    usedByMemberId: memberUser._id
  });

  request.qrTokenId = token._id;
  await request.save();

  return token;
}

async function initDb() {
  try {
    const connectOptions = {
      dbName,
      tls: true,
      authSource: "admin",
      retryWrites: true,
      w: "majority",
      serverSelectionTimeoutMS: 30000,
      socketTimeoutMS: 45000,
      connectTimeoutMS: 30000
    };

    // For development, if SSL issues occur
    if (mongoUri.includes("mongodb+srv")) {
      connectOptions.tlsAllowInvalidCertificates = false;
      connectOptions.tlsAllowInvalidHostnames = false;
    }

    await mongoose.connect(mongoUri, connectOptions);
    console.log(`Connected to MongoDB database: ${dbName}`);

    await Promise.all([
      User.createCollection(),
      Request.createCollection(),
      Negotiation.createCollection(),
      QrToken.createCollection(),
      Bootstrap.createCollection(),
      Campus.createCollection()
    ]);

    await Promise.all([
      User.syncIndexes(),
      Request.syncIndexes(),
      Negotiation.syncIndexes(),
      QrToken.syncIndexes(),
      Bootstrap.syncIndexes(),
      Campus.syncIndexes()
    ]);

    const campus = await ensureCampusDocument();
    await ensureBootstrapDocument();
    const adminUser = await ensureAdmin();

    const studentUser = await ensureSeedUser({
      role: "USER",
      fullName: "Sample Student",
      email: "student@eco-campus.local",
      phone: "8888888888",
      campusId: campus.code,
      department: "Computer Science",
      password: "Student@12345"
    });

    const memberUser = await ensureSeedUser({
      role: "MEMBER",
      fullName: "Sample Campus Member",
      email: "member@eco-campus.local",
      phone: "7777777777",
      campusId: campus.code,
      department: "Facilities",
      password: "Member@12345"
    });

    const sampleRequest = await ensureSampleRequest(studentUser, memberUser);
    await ensureNegotiation(sampleRequest, adminUser, studentUser);
    await ensureQrToken(sampleRequest, memberUser);

    const counts = {
      campuses: await Campus.countDocuments(),
      bootstraps: await Bootstrap.countDocuments(),
      users: await User.countDocuments(),
      requests: await Request.countDocuments(),
      negotiations: await Negotiation.countDocuments(),
      qrtokens: await QrToken.countDocuments()
    };

    console.log("Seeded document counts:", JSON.stringify(counts, null, 2));

    console.log("Database prerequisites created successfully.");
  } catch (error) {
    console.error("Database initialization failed:", error.message || error);
    process.exitCode = 1;
  } finally {
    // Ensure all writes are flushed before disconnecting
    await new Promise(resolve => setTimeout(resolve, 500));
    await mongoose.disconnect();
  }
}

initDb();
