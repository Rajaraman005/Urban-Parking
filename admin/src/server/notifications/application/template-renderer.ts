const tokenPattern = /\{\{\s*([a-zA-Z0-9_.-]+)\s*\}\}/g;

export function renderNotificationTemplate(
  template: string | null | undefined,
  payload: Record<string, unknown>,
) {
  if (!template) return undefined;
  return template.replace(tokenPattern, (_match, key: string) => {
    const value = valueAtPath(payload, key);
    if (value == null) return "";
    if (typeof value === "string") return value;
    if (typeof value === "number" || typeof value === "boolean") {
      return String(value);
    }
    return "";
  });
}

function valueAtPath(payload: Record<string, unknown>, path: string) {
  let value: unknown = payload;
  for (const key of path.split(".")) {
    if (typeof value !== "object" || value === null || !(key in value)) {
      return undefined;
    }
    value = (value as Record<string, unknown>)[key];
  }
  return value;
}
