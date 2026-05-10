import { z } from "zod";

export const notificationCategories = [
  "message",
  "booking",
  "payment",
  "security",
  "admin",
  "system",
  "marketing",
] as const;

export const notificationChannels = [
  "in_app",
  "realtime",
  "push",
  "email",
  "sms",
] as const;

export const notificationPriorities = [
  "low",
  "normal",
  "high",
  "critical",
] as const;

export const notificationStatuses = [
  "unread",
  "read",
  "dismissed",
  "archived",
] as const;

export type NotificationCategory = (typeof notificationCategories)[number];
export type NotificationChannel = (typeof notificationChannels)[number];
export type NotificationPriority = (typeof notificationPriorities)[number];
export type NotificationStatus = (typeof notificationStatuses)[number];

export const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const uuidSchema = z.string().regex(uuidPattern, "UUID is invalid.");
export const notificationCategorySchema = z.enum(notificationCategories);
export const notificationChannelSchema = z.enum(notificationChannels);
export const notificationPrioritySchema = z.enum(notificationPriorities);
export const notificationStatusSchema = z.enum(notificationStatuses);

export const notificationEventSchema = z.object({
  actorId: uuidSchema.optional().nullable(),
  aggregate: z.object({
    id: uuidSchema,
    type: z.string().trim().min(1).max(80),
  }),
  category: notificationCategorySchema,
  channels: z.array(notificationChannelSchema).min(1).max(5),
  dedupeKey: z.string().trim().min(1).max(180).optional().nullable(),
  eventType: z.string().trim().min(1).max(120),
  idempotencyKey: z.string().trim().min(1).max(240),
  payload: z.record(z.string(), z.unknown()).default({}),
  priority: notificationPrioritySchema.default("normal"),
  recipientSelector: z.union([
    z.object({
      type: z.literal("users"),
      userIds: z.array(uuidSchema).min(1).max(5000),
    }),
    z.object({
      params: z.record(z.string(), z.unknown()).default({}),
      segmentKey: z.string().trim().min(1).max(120),
      type: z.literal("segment"),
    }),
  ]),
  scheduledAt: z.string().datetime().optional().nullable(),
  template: z.object({
    key: z.string().trim().min(1).max(120),
    version: z.number().int().positive(),
  }),
  traceId: z.string().trim().min(1).max(180),
});

export type NotificationEventInput = z.infer<typeof notificationEventSchema>;

export type NotificationDto = {
  body: string;
  category: NotificationCategory;
  createdAt: string;
  cursor: string;
  deeplink?: string;
  id: string;
  payload?: Record<string, unknown>;
  priority: NotificationPriority;
  readAt?: string;
  status: NotificationStatus;
  title: string;
};

export type NotificationListResponse = {
  items: NotificationDto[];
  unreadByCategory: Record<string, number>;
};

export type NotificationPreferenceDto = {
  category: NotificationCategory;
  emailEnabled: boolean;
  inAppEnabled: boolean;
  marketingConsentAt?: string;
  pushEnabled: boolean;
  quietHoursEnabled: boolean;
  quietHoursEndMinute?: number;
  quietHoursStartMinute?: number;
  realtimeEnabled: boolean;
  smsEnabled: boolean;
  timezone: string;
};
