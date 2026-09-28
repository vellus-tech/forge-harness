import { test } from "node:test";
import assert from "node:assert";
import { RecargaService } from "../src/recarga/recargaService.js";

test("RecargaService rejeita valor abaixo do mínimo", () => {
  assert.throws(() => new RecargaService().validarValor(100));
});
