import { Pool } from "pg";
import { config } from "../config/load.js";

export const pool = new Pool({ connectionString: config.databaseUrl, max: 10, ssl: { ca: config.pgCa } });
