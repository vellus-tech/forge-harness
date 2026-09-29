import express from "express";
import pg from "pg";
import { createPgRecargaRepository } from "./recargas/repository.js";
import { recargaRoutes } from "./recargas/routes.js";

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
export const app = express();
app.use(express.json({ limit: "16kb" }));
app.use(recargaRoutes(createPgRecargaRepository(pool)));
