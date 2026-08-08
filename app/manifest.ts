import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "ECO Healthy ERP",
    short_name: "ECO ERP",
    description: "نظام إدارة اشتراكات ECO Healthy",
    start_url: "/",
    display: "standalone",
    background_color: "#f4f7f5",
    theme_color: "#16794a",
    lang: "ar",
    dir: "rtl",
    icons: [
      {
        src: "/eco-icon.svg",
        sizes: "any",
        type: "image/svg+xml",
        purpose: "any",
      },
    ],
  };
}

