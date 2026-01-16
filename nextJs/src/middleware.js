import { NextResponse } from "next/server";

export function middleware(request) {
  const token = request.cookies.get("token")?.value || null;
  const customerToken = request.cookies.get("customer_token")?.value || null;
  const pathname = request.nextUrl.pathname;

  /**
   * Public invoice routes
   * - /invoice/:id
   * - /invoice/:id/pdf
   */
  if (pathname.startsWith("/invoice/")) {
    return NextResponse.next();
  }

  /**
   * Public assets & Next internal
   */
  if (
    pathname.startsWith("/assets/") ||
    pathname === "/favicon.ico" ||
    pathname === "/icon.png" ||
    pathname === "/apple-icon.png" ||
    pathname === "/manifest.json" ||
    pathname.startsWith("/_next/")
  ) {
    return NextResponse.next();
  }

  /**
   * Allow Next internal API (proxy, route handlers)
   */
  if (pathname.startsWith("/api/")) {
    return NextResponse.next();
  }

  /**
   * Auth page logic
   */
  const isAdminAuthPage = pathname.startsWith("/login");
  const isCustomerAuthPage =
    pathname.startsWith("/customer/sign-in") ||
    pathname.startsWith("/customer/sign-up");
  const isCustomerArea = pathname === "/order" || pathname.startsWith("/order/");
  const isPublicPage = pathname === "/" || isAdminAuthPage || isCustomerAuthPage;

  if (isAdminAuthPage) {
    if (token && token !== "undefined" && token !== "null") {
      return NextResponse.redirect(new URL("/dashboard", request.url));
    }
    return NextResponse.next();
  }

  if (isCustomerAuthPage) {
    if (customerToken && customerToken !== "undefined" && customerToken !== "null") {
      return NextResponse.redirect(new URL("/order", request.url));
    }
    return NextResponse.next();
  }

  if (isPublicPage) {
    return NextResponse.next();
  }

  if (isCustomerArea && (!customerToken || customerToken === "undefined" || customerToken === "null")) {
    return NextResponse.redirect(new URL("/customer/sign-in", request.url));
  }

  if (
    !isCustomerArea &&
    (!token || token === "undefined" || token === "null")
  ) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|icon.png|manifest.json).*)",
  ],
};
