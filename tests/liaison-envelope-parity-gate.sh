#!/usr/bin/env bash
# ORDINAL: wNNN atribuído na hora do merge
# Gate — paridade de envelope cross-session (REQ-02) e compatibilidade com peer de harness antigo
# (design §4.1, §4.2):
#   [1] a tag v0.18.0 existe neste clone — ausente é "não verificável", NUNCA verde por vacuidade
#       (clone raso de CI não prova compatibilidade)
#   [2] bateria de envelopes válidos e inválidos dá o MESMO veredito no validador mínimo de schema
#       (reimplementação, aqui, das palavras-chave efetivamente usadas pelo schema) e em
#       validateEnvelope (lib/liaison-merge.mjs) — enum `via`, exclusão `cross_session`/`via` nos
#       dois sentidos, os cinco subcampos obrigatórios, teto de 128 caracteres, caractere de
#       controle, padrão do fingerprint e propriedade não declarada
#   [3] um bundle com uma mensagem `via: cross-session` é importado SEM CONFLITO pelos módulos de
#       import extraídos da tag v0.18.0 (liaison-merge.mjs + liaison-import.mjs, num diretório
#       temporário) — peer de harness antigo aceita a mensagem nova, e os campos chegam intactos
#       no log de destino (`trust` reescrito para untrusted-peer pela própria política de import)
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-liaison-envelope-parity.XXXXXX)"
trap 'rm -rf "$T"' EXIT

LIBDIR="$WS/template/.forge/scripts/lib"
SCHEMA="$WS/template/.forge/schemas/liaison-message.schema.json"

[ -f "$LIBDIR/liaison-merge.mjs" ] || { echo "FAIL [0]: $LIBDIR/liaison-merge.mjs ausente" >&2; exit 1; }
[ -f "$SCHEMA" ] || { echo "FAIL [0]: $SCHEMA ausente" >&2; exit 1; }

echo "[1] tag v0.18.0 existe neste clone"
if ! git -C "$WS" rev-parse -q --verify "refs/tags/v0.18.0" >/dev/null 2>&1; then
  echo "FAIL [1]: tag v0.18.0 ausente neste clone — não verificável (clone raso de CI não prova" >&2
  echo "  compatibilidade com peer de harness antigo; nunca reportar verde por vacuidade aqui)" >&2
  exit 1
fi
echo "OK [1] — tag v0.18.0 presente"

echo "[2] bateria de paridade: schema (validador mínimo) × validateEnvelope"
node - "$SCHEMA" "$LIBDIR" <<'NODEEOF'
const { readFileSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , schemaPath, lib] = process.argv;
  const schema = JSON.parse(readFileSync(schemaPath, 'utf8'));
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);

  // Validador mínimo de JSON Schema — só as palavras-chave que ESTE schema de fato usa (medido
  // por grep antes de escrever isto): type, const, enum, pattern, minLength, maxLength, minimum,
  // minItems, items, required, properties, additionalProperties, allOf, if/then, not. Não é um
  // validador de schema genérico — generalizar além disso seria reimplementar ajv sem precisão.
  function typeOk(type, v) {
    const types = Array.isArray(type) ? type : [type];
    return types.some((t) => {
      switch (t) {
        case 'object': return v !== null && typeof v === 'object' && !Array.isArray(v);
        case 'array': return Array.isArray(v);
        case 'string': return typeof v === 'string';
        case 'integer': return typeof v === 'number' && Number.isInteger(v);
        case 'number': return typeof v === 'number';
        case 'boolean': return typeof v === 'boolean';
        case 'null': return v === null;
        default: return true;
      }
    });
  }
  function schemaValidate(sch, value, path = '$') {
    const errors = [];
    if (sch.type !== undefined && !typeOk(sch.type, value)) {
      errors.push(`${path}: tipo esperado ${JSON.stringify(sch.type)}, recebido ${JSON.stringify(value)}`);
      return errors;
    }
    if (sch.const !== undefined && value !== sch.const) {
      errors.push(`${path}: esperado const ${JSON.stringify(sch.const)}, recebido ${JSON.stringify(value)}`);
    }
    if (sch.enum !== undefined && !sch.enum.includes(value)) {
      errors.push(`${path}: valor '${value}' fora do enum ${JSON.stringify(sch.enum)}`);
    }
    if (typeof value === 'string') {
      if (sch.pattern !== undefined && !new RegExp(sch.pattern).test(value)) {
        errors.push(`${path}: '${value}' não casa o padrão ${sch.pattern}`);
      }
      if (sch.minLength !== undefined && value.length < sch.minLength) {
        errors.push(`${path}: comprimento ${value.length} menor que minLength ${sch.minLength}`);
      }
      if (sch.maxLength !== undefined && value.length > sch.maxLength) {
        errors.push(`${path}: comprimento ${value.length} maior que maxLength ${sch.maxLength}`);
      }
    }
    if (typeof value === 'number' && sch.minimum !== undefined && value < sch.minimum) {
      errors.push(`${path}: ${value} menor que minimum ${sch.minimum}`);
    }
    if (Array.isArray(value)) {
      if (sch.minItems !== undefined && value.length < sch.minItems) {
        errors.push(`${path}: array com ${value.length} item(ns), menor que minItems ${sch.minItems}`);
      }
      if (sch.items) value.forEach((item, i) => errors.push(...schemaValidate(sch.items, item, `${path}[${i}]`)));
    }
    if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
      if (Array.isArray(sch.required)) {
        for (const field of sch.required) if (value[field] === undefined) errors.push(`${path}: campo obrigatório ausente: ${field}`);
      }
      if (sch.properties) {
        for (const [key, sub] of Object.entries(sch.properties)) {
          if (value[key] !== undefined) errors.push(...schemaValidate(sub, value[key], `${path}.${key}`));
        }
      }
      if (sch.additionalProperties === false) {
        const known = new Set(Object.keys(sch.properties || {}));
        for (const key of Object.keys(value)) if (!known.has(key)) errors.push(`${path}: propriedade não declarada '${key}'`);
      }
    }
    if (Array.isArray(sch.allOf)) for (const sub of sch.allOf) errors.push(...schemaValidate(sub, value, path));
    if (sch.if) {
      const ifErrs = schemaValidate(sch.if, value, path);
      if (ifErrs.length === 0 && sch.then) errors.push(...schemaValidate(sch.then, value, path));
      else if (ifErrs.length > 0 && sch.else) errors.push(...schemaValidate(sch.else, value, path));
    }
    if (sch.not) {
      const notErrs = schemaValidate(sch.not, value, path);
      if (notErrs.length === 0) errors.push(`${path}: deveria reprovar 'not' e passou`);
    }
    return errors;
  }

  const SHA = 'a'.repeat(64);
  const base = (over = {}) => ({
    msg_id: 'peer-b-0001', channel: 'c', thread_id: 't', sender: 'peer-b', seq: 1, lamport: 1,
    kind: 'note', requires_ack: false, subject: 's', created_at: '2026-01-01T00:00:00Z',
    content_sha: SHA, trust: 'self',
    ...over,
  });
  const crossSession = (over = {}) => ({
    from_addr: 'uds:/tmp/cc-socks/999.sock', from_name: 'PEER-FIXTURE', from_mode: 'default',
    native_ref: 'b'.repeat(64), origin_verified: true,
    ...over,
  });

  const fixtures = [
    { label: 'baseline-sem-via', expect: true, msg: base() },
    { label: 'via-ask-peer-legado', expect: true, msg: base({ via: 'ask-peer', authored_by: 'peer-a', trust: 'untrusted-peer' }) },
    { label: 'via-divergence-resolve-legado', expect: true, msg: base({ via: 'divergence-resolve', trust: 'untrusted-peer', resolves: { sender: 'peer-a', seq: 1 } }) },
    { label: 'cross-session-completo', expect: true, msg: base({ via: 'cross-session', authored_by: 'peer-b', trust: 'untrusted-peer', cross_session: crossSession() }) },
    { label: 'cross-session-sem-cross_session', expect: false, msg: base({ via: 'cross-session', authored_by: 'peer-b', trust: 'untrusted-peer' }) },
    { label: 'cross-session-sem-authored_by', expect: false, msg: base({ via: 'cross-session', trust: 'untrusted-peer', cross_session: crossSession() }) },
    { label: 'cross_session-sem-via', expect: false, msg: base({ authored_by: 'peer-b', trust: 'untrusted-peer', cross_session: crossSession() }) },
    { label: 'cross_session-via-errado', expect: false, msg: base({ via: 'ask-peer', authored_by: 'peer-b', trust: 'untrusted-peer', cross_session: crossSession() }) },
    { label: 'cross_session-campo-faltando', expect: false, msg: base({ via: 'cross-session', authored_by: 'peer-b', trust: 'untrusted-peer', cross_session: crossSession({ native_ref: undefined }) }) },
    { label: 'cross_session-native_ref-invalido', expect: false, msg: base({ via: 'cross-session', authored_by: 'peer-b', trust: 'untrusted-peer', cross_session: crossSession({ native_ref: 'NAO-E-HEX' }) }) },
    { label: 'cross_session-campo-extra', expect: false, msg: base({ via: 'cross-session', authored_by: 'peer-b', trust: 'untrusted-peer', cross_session: crossSession({ foo: 'bar' }) }) },
    { label: 'cross_session-from_addr-excede-128', expect: false, msg: base({ via: 'cross-session', authored_by: 'peer-b', trust: 'untrusted-peer', cross_session: crossSession({ from_addr: 'uds:' + 'x'.repeat(130) }) }) },
    { label: 'cross_session-caractere-controle', expect: false, msg: base({ via: 'cross-session', authored_by: 'peer-b', trust: 'untrusted-peer', cross_session: crossSession({ from_name: 'PEER\u0007FIXTURE' }) }) },
  ];
  // campo undefined explícito no objeto não deve ser confundido com ausente pelo JSON real — a
  // bateria usa JSON.parse(JSON.stringify(...)) para que `native_ref: undefined` se torne
  // ausência de chave, exatamente como um envelope lido de disco.
  for (const f of fixtures) f.msg = JSON.parse(JSON.stringify(f.msg));

  let n = 1;
  for (const f of fixtures) {
    const schemaErrs = schemaValidate(schema, f.msg);
    const envErrs = M.validateEnvelope(f.msg);
    const schemaValid = schemaErrs.length === 0;
    const envValid = envErrs.length === 0;
    if (schemaValid !== f.expect || envValid !== f.expect) {
      console.error(`FAIL [2]: fixture #${n} '${f.label}' (via=${f.msg.via || 'ausente'}, cross_session=${f.msg.cross_session ? 'presente' : 'ausente'}) — esperado ${f.expect ? 'válido' : 'inválido'}, schema disse ${schemaValid ? 'válido' : 'inválido'} (${schemaErrs.join('; ') || '—'}), validateEnvelope disse ${envValid ? 'válido' : 'inválido'} (${envErrs.join('; ') || '—'})`);
      process.exit(1);
    }
    n++;
  }
  console.log(`OK [2] — ${fixtures.length} fixture(s) em paridade (schema × validateEnvelope, mesmo veredito dos dois)`);
})();
NODEEOF

echo "[3] import de 'via: cross-session' pelos módulos de import extraídos da tag v0.18.0 — zero conflito"
LEGACY="$T/legacy/lib"
mkdir -p "$LEGACY"
git -C "$WS" show "v0.18.0:template/.forge/scripts/lib/liaison-merge.mjs" > "$LEGACY/liaison-merge.mjs"
git -C "$WS" show "v0.18.0:template/.forge/scripts/lib/liaison-import.mjs" > "$LEGACY/liaison-import.mjs"

DEST="$T/dest-channel"
BUNDLE="$T/bundle"
mkdir -p "$DEST/log" "$DEST/blobs" "$DEST/conflicts" "$BUNDLE/log" "$BUNDLE/blobs"

node - "$LEGACY" "$BUNDLE" "$DEST" <<'NODEEOF'
const { writeFileSync, readFileSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , legacyLib, bundleDir, destDir] = process.argv;
  const M = await import(pathToFileURL(join(legacyLib, 'liaison-merge.mjs')).href);
  const { applyBundle } = await import(pathToFileURL(join(legacyLib, 'liaison-import.mjs')).href);

  const partial = {
    msg_id: 'peer-cross-0001', channel: 'peer-channel', thread_id: 'thread-x', sender: 'peer-cross',
    seq: 1, lamport: 1, kind: 'note', in_reply_to: null, requires_ack: false,
    subject: 'mensagem cross-session de fixture',
    refs: { change_id: null, contract_files: [], commit: null },
    created_at: '2026-10-30T00:00:00Z',
    authored_by: 'peer-cross-origin-repo', via: 'cross-session',
    cross_session: {
      from_addr: 'uds:/tmp/cc-socks/999.sock', from_name: 'PEER-CROSS', from_mode: 'default',
      native_ref: 'c'.repeat(64), origin_verified: false,
    },
  };
  const sha = M.computeContentSha(partial);
  const msg = { ...partial, content_sha: sha, trust: 'untrusted-peer' };

  writeFileSync(join(bundleDir, 'log', 'peer-cross.jsonl'), JSON.stringify(msg) + '\n');

  const r = applyBundle({ chDir: destDir, fromDir: bundleDir, self: 'local-me' });
  if (r.conflicts !== 0) {
    console.error(`FAIL [3]: import pelos módulos v0.18.0 produziu ${r.conflicts} conflito(s) — peer de harness antigo deveria aceitar a mensagem via:cross-session sem conflito (mudança aditiva, design §4.2)`);
    process.exit(1);
  }
  const written = readFileSync(join(destDir, 'log', 'peer-cross.jsonl'), 'utf8').trim().split('\n').map((l) => JSON.parse(l));
  const got = written.find((m) => m.msg_id === 'peer-cross-0001');
  if (!got) { console.error('FAIL [3]: mensagem não apareceu no log de destino após o import'); process.exit(1); }
  if (got.via !== 'cross-session' || !got.cross_session || got.cross_session.native_ref !== 'c'.repeat(64)) {
    console.error(`FAIL [3]: campos via/cross_session não chegaram intactos no destino: ${JSON.stringify(got)}`);
    process.exit(1);
  }
  if (got.trust !== 'untrusted-peer') {
    console.error(`FAIL [3]: trust no destino deveria ser 'untrusted-peer' (política de import), veio '${got.trust}'`);
    process.exit(1);
  }
  console.log('OK [3] — import pela v0.18.0 aceitou a mensagem cross-session sem conflito, campos intactos, trust=untrusted-peer');
})();
NODEEOF

echo "PASS liaison-envelope-parity-gate"
