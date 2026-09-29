export const config = {
  databaseUrl: process.env.DATABASE_URL ?? "",
  port: Number(process.env.PORT ?? 3000),
};
