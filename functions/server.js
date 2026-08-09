require("dotenv").config();
const express = require("express");
const cors = require("cors");
const multer = require("multer");
const admin = require("firebase-admin");
const { GoogleGenAI } = require("@google/genai");

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  try {
    admin.initializeApp();
  } catch (e) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  }
}

const db = admin.firestore();
const app = express();

app.use(cors({ origin: true }));
app.use(express.json());

// Setup Multer for in-memory file upload handling
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
});

const DAILY_LIMIT = 5;

// Utility: Calculate next 12:00 AM reset ISO timestamp
function getResetAtTime(userDateStr) {
  let date;
  if (userDateStr && /^\d{4}-\d{2}-\d{2}$/.test(userDateStr)) {
    const [year, month, day] = userDateStr.split("-").map(Number);
    date = new Date(year, month - 1, day);
  } else {
    date = new Date();
  }
  // Next calendar day at 00:00:00
  const resetDate = new Date(date);
  resetDate.setDate(resetDate.getDate() + 1);
  resetDate.setHours(0, 0, 0, 0);
  return resetDate.toISOString();
}

// Utility: Format date to YYYY-MM-DD
function getFormattedDate(userDateStr) {
  if (userDateStr && /^\d{4}-\d{2}-\d{2}$/.test(userDateStr)) {
    return userDateStr;
  }
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

// Authentication Middleware via Firebase ID Token
async function authenticateUser(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({
      success: false,
      error: "unauthorized",
      message: "Authorization token is missing or malformed.",
    });
  }

  const idToken = authHeader.split("Bearer ")[1];
  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    req.user = decodedToken;
    next();
  } catch (error) {
    console.error("Firebase auth verification error:", error);
    return res.status(401).json({
      success: false,
      error: "unauthorized",
      message: "Invalid or expired authentication token.",
    });
  }
}

// Health check endpoint
app.get("/api/health", (req, res) => {
  res.json({ status: "ok", service: "Calorix AI Scan Backend" });
});

// GET /api/scan-usage - Get current daily scan usage for user
app.get("/api/scan-usage", authenticateUser, async (req, res) => {
  try {
    const userId = req.user.uid;
    const userDate = req.headers["x-user-date"] || req.query.date;
    const dateKey = getFormattedDate(userDate);
    const resetAt = getResetAtTime(dateKey);

    const docRef = db
      .collection("users")
      .doc(userId)
      .collection("ai_scan_usage")
      .doc(dateKey);

    const docSnap = await docRef.get();
    const used = docSnap.exists ? docSnap.data().scanCount || 0 : 0;
    const remaining = Math.max(0, DAILY_LIMIT - used);

    return res.json({
      success: true,
      data: {
        userId,
        date: dateKey,
        limit: DAILY_LIMIT,
        used,
        remaining,
        resetAt,
      },
    });
  } catch (error) {
    console.error("Error fetching scan usage:", error);
    return res.status(500).json({
      success: false,
      error: "server_error",
      message: "Failed to retrieve scan usage.",
    });
  }
});

// POST /api/analyze-food - Analyze food image with Gemini API (Rate-Limited)
app.post(
  "/api/analyze-food",
  authenticateUser,
  upload.single("image"),
  async (req, res) => {
    try {
      const userId = req.user.uid;
      const userDate = req.headers["x-user-date"] || req.body.date;
      const language = req.body.language || "en";
      const dateKey = getFormattedDate(userDate);
      const resetAt = getResetAtTime(dateKey);

      const usageRef = db
        .collection("users")
        .doc(userId)
        .collection("ai_scan_usage")
        .doc(dateKey);

      // STEP 1: Pre-check scan usage (before calling Gemini API)
      const initialDocSnap = await usageRef.get();
      const currentUsed = initialDocSnap.exists
        ? initialDocSnap.data().scanCount || 0
        : 0;

      if (currentUsed >= DAILY_LIMIT) {
        return res.status(429).json({
          success: false,
          error: "daily_limit_reached",
          message: `Daily scan limit reached. You get ${DAILY_LIMIT} free AI scans per day.`,
          limit: DAILY_LIMIT,
          used: currentUsed,
          remaining: 0,
          resetAt,
        });
      }

      // STEP 2: Validate uploaded image file
      if (!req.file) {
        return res.status(400).json({
          success: false,
          error: "missing_image",
          message: "Please upload an image for food analysis.",
        });
      }

      // STEP 3: Call Gemini AI for food analysis
      const apiKey = process.env.GEMINI_API_KEY;
      if (!apiKey) {
        console.error("GEMINI_API_KEY is not configured on backend!");
        return res.status(500).json({
          success: false,
          error: "configuration_error",
          message: "Server AI key configuration missing.",
        });
      }

      const ai = new GoogleGenAI({ apiKey });
      const promptText = `You are a professional nutrition expert. Analyze this food image carefully.
Respond strictly in JSON format matching this structure (no markdown formatting outside of JSON):
{
  "foodName": "Name of the dish or food item",
  "description": "Brief description of the meal and estimated components",
  "calories": 450,
  "protein": 25.5,
  "carbs": 50.0,
  "fat": 15.0,
  "fiber": 4.5,
  "servingSize": "1 plate (350g)",
  "confidenceScore": 0.92,
  "healthRating": "Healthy",
  "ingredients": ["Item 1", "Item 2"]
}
Provide all text descriptions in language: ${language}.`;

      const imagePart = {
        inlineData: {
          data: req.file.buffer.toString("base64"),
          mimeType: req.file.mimetype || "image/jpeg",
        },
      };

      let aiResponseText = "";
      try {
        const response = await ai.models.generateContent({
          model: "gemini-2.5-flash",
          contents: [promptText, imagePart],
        });
        aiResponseText = response.text;
      } catch (geminiErr) {
        console.error("Gemini API Error:", geminiErr);
        // Do NOT consume scan count if Gemini API request fails
        return res.status(500).json({
          success: false,
          error: "ai_analysis_failed",
          message: "AI analysis failed. Please try again with a clearer picture.",
        });
      }

      // Parse JSON from Gemini response
      let parsedData;
      try {
        const cleanJsonStr = aiResponseText
          .replace(/```json/gi, "")
          .replace(/```/g, "")
          .trim();
        parsedData = JSON.parse(cleanJsonStr);
      } catch (jsonErr) {
        console.error("Failed to parse Gemini JSON:", aiResponseText);
        return res.status(500).json({
          success: false,
          error: "ai_parse_failed",
          message: "Could not parse AI nutrition output.",
        });
      }

      // STEP 4: Atomic increment in Firestore AFTER successful AI response
      let updatedCount = 0;
      try {
        updatedCount = await db.runTransaction(async (transaction) => {
          const docSnap = await transaction.get(usageRef);
          const count = docSnap.exists ? docSnap.data().scanCount || 0 : 0;

          if (count >= DAILY_LIMIT) {
            throw new Error("daily_limit_reached");
          }

          const newCount = count + 1;
          transaction.set(
            usageRef,
            {
              userId,
              date: dateKey,
              scanCount: newCount,
              limit: DAILY_LIMIT,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
          return newCount;
        });
      } catch (txnError) {
        if (txnError.message === "daily_limit_reached") {
          return res.status(429).json({
            success: false,
            error: "daily_limit_reached",
            message: `Daily scan limit reached. You get ${DAILY_LIMIT} free AI scans per day.`,
            limit: DAILY_LIMIT,
            used: DAILY_LIMIT,
            remaining: 0,
            resetAt,
          });
        }
        console.error("Transaction failed:", txnError);
        throw txnError;
      }

      const remainingScans = Math.max(0, DAILY_LIMIT - updatedCount);

      // STEP 5: Return successful result + scan usage metadata
      return res.json({
        success: true,
        data: {
          ...parsedData,
          scanUsage: {
            limit: DAILY_LIMIT,
            used: updatedCount,
            remaining: remainingScans,
            resetAt,
          },
        },
      });
    } catch (error) {
      console.error("Unhandled error in analyze-food:", error);
      return res.status(500).json({
        success: false,
        error: "internal_error",
        message: error.message || "An unexpected error occurred.",
      });
    }
  }
);

// Export app or listen if started directly
const PORT = process.env.PORT || 3000;
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Calorix AI Backend Server running on port ${PORT}`);
  });
}

module.exports = app;
