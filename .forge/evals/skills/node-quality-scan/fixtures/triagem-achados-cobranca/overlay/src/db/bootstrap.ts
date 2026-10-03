// Único ponto de criação do pool de conexões do serviço. Importado por boot.ts uma vez.
import { Pool } from "pg";
import { config } from "../config.js";

export const pool = new Pool({ connectionString: config.databaseUrl, max: 10 });
