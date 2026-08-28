// auth: project logic for this module.
import { betterAuth } from "better-auth";
import { drizzleAdapter } from "better-auth/adapters/drizzle";
import { emailOTP } from "better-auth/plugins";
import { Resend } from "resend";
import { db } from "../../db";

const secret = process.env.BETTER_AUTH_SECRET;
const resendApiKey = process.env.RESEND_API_KEY;
const resendFrom = process.env.RESEND_FROM;
const resend = resendApiKey ? new Resend(resendApiKey) : undefined;

if (!secret) {
  throw new Error("BETTER_AUTH_SECRET is required to start the API");
}

export const auth = betterAuth({
  secret,
  baseURL: process.env.BETTER_AUTH_URL,
  // The Hono adapter mounts Better Auth at /auth/* and the iOS client uses
  // the same prefix. Better Auth defaults to /api/auth, so keep its router
  // base path aligned with the public route.
  basePath: "/auth",
  trustedOrigins: [
    process.env.BETTER_AUTH_URL ?? "http://localhost:3000",
    "http://*.local:3000",
    "http://*.local.:3000",
  ],
  database: drizzleAdapter(db, {
    provider: "pg",
  }),
  plugins: [
    emailOTP({
      async sendVerificationOTP({ email, otp, type }) {
        console.log(`[API:Auth] Sending ${type} OTP`);
        if (type !== "sign-in") {
          throw new Error(`Unsupported email OTP type: ${type}`);
        }

        if (!resend) {
          throw new Error("RESEND_API_KEY is required to send email OTPs");
        }

        if (!resendFrom) {
          throw new Error("RESEND_FROM is required to send email OTPs");
        }

        const { data, error } = await resend.emails.send({
          from: resendFrom,
          to: [email],
          subject: "Your Sarvam sign-in code",
          text: `Your Sarvam sign-in code is ${otp}. This code expires soon.`,
        });

        if (error) {
          throw new Error(error.message);
        }

        if (!data?.id) {
          throw new Error("Resend did not return an email id");
        }
        console.log("[API:Auth] OTP email sent");
      },
    }),
  ],
});
