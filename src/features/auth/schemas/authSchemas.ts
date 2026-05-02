import { z } from "zod";

export const emailSchema = z.string().trim().email("Enter a valid email address").toLowerCase();

export const passwordSchema = z
  .string()
  .min(8, "Password must be at least 8 characters")
  .regex(/[A-Z]/, "Use at least one uppercase letter")
  .regex(/[a-z]/, "Use at least one lowercase letter")
  .regex(/[0-9]/, "Use at least one number")
  .regex(/[^A-Za-z0-9]/, "Use at least one symbol");

export const loginSchema = z.object({
  email: emailSchema,
  password: z.string().min(1, "Enter your password")
});

export const signupSchema = z.object({
  fullName: z.string().trim().min(2, "Enter your full name").max(80, "Name is too long"),
  email: emailSchema,
  password: passwordSchema
});

export const emailOtpRequestSchema = z.object({
  email: emailSchema
});

export const emailOtpVerifySchema = z.object({
  email: emailSchema,
  token: z.string().trim().length(6, "Enter the 6-digit code")
});

export const signupOtpVerifySchema = z.object({
  token: z.string().trim().length(6, "Enter the 6-digit code")
});

export const passwordResetRequestSchema = z.object({
  email: emailSchema
});

export const passwordUpdateSchema = z.object({
  password: passwordSchema
});

export type LoginFormValues = z.infer<typeof loginSchema>;
export type SignupFormValues = z.infer<typeof signupSchema>;
export type EmailOtpRequestValues = z.infer<typeof emailOtpRequestSchema>;
export type EmailOtpVerifyValues = z.infer<typeof emailOtpVerifySchema>;
export type SignupOtpVerifyValues = z.infer<typeof signupOtpVerifySchema>;
export type PasswordResetRequestValues = z.infer<typeof passwordResetRequestSchema>;
export type PasswordUpdateValues = z.infer<typeof passwordUpdateSchema>;
