import type { Metadata, Viewport } from "next";
import { cookies } from "next/headers";
import "./globals.css";
import { LocaleProvider } from "@/components/providers/locale-provider";
import { dictionaries, type Locale } from "@/lib/i18n";

export const metadata: Metadata = {
  title: { default: "Eco Healthy ERP", template: "%s · Eco Healthy ERP" },
  description: "Eco Healthy operations, sales and finance workspace",
  manifest: "/manifest.webmanifest",
  applicationName: "Eco Healthy ERP",
  appleWebApp: { capable: true, title: "Eco ERP", statusBarStyle: "default" },
};

export const viewport: Viewport = {
  themeColor: "#174a3a",
  width: "device-width",
  initialScale: 1,
};

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const cookieStore = await cookies();
  const locale: Locale = cookieStore.get("eco_locale")?.value === "en" ? "en" : "ar";
  const dictionary = dictionaries[locale];

  return (
    <html lang={locale} dir={dictionary.direction} suppressHydrationWarning>
      <body>
        <LocaleProvider initialLocale={locale}>{children}</LocaleProvider>
      </body>
    </html>
  );
}
