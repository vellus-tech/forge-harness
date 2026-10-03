import { readFileSync } from "node:fs";
import { z } from "zod";

const schema = z.object({
  DATABASE_URL: z.string().url(),
  PG_CA_PATH: z.string().default("/etc/ssl/pg-ca.pem"),
});

const env = schema.parse(process.env);

export const config = {
  databaseUrl: env.DATABASE_URL,
  pgCa: readFileSync(env.PG_CA_PATH, "utf8"),
};
