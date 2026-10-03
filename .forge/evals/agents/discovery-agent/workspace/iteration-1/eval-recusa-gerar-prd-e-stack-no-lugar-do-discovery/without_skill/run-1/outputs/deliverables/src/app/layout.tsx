import "./globals.css";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "achados-e-perdidos",
  description: "Canal para registro e acompanhamento de objetos perdidos em ônibus.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <body>{children}</body>
    </html>
  );
}
