export const corsHeaders = {
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Origin": "*"
};

export const jsonResponse = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json"
    },
    status
  });

export const getBearerToken = (request: Request) => {
  const authorization = request.headers.get("Authorization") ?? "";
  const [scheme, token] = authorization.split(" ");

  return scheme?.toLowerCase() === "bearer" ? token : null;
};

export const getClientIp = (request: Request) => {
  const forwardedFor = request.headers.get("x-forwarded-for");
  const sanitizeIp = (value: string | null | undefined) => {
    const ip = value?.trim();

    return ip && /^[0-9a-fA-F:.]+$/.test(ip) ? ip : null;
  };

  if (forwardedFor) {
    return sanitizeIp(forwardedFor.split(",")[0]);
  }

  return sanitizeIp(request.headers.get("cf-connecting-ip") ?? request.headers.get("x-real-ip"));
};

export const readJsonBody = async <T extends Record<string, unknown>>(request: Request) => {
  try {
    return (await request.json()) as T;
  } catch {
    return {} as T;
  }
};
