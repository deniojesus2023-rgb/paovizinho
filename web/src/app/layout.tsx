import type { Metadata, Viewport } from "next";
import { Red_Hat_Display, Red_Hat_Text } from "next/font/google";
import "./globals.css";

const display = Red_Hat_Display({
  subsets: ["latin"],
  weight: ["500", "700"],
  variable: "--font-red-hat-display",
});

const texto = Red_Hat_Text({
  subsets: ["latin"],
  weight: ["400", "500", "700"],
  variable: "--font-red-hat-text",
});

export const metadata: Metadata = {
  title: "Pão Vizinho",
  description: "Seu pãozinho, pertinho de casa.",
};

export const viewport: Viewport = {
  themeColor: "#FFFBF5",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="pt-BR" className={`${display.variable} ${texto.variable}`}>
      <head>
        {/* eslint-disable-next-line @next/next/no-page-custom-font */}
        <link
          rel="stylesheet"
          href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded:opsz,wght,FILL,GRAD@20..24,400,0..1,0&display=swap"
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
