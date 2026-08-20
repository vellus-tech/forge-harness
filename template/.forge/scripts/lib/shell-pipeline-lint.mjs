#!/usr/bin/env node
// lib/shell-pipeline-lint.mjs — detector da forma `<produtor> | grep -q … || <ação>` (issue #49).
//
// Por que esta forma específica, e não "pipe" em geral: `grep -q` sai no PRIMEIRO casamento. Se o
// produtor ainda tem o que escrever, ele leva SIGPIPE, o pipeline devolve 141, e sob `pipefail`
// isso vira falha do pipeline INTEIRO. O `||` na sequência então executa a ação de "não casou" —
// `continue`, `exit`, um default — para uma linha que CASAVA. Com `&&`, o efeito é o inverso e
// pior: a asserção do lado direito não roda, e o teste passa sem ter medido nada. Medido no
// Axis.PadSimulator: 57 exit codes anômalos em 300 execuções com pipe, zero em 300 sem, sobre o
// parser cujo trabalho era exatamente não perder declaração.
//
// O produtor importa. `echo "$x" | grep -q …` e `printf '%s' "$x" | grep -q …` escrevem UMA
// string curta, que cabe inteira no buffer do pipe antes de o `grep` sair — não há escrita
// pendente, não há SIGPIPE. Acusar essas duas formas encheria o lint de falso positivo, e um lint
// ruidoso é desligado; o alvo são os produtores que continuam produzindo (`sed`, `awk`, `cat`,
// `node`, `git`, funções do próprio script).
//
// Correção esperada: capturar a saída ANTES do pipe e casar sem pipeline —
//   out="$(cmd 2>&1 || true)"
//   grep -q 'pat' <<<"$out" || { …; }        # here-string: comando único, rc é o do grep
// ou trocar o casamento por construção nativa (`case "$out" in *pat*) … esac`).
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';

// Mesmos diretórios gerados/vendored que o coletor dos gates de governança já ignora.
export const SKIP_DIRS = new Set([
  'node_modules', '.git', 'dist', 'build', 'out', 'coverage', '.next', 'vendor',
  '.venv', '__pycache__', '.turbo', '.cache', '.idea', '.vs',
]);

// Produtores cuja saída é uma string curta escrita de uma vez: sem escrita pendente quando o
// `grep -q` sai, sem SIGPIPE, sem 141.
export const SAFE_PRODUCERS = new Set(['echo', 'printf', ':', 'true', 'false']);

// `grep` (ou variantes) com a flag -q em qualquer combinação (-q, -qE, -Eq, -Fq, -qi, -qx…),
// seguido, na MESMA linha, de `||` ou `&&`.
const GREP_Q = /\|\s*(?:[A-Za-z_][A-Za-z0-9_]*=\S+\s+)*grep\b[^|]*?\s-[A-Za-z]*q[A-Za-z]*\b[^|]*?(\|\||&&)/;

// Qual comando escreve NO pipe. Precisa recortar tudo que vem antes dele na mesma linha —
// `if … ; then`, `{`, `&&`, `||`, `;`, atribuições de ambiente — senão o produtor reportado vira
// o `[` do teste anterior e um `echo` seguro passa por inseguro (e vice-versa).
export function producerOf(line, pipeIdx) {
  let seg = line.slice(0, pipeIdx);
  // Último separador de comando antes do pipe: o produtor é o que vem DEPOIS dele.
  const cut = /(?:;|&&|\|\||\{|\(|\bthen\b|\bdo\b|\belse\b|\|)/g;
  let last = -1, m;
  while ((m = cut.exec(seg)) !== null) last = m.index + m[0].length;
  if (last >= 0) seg = seg.slice(last);
  seg = seg.replace(/^\s+/, '')
    .replace(/^(?:!|if|while|until|elif)\s+/, '')
    .replace(/^(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)+/, '');
  const m2 = seg.match(/^[^\s;|&]+/);
  return m2 ? m2[0] : '';
}

export function lintText(text) {
  const findings = [];
  const lines = text.split('\n');
  lines.forEach((line, i) => {
    if (/^\s*#/.test(line)) return;                 // comentário: prosa, não código
    const m = line.match(GREP_Q);
    if (!m) return;
    const pipeIdx = line.indexOf(m[0]);
    const producer = producerOf(line, pipeIdx);
    if (SAFE_PRODUCERS.has(producer)) return;
    findings.push({
      lineNo: i + 1,
      op: m[1],
      producer: producer || '(indeterminado)',
      line: line.trim(),
    });
  });
  return findings;
}

export function collectShellFiles(paths) {
  const acc = [];
  const walk = (p) => {
    const rp = resolve(p);
    if (!existsSync(rp)) return;
    const st = statSync(rp);
    if (st.isDirectory()) {
      for (const e of readdirSync(rp, { withFileTypes: true })) {
        if (e.isDirectory()) { if (!SKIP_DIRS.has(e.name)) walk(join(rp, e.name)); }
        else if (e.name.endsWith('.sh') || e.name.endsWith('.bash')) acc.push(join(rp, e.name));
      }
    } else if (rp.endsWith('.sh') || rp.endsWith('.bash')) acc.push(rp);
  };
  for (const p of [].concat(paths)) walk(p);
  return acc.sort();
}
