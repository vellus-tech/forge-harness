const [lib] = process.argv.slice(2);
const { normalizePath } = await import(`${lib}/route-scan.mjs`);
const { forAll, gen } = await import(`${lib}/pbt.mjs`);

// Gera path a partir de segmentos que exercitam as três normalizações, mais o caso vazio (que
// produz barra dupla) e a barra final. Sem esses dois, a propriedade passaria por degeneração.
const SEG = ['a', 'b', 'items', '{id}', '{id:long}', ':name', '<x>', 'v1', '', '*'];
const pathGen = gen.array(gen.oneOf(SEG), 1, 5);

const r = forAll([pathGen, gen.bool()], (segs, barraFinal) => {
  const p = `/${segs.join('/')}${barraFinal ? '/' : ''}`;
  const uma = normalizePath(p);
  return normalizePath(uma) === uma;
}, { runs: 300 });
if (!r.ok) { console.error(`normalizePath não é idempotente: ${JSON.stringify(r.counterexample)}`); process.exit(1); }

// Controle da própria propriedade: o gerador precisa de fato produzir path que MUDA na primeira
// normalização, senão idempotência é trivialmente verdadeira e a asserção não vale nada.
let mudou = 0;
const rnd = (await import(`${lib}/pbt.mjs`)).makeRandom(7);
for (let i = 0; i < 200; i += 1) {
  const segs = pathGen.generate(rnd, i / 199);
  const p = `/${segs.join('/')}`;
  if (normalizePath(p) !== p) mudou += 1;
}
if (mudou < 20) { console.error(`gerador degenerado: só ${mudou}/200 paths mudam na normalização`); process.exit(1); }
