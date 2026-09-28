function obrigatoria(nome: string): string {
  const v = process.env[nome];
  if (!v) throw new Error(`variável de ambiente ausente: ${nome}`);
  return v;
}

export const config = {
  databaseUrl: obrigatoria("DATABASE_URL"),
  porta: Number(process.env.PORT ?? 8080),
  certPath: process.env.TLS_CERT_PATH ?? "./certs/dev.pem",
};
