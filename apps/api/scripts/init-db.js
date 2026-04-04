const path = require("path");
const dotenv = require("dotenv");
const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");

const apiEnvPath = path.resolve(__dirname, "../.env");
const rootEnvPath = path.resolve(__dirname, "../../.env");

dotenv.config({ path: apiEnvPath });
dotenv.config({ path: rootEnvPath });

const mongoUri = process.env.MONGODB_URI;
const dbName = process.env.MONGODB_DB_NAME || "eco_campus";

if (!mongoUri) {
  console.error("Missing MONGODB_URI in environment.");
  process.exit(1);
}

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
    qrTokenId: { type: mongoose.Schema.Types.ObjectId, ref: "QrToken", default: null },
    assignedMemberId: { type: mongoose.Schema.Types.ObjectId, ref: "User", default: null },
    assignedAt: { type: Date, default: null },
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

async function createUser({ role, fullName, email, phone, campusId, department, password }) {
  return User.create({
    role,
    fullName,
    email: email.toLowerCase(),
    phone,
    campusId,
    department,
    passwordHash: await bcrypt.hash(password, 10),
    isActive: true
  });
}

async function initDb() {
  try {
    await mongoose.connect(mongoUri, {
      dbName,
      retryWrites: true,
      w: "majority",
      serverSelectionTimeoutMS: 30000,
      socketTimeoutMS: 45000,
      connectTimeoutMS: 30000
    });

    console.log(`Connected to MongoDB database: ${dbName}`);
    console.log("Deleting old database data...");
    await mongoose.connection.db.dropDatabase();
    console.log("Old database deleted successfully.");

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

    const mainCampus = await Campus.create({
      name: "Eco Campus Main Campus",
      code: "MAIN-CAMPUS",
      address: "University Road, Block A",
      city: "Metro City"
    });

    const northCampus = await Campus.create({
      name: "Eco Campus North Campus",
      code: "NORTH-CAMPUS",
      address: "North Ring Road, Block N",
      city: "Metro City"
    });

    await Bootstrap.create({
      key: "project",
      value: {
        name: "Eco Campus",
        database: dbName,
        initializedAt: new Date().toISOString(),
        seedVersion: "fresh-v2"
      }
    });

    const admin = await createUser({
      role: "ADMIN",
      fullName: process.env.ADMIN_NAME || "Eco Campus Admin",
      email: process.env.ADMIN_EMAIL || "admin@eco-campus.local",
      phone: process.env.ADMIN_PHONE || "9999999999",
      campusId: "MAIN-CAMPUS",
      department: "Operations",
      password: process.env.ADMIN_PASSWORD || "Admin@12345"
    });

    const mainMember = await createUser({
      role: "MEMBER",
      fullName: "Rahul Main Collector",
      email: "member.main@eco-campus.local",
      phone: "7777000001",
      campusId: mainCampus.code,
      department: "Facilities",
      password: "Member@12345"
    });

    const northMember = await createUser({
      role: "MEMBER",
      fullName: "Anita North Collector",
      email: "member.north@eco-campus.local",
      phone: "7777000002",
      campusId: northCampus.code,
      department: "Facilities",
      password: "Member@12345"
    });

    const students = {
      main1: await createUser({
        role: "USER",
        fullName: "Aman Verma",
        email: "aman.main@eco-campus.local",
        phone: "8888000001",
        campusId: mainCampus.code,
        department: "Computer Science",
        password: "Student@12345"
      }),
      main2: await createUser({
        role: "USER",
        fullName: "Priya Nair",
        email: "priya.main@eco-campus.local",
        phone: "8888000002",
        campusId: mainCampus.code,
        department: "Electronics",
        password: "Student@12345"
      }),
      main3: await createUser({
        role: "USER",
        fullName: "Karan Singh",
        email: "karan.main@eco-campus.local",
        phone: "8888000003",
        campusId: mainCampus.code,
        department: "Mechanical",
        password: "Student@12345"
      }),
      north1: await createUser({
        role: "USER",
        fullName: "Neha Roy",
        email: "neha.north@eco-campus.local",
        phone: "8888000004",
        campusId: northCampus.code,
        department: "Architecture",
        password: "Student@12345"
      }),
      north2: await createUser({
        role: "USER",
        fullName: "Rohit Das",
        email: "rohit.north@eco-campus.local",
        phone: "8888000005",
        campusId: northCampus.code,
        department: "Civil",
        password: "Student@12345"
      })
    };

    const requests = await Request.insertMany([
      {
        userId: students.main1._id,
        campusId: mainCampus.code,
        imageUrl: "https://images.unsplash.com/photo-1588702547923-7093a6c3ba33?w=800",
        imageUrls: ["https://images.unsplash.com/photo-1588702547923-7093a6c3ba33?w=800"],
        description: "Old laptop and charger for pickup",
        categoriesDetected: ["Laptop", "Charger"],
        status: "QR_ISSUED",
        currentQuote: 600,
        adminQuote: 600,
        adminQuoteMessage: "Good condition devices.",
        quotePendingForUser: false,
        agreedQuote: 600,
        assignedMemberId: mainMember._id,
        assignedAt: new Date(),
        agreedAt: new Date()
      },
      {
        userId: students.main2._id,
        campusId: mainCampus.code,
        imageUrl: "https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?w=800",
        imageUrls: ["https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?w=800"],
        description: "CRT monitor and keyboard",
        categoriesDetected: ["Monitor", "Keyboard"],
        status: "BARGAINING",
        currentQuote: 350,
        adminQuote: 400,
        adminQuoteMessage: "Monitor is bulky.",
        lastUserCounterMessage: "Can you make it 350?",
        quotePendingForUser: false,
        agreedQuote: 0
      },
      {
        userId: students.main3._id,
        campusId: mainCampus.code,
        imageUrl: "https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=800",
        imageUrls: ["https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=800"],
        description: "Broken UPS battery set",
        categoriesDetected: ["Battery", "UPS"],
        status: "SUBMITTED",
        currentQuote: 0,
        adminQuote: 0,
        quotePendingForUser: false,
        agreedQuote: 0
      },
      {
        userId: students.north1._id,
        campusId: northCampus.code,
        imageUrl: "https://images.unsplash.com/photo-1610337673044-720471f83677?w=800",
        imageUrls: ["https://images.unsplash.com/photo-1610337673044-720471f83677?w=800"],
        description: "Networking router and modem scrap",
        categoriesDetected: ["Router", "Modem"],
        status: "QR_ISSUED",
        currentQuote: 250,
        adminQuote: 250,
        adminQuoteMessage: "Approved for north campus pickup.",
        quotePendingForUser: false,
        agreedQuote: 250,
        assignedMemberId: northMember._id,
        assignedAt: new Date(),
        agreedAt: new Date()
      },
      {
        userId: students.north2._id,
        campusId: northCampus.code,
        imageUrl: "https://images.unsplash.com/photo-1527443195645-1133f7f28990?w=800",
        imageUrls: ["https://images.unsplash.com/photo-1527443195645-1133f7f28990?w=800"],
        description: "Old CPU cabinet and cables",
        categoriesDetected: ["CPU", "Cables"],
        status: "QUOTED",
        currentQuote: 300,
        adminQuote: 300,
        adminQuoteMessage: "Please accept to proceed.",
        quotePendingForUser: true,
        agreedQuote: 0
      }
    ]);

    const qrIssued = requests.filter((item) => item.status === "QR_ISSUED");

    for (const req of qrIssued) {
      const token = await QrToken.create({
        requestId: req._id,
        tokenHash: `qr-${req._id}`,
        expiresAt: new Date(Date.now() + 48 * 60 * 60 * 1000),
        isUsed: false
      });

      req.qrTokenId = token._id;
      await req.save();
    }

    await Negotiation.insertMany([
      {
        requestId: requests[0]._id,
        senderRole: "ADMIN",
        senderId: admin._id,
        offeredAmount: 600,
        message: "Final quote sent."
      },
      {
        requestId: requests[1]._id,
        senderRole: "USER",
        senderId: students.main2._id,
        offeredAmount: 350,
        message: "Can you make it 350?"
      },
      {
        requestId: requests[3]._id,
        senderRole: "ADMIN",
        senderId: admin._id,
        offeredAmount: 250,
        message: "North campus pickup approved."
      },
      {
        requestId: requests[4]._id,
        senderRole: "ADMIN",
        senderId: admin._id,
        offeredAmount: 300,
        message: "Quote sent for your confirmation."
      }
    ]);

    const counts = {
      campuses: await Campus.countDocuments(),
      users: await User.countDocuments(),
      members: await User.countDocuments({ role: "MEMBER" }),
      students: await User.countDocuments({ role: "USER" }),
      requests: await Request.countDocuments(),
      mainCampusRequests: await Request.countDocuments({ campusId: "MAIN-CAMPUS" }),
      northCampusRequests: await Request.countDocuments({ campusId: "NORTH-CAMPUS" }),
      negotiations: await Negotiation.countDocuments(),
      qrtokens: await QrToken.countDocuments()
    };

    console.log("Fresh seed complete.");
    console.log(JSON.stringify(counts, null, 2));
    console.log("Admin login:", process.env.ADMIN_EMAIL || "admin@eco-campus.local", "/", process.env.ADMIN_PASSWORD || "Admin@12345");
    console.log("Member login sample:", "member.main@eco-campus.local", "/ Member@12345");
    console.log("Student login sample:", "aman.main@eco-campus.local", "/ Student@12345");
  } catch (error) {
    console.error("Database initialization failed:", error.message || error);
    process.exitCode = 1;
  } finally {
    await new Promise((resolve) => setTimeout(resolve, 300));
    await mongoose.disconnect();
  }
}

initDb();
