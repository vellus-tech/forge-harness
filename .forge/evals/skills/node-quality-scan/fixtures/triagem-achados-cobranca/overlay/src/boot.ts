import { readFileSync } from "node:fs";
import Fastify from "fastify";
import { config } from "./config.js";
import { pool } from "./db/bootstrap.js";
import { PgCobrancaRepository } from "./infra/PgCobrancaRepository.js";
import { registrarRotas } from "./rotas.js";

// Carregado uma única vez, antes de o servidor aceitar conexões.
const cert = readFileSync(config.certPath, "utf8");

const app = Fastify({ https: { cert, key: cert } as never });
registrarRotas(app, new PgCobrancaRepository(pool));
await app.listen({ port: config.porta, host: "0.0.0.0" });
