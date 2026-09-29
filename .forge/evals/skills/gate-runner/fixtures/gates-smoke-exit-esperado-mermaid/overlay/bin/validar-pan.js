#!/usr/bin/env node
// Valida um PAN pelo algoritmo de Luhn antes de enviar para tokenização.
// Códigos de saída: 0 = PAN válido, 2 = PAN inválido, 64 = uso incorreto.
const pan = process.argv[2];
if (!pan || !/^\d{12,19}$/.test(pan)) {
  process.stderr.write('uso: validar-pan <PAN com 12 a 19 dígitos>\n');
  process.exit(64);
}
let soma = 0;
let dobrar = false;
for (let i = pan.length - 1; i >= 0; i--) {
  let d = Number(pan[i]);
  if (dobrar) { d *= 2; if (d > 9) d -= 9; }
  soma += d;
  dobrar = !dobrar;
}
if (soma % 10 !== 0) {
  process.stderr.write('PAN inválido (Luhn)\n');
  process.exit(2);
}
process.stdout.write('PAN válido\n');
