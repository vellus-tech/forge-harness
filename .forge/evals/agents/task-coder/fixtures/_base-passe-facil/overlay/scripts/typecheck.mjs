// Verificação barata: importa todo .ts de produção em apps/web (type stripping do Node falha em sintaxe inválida).
import { readdirSync, statSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
const raiz = resolve('apps/web');
const arquivos = [];
const varrer = (dir) => { for (const nome of readdirSync(dir)) { const p = join(dir, nome); if (statSync(p).isDirectory()) varrer(p); else if (p.endsWith('.ts') && !p.endsWith('.test.ts')) arquivos.push(p); } };
varrer(raiz);
for (const a of arquivos) await import(pathToFileURL(a).href);
console.log(`typecheck ok: ${arquivos.length} arquivo(s)`);
