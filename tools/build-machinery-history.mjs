#!/usr/bin/env node
// Gera template/machinery-history.json: o sha256 de cada arquivo de maquinaria em cada versão PUBLICADA do template (tags v*), por caminho relativo a .forge/.
//
// POR QUE EXISTE. O `forge update` preserva a maquinaria em deriva local (revisão da DH-1) e só sobrescreve o que consegue provar intocado. Com `.forge/cache/machinery.lock` a prova é o sha registrado na última aplicação; sem lock (consumidor que só rodou `init`, clone novo, outra máquina — `.forge/cache/` é ignorado pelo .gitignore gerenciado), a prova é este histórico: um arquivo local byte-idêntico a alguma versão publicada do template nunca foi tocado pelo consumidor, e recebe o template novo como `ATUALIZADO`. Sem o histórico, o update congelava toda a maquinaria de quem não tinha lock — medido: consumidor pristino da 0.15.0 com 22 de 22 arquivos alterados retidos, inclusive o gancho de segredos da #125.
//
// Uso (da raiz do repositório):
//   node tools/build-machinery-history.mjs                     regenera a partir das tags v* alcançáveis de HEAD, em união com o arquivo existente (nunca remove entrada)
//   node tools/build-machinery-history.mjs --release v0.16.0   idem, e acrescenta a árvore de trabalho de template/.forge como a versão sendo publicada (rodar no PR de release)
//   node tools/build-machinery-history.mjs --check             rc 1 se alguma tag v* alcançável de HEAD tem (caminho, sha) ausente do arquivo versionado; não escreve nada
//
// Determinístico: chaves e listas ordenadas, sem data. Zero dependências.
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative, sep } from 'node:path';

const ROOT = execFileSync('git', ['rev-parse', '--show-toplevel'], { encoding: 'utf8' }).trim();
const OUT = join(ROOT, 'template', 'machinery-history.json');
const PREFIX = 'template/.forge/';
// Mesmo recorte de machineryFiles() em bin/forge.mjs: MACHINERY_DIRS inteiros, adapters/*.yaml (sem *.lock.yaml) e README.md.
const MACHINERY_DIRS = ['agents', 'capabilities', 'commands', 'contracts', 'hooks', 'schemas', 'scripts', 'skills', 'templates', 'rules'];
const isMachinery = (rel) => {
  const parts = rel.split('/');
  if (parts[parts.length - 1] === '.DS_Store') return false;
  if (MACHINERY_DIRS.includes(parts[0])) return true;
  if (parts.length === 2 && parts[0] === 'adapters') return parts[1].endsWith('.yaml') && !parts[1].endsWith('.lock.yaml');
  return rel === 'README.md';
};
const sha256 = (buf) => createHash('sha256').update(buf).digest('hex');

const args = process.argv.slice(2);
const check = args.includes('--check');
const relIdx = args.indexOf('--release');
const release = relIdx === -1 ? '' : (args[relIdx + 1] || '');
if (relIdx !== -1 && !/^v\d+\.\d+\.\d+/.test(release)) { console.error('FAIL: --release exige a versão (ex.: --release v0.16.0)'); process.exit(2); }

const tags = execFileSync('git', ['-C', ROOT, 'tag', '--merged', 'HEAD', '-l', 'v*'], { encoding: 'utf8' }).split('\n').filter(Boolean)
  .sort((a, b) => a.localeCompare(b, 'en', { numeric: true }));
if (!tags.length) { console.error('FAIL: nenhuma tag v* alcançável de HEAD — rode `git fetch --tags` (o histórico de versões publicadas vem delas)'); process.exit(1); }

// (caminho -> Set(sha256)) de todas as tags, lendo cada blob uma vez só via `git cat-file --batch`.
const byBlob = new Map(); // blob sha1 -> [rel...]
const pairs = [];         // [rel, blob]
for (const tag of tags) {
  const ls = execFileSync('git', ['-C', ROOT, 'ls-tree', '-r', '--full-tree', tag, '--', PREFIX], { encoding: 'utf8', maxBuffer: 64 << 20 });
  for (const line of ls.split('\n')) {
    const m = /^(\d{6}) blob ([0-9a-f]+)\t(.+)$/.exec(line);
    if (!m || !['100644', '100755'].includes(m[1])) continue; // symlink/submódulo: o update copia arquivos regulares
    const rel = m[3].slice(PREFIX.length);
    if (!isMachinery(rel)) continue;
    pairs.push([rel, m[2]]);
    byBlob.set(m[2], null);
  }
}
const blobs = [...byBlob.keys()];
const raw = execFileSync('git', ['-C', ROOT, 'cat-file', '--batch'], { input: blobs.join('\n') + '\n', maxBuffer: 1 << 30 });
let off = 0;
for (const b of blobs) {
  const nl = raw.indexOf(10, off);
  const header = raw.subarray(off, nl).toString('utf8');
  const hm = /^([0-9a-f]+) blob (\d+)$/.exec(header);
  if (!hm || hm[1] !== b) { console.error(`FAIL: resposta inesperada do git cat-file para ${b}: ${header}`); process.exit(1); }
  const size = Number(hm[2]);
  byBlob.set(b, sha256(raw.subarray(nl + 1, nl + 1 + size)));
  off = nl + 1 + size + 1;
}
const fromTags = new Map();
const add = (map, rel, h) => { if (!map.has(rel)) map.set(rel, new Set()); map.get(rel).add(h); };
for (const [rel, b] of pairs) add(fromTags, rel, byBlob.get(b));

const readExisting = () => {
  if (!existsSync(OUT)) return { versions: [], paths: new Map() };
  const j = JSON.parse(readFileSync(OUT, 'utf8'));
  const paths = new Map();
  for (const [rel, arr] of Object.entries(j.paths || {})) for (const h of arr) add(paths, rel, h);
  return { versions: j.versions || [], paths };
};

if (check) {
  const cur = readExisting();
  const faltam = [];
  for (const [rel, set] of fromTags) for (const h of set) if (!(cur.paths.get(rel) && cur.paths.get(rel).has(h))) faltam.push(`${rel} ${h.slice(0, 12)}`);
  const tagsFora = tags.filter((t) => !cur.versions.includes(t));
  if (faltam.length || tagsFora.length) {
    console.error(`FAIL: template/machinery-history.json defasado — ${faltam.length} par(es) (caminho, sha) de versões publicadas ausentes; tags não registradas: ${tagsFora.join(', ') || '(nenhuma)'}`);
    for (const f of faltam.slice(0, 10)) console.error(`  falta: ${f}`);
    console.error('  Regenere com `node tools/build-machinery-history.mjs` e commite o arquivo.');
    process.exit(1);
  }
  console.log(`OK machinery-history: ${tags.length} tag(s) cobertas`);
  process.exit(0);
}

const cur = readExisting();
const merged = cur.paths;
for (const [rel, set] of fromTags) for (const h of set) add(merged, rel, h);
const versions = new Set([...cur.versions, ...tags]);
if (release) {
  const base = join(ROOT, PREFIX);
  const walk = (d) => readdirSync(d).flatMap((e) => { const p = join(d, e); return statSync(p).isDirectory() ? walk(p) : [p]; });
  for (const f of walk(base)) {
    const rel = relative(base, f).split(sep).join('/');
    if (isMachinery(rel)) add(merged, rel, sha256(readFileSync(f)));
  }
  versions.add(release);
}
const paths = {};
for (const rel of [...merged.keys()].sort()) paths[rel] = [...merged.get(rel)].sort();
const doc = {
  schema: 'forge-machinery-history/v1',
  nota: 'sha256 de cada arquivo de maquinaria (caminho relativo a .forge/) em cada versão publicada do template. Lido pelo `forge update` para provar que um arquivo sem entrada no machinery.lock está intocado. Gerado por tools/build-machinery-history.mjs — não edite à mão.',
  versions: [...versions].sort((a, b) => a.localeCompare(b, 'en', { numeric: true })),
  paths,
};
writeFileSync(OUT, JSON.stringify(doc, null, 1) + '\n');
console.log(`OK machinery-history: ${doc.versions.length} versão(ões), ${Object.keys(paths).length} caminho(s), ${Object.values(paths).reduce((n, a) => n + a.length, 0)} sha(s) → ${relative(ROOT, OUT)}`);
