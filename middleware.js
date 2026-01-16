import { NextResponse } from "next/server";

export function middleware(req) {
  const { pathname } = req.nextUrl;

  // Boleh akses halaman login
  if (pathname.startsWith("/login")) {
    return NextResponse.next();
  }

  const cookieToken = req.cookies.get("token")?.value;
  const authHeader = req.headers.get("authorization") || "";
  const headerToken = authHeader.startsWith("Bearer ")
    ? authHeader.replace("Bearer ", "")
    : null;

  // Jika tidak ada token, redirect login
  if (!cookieToken && !headerToken) {
    const url = new URL("/login", req.url);
    return NextResponse.redirect(url);
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    "/dashboard/:path*",
    "/invoice-list/:path*",
    "/invoice/:path*",
    "/invoice-add/:path*",
    "/invoice-edit/:path*",
    "/invoice-preview/:path*",
    "/invoice-expense/:path*",
    "/invoice-expense-edit/:path*",
    "/expense-preview/:path*",
    "/armada-list/:path*",
    "/armada-add/:path*",
    "/armada-edit/:path*",
    "/calendar/:path*",
    "/calendar-main/:path*",
    "/role-access/:path*",
    "/assign-role/:path*",
    "/add-user/:path*",
    "/customer-registrations/:path*",
    "/order-acceptance/:path*"
  ],
};
