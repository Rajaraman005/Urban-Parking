import { NextRequest, NextResponse } from "next/server";
import { SESSION_COOKIE_NAME } from "@/server/auth/constants";

const publicRoutes = new Set(["/login"]);
const protectedPrefixes = ["/reviews", "/approved", "/rejected", "/settings"];
const isDevelopment = process.env.NODE_ENV !== "production";

function createNonce() {
  return btoa(crypto.randomUUID());
}

function contentSecurityPolicy(nonce: string) {
  const scriptSrc = [
    "'self'",
    `'nonce-${nonce}'`,
    "'strict-dynamic'",
    ...(isDevelopment ? ["'unsafe-eval'"] : [])
  ].join(" ");

  const connectSrc = [
    "'self'",
    "https://*.supabase.co",
    ...(isDevelopment ? ["http://localhost:3000", "http://127.0.0.1:3000", "ws://localhost:3000", "ws://127.0.0.1:3000"] : [])
  ].join(" ");

  return [
    "default-src 'self'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'none'",
    "object-src 'none'",
    `script-src ${scriptSrc}`,
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: blob: https://res.cloudinary.com https://images.unsplash.com",
    "font-src 'self' data:",
    `connect-src ${connectSrc}`
  ].join("; ");
}

function secureResponse(response: NextResponse, nonce: string) {
  response.headers.set("Content-Security-Policy", contentSecurityPolicy(nonce));
  return response;
}

export function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const nonce = createNonce();
  const requestHeaders = new Headers(request.headers);
  requestHeaders.set("x-nonce", nonce);

  const hasSession = Boolean(request.cookies.get(SESSION_COOKIE_NAME)?.value);
  const isPublic = publicRoutes.has(pathname);
  const isProtected = protectedPrefixes.some((prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`));

  if (isPublic && hasSession) {
    return secureResponse(NextResponse.redirect(new URL("/reviews", request.url)), nonce);
  }

  if (isProtected && !hasSession) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("next", pathname);
    return secureResponse(NextResponse.redirect(loginUrl), nonce);
  }

  return secureResponse(
    NextResponse.next({
      request: {
        headers: requestHeaders
      }
    }),
    nonce
  );
}

export const config = {
  matcher: ["/((?!api|_next/static|_next/image|favicon.ico|.*\\.(?:png|jpg|jpeg|svg|webp)$).*)"]
};
