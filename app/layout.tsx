import type { Metadata, Viewport } from "next";
import { AuthProvider } from "@/components/auth-provider";
import { PwaRegister } from "@/components/pwa-register";
import { TooltipProvider } from "@/components/ui/tooltip";
import "./globals.css";

export const metadata: Metadata = {
  title: "ECO Healthy ERP",
  description: "نظام إدارة اشتراكات ECO Healthy",
  applicationName: "ECO Healthy ERP",
};

export const viewport: Viewport = {
  themeColor: "#16794a",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ar" dir="rtl">
      <body>
        <TooltipProvider>
          <AuthProvider>
            <PwaRegister />
            {children}
          </AuthProvider>
        </TooltipProvider>
      </body>
    </html>
  );
}
