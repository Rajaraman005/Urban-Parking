import { createClient } from "@supabase/supabase-js";
import { Algorithm, hash } from "@node-rs/argon2";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const envPath = join(scriptDir, "..", ".env");

if (existsSync(envPath)) {
  for (const line of readFileSync(envPath, "utf8").split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;

    const separatorIndex = trimmed.indexOf("=");
    if (separatorIndex === -1) continue;

    const key = trimmed.slice(0, separatorIndex).trim();
    let value = trimmed.slice(separatorIndex + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }

    process.env[key] ??= value;
  }
}

const requiredEnv = (name) => {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`Missing ${name}`);
  }
  return value;
};

const username = requiredEnv("ADMIN_BOOTSTRAP_USERNAME").toLowerCase();
const password = requiredEnv("ADMIN_BOOTSTRAP_PASSWORD");
const displayName = process.env.ADMIN_BOOTSTRAP_NAME?.trim() || "Parking Admin";

if (password.length < 12) {
  throw new Error("ADMIN_BOOTSTRAP_PASSWORD must be at least 12 characters.");
}

const supabase = createClient(requiredEnv("SUPABASE_URL"), requiredEnv("SUPABASE_SERVICE_ROLE_KEY"), {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

const passwordHash = await hash(password, {
  algorithm: Algorithm.Argon2id,
  memoryCost: 19_456,
  parallelism: 1,
  timeCost: 2
});

const { data: existing, error: lookupError } = await supabase
  .from("admin_users")
  .select("id")
  .eq("username", username)
  .maybeSingle();

if (lookupError) {
  throw lookupError;
}

const payload = {
  display_name: displayName,
  is_active: true,
  password_hash: passwordHash,
  role: "owner",
  username
};

const { error } = existing
  ? await supabase.from("admin_users").update(payload).eq("id", existing.id)
  : await supabase.from("admin_users").insert(payload);

if (error) {
  throw error;
}

console.log(`Admin user ready: ${username}`);
