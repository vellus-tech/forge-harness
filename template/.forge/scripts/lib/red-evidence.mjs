// lib/red-evidence.mjs — leitura e validação à mão de evidence/red/red-evidence.json
// (schema red-evidence/v1, template/.forge/schemas/red-evidence.schema.json). Espelha as
// regras do schema sem depender de ajv em runtime (mesmo padrão de validate-spec.mjs).
// Puro quanto possível: loadRedEvidence é o único ponto de I/O; o resto opera sobre o
// objeto já lido.
import { readFileSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';

export const REL_PATH = 'evidence/red/red-evidence.json';

export const STATUSES = ['pending', 'observed', 'waived', 'not-possible'];
export const CLASSIFICATIONS = ['behavioral', 'build-error', 'unknown'];
export const WAIVER_REASONS = ['non-behavioral', 'no-test-infra', 'external-unreproducible', 'hotfix-under-incident'];
// Estratégias de derivação da árvore base (lib/red-replay.mjs). Exportada em vez de repetida em
// literal: a lista vivia em dois lugares (aqui e no schema JSON) e o valor novo 'test-graft'
// chegou ao motor sem chegar ao validador — o change ficava travado com a evidência que ele
// mesmo acabara de produzir.
export const BASE_STRATEGIES = ['ancestry', 'revert-synthesis', 'test-graft'];

// ENTRY_SCALAR_FIELDS — os campos por-defeito que hoje moram no topo (Onda #139: entries[]).
// Fonte única para quem projeta o topo a partir de entries[0] (lib/red-evidence-ops.mjs) e para
// quem valida cada entrada aqui — evita que as duas listas divirjam como a de STATUSES/
// CLASSIFICATIONS antes desta constante existir. Exclui 'id', 'status', 'fix_files' e 'waiver',
// que têm forma/validação própria (ver validateEntryFields abaixo).
export const ENTRY_SCALAR_FIELDS = [
  'test_path', 'test_id', 'command', 'base_commit', 'failure_pattern', 'excerpt', 'excerpt_sha256',
  'classification', 'base_result', 'base_strategy', 'graft_from', 'revert_patch', 'replay_head',
  'setup_command', 'reproduces', 'recorded_at', 'replayed_at', 'waived_at',
];

// validateEntryFields: mesma checagem de tipo/enum/pattern do topo, aplicada a um item de
// entries[] (Onda #139). Duplicada em vez de compartilhada com validateRedEvidence porque o topo
// tem campos que uma entrada não tem (schema, change_id) e vice-versa (id) — extrair um
// compartilhamento genérico arriscaria o validador do topo, já em produção, por um ganho de DRY
// que a lista ENTRY_SCALAR_FIELDS acima já cobre para o risco real (as duas listas divergirem).
function validateEntryFields(e, idx, errors) {
  const p = `entries[${idx}]`;
  if (!e || typeof e !== 'object' || Array.isArray(e)) { errors.push(`${p}: not an object`); return; }
  if (e.id !== undefined && e.id !== null && typeof e.id !== 'string') errors.push(`${p}.id must be string|null`);
  if (!STATUSES.includes(e.status)) errors.push(`${p}.status invalid: ${e.status} (allowed: ${STATUSES.join('|')})`);
  for (const k of ['test_path', 'test_id', 'command', 'failure_pattern', 'excerpt', 'reproduces'])
    if (e[k] !== undefined && e[k] !== null && typeof e[k] !== 'string') errors.push(`${p}.${k} must be string|null`);
  if (e.base_commit !== undefined && e.base_commit !== null) {
    if (typeof e.base_commit !== 'string' || !/^[a-f0-9]{7,40}$/.test(e.base_commit))
      errors.push(`${p}.base_commit must match ^[a-f0-9]{7,40}$`);
  }
  if (e.excerpt_sha256 !== undefined && e.excerpt_sha256 !== null) {
    if (typeof e.excerpt_sha256 !== 'string' || !/^[a-f0-9]{64}$/.test(e.excerpt_sha256))
      errors.push(`${p}.excerpt_sha256 must be a 64-hex sha256`);
  }
  if (e.classification !== undefined && e.classification !== null && !CLASSIFICATIONS.includes(e.classification))
    errors.push(`${p}.classification invalid: ${e.classification} (allowed: ${CLASSIFICATIONS.join('|')}|null)`);
  if (e.base_result !== undefined && e.base_result !== null && !['failed', 'passed', 'unknown'].includes(e.base_result))
    errors.push(`${p}.base_result invalid: ${e.base_result} (allowed: failed|passed|unknown|null)`);
  if (e.base_strategy !== undefined && e.base_strategy !== null && !BASE_STRATEGIES.includes(e.base_strategy))
    errors.push(`${p}.base_strategy invalid: ${e.base_strategy} (allowed: ${BASE_STRATEGIES.join('|')}|null)`);
  if (e.graft_from !== undefined && e.graft_from !== null) {
    if (typeof e.graft_from !== 'string' || !/^[a-f0-9]{7,40}$/.test(e.graft_from))
      errors.push(`${p}.graft_from must match ^[a-f0-9]{7,40}$`);
  }
  for (const k of ['revert_patch', 'setup_command'])
    if (e[k] !== undefined && e[k] !== null && typeof e[k] !== 'string') errors.push(`${p}.${k} must be string|null`);
  if (e.replay_head !== undefined && e.replay_head !== null) {
    if (typeof e.replay_head !== 'string' || !/^[a-f0-9]{7,40}$/.test(e.replay_head))
      errors.push(`${p}.replay_head must match ^[a-f0-9]{7,40}$`);
  }
  if (e.fix_files !== undefined) {
    if (!Array.isArray(e.fix_files) || e.fix_files.some((f) => typeof f !== 'string'))
      errors.push(`${p}.fix_files must be an array of strings`);
  }
  if (e.waiver !== undefined && e.waiver !== null) {
    if (typeof e.waiver !== 'object' || Array.isArray(e.waiver)) errors.push(`${p}.waiver must be object|null`);
    else {
      if (!WAIVER_REASONS.includes(e.waiver.reason))
        errors.push(`${p}.waiver.reason invalid: ${e.waiver.reason} (allowed: ${WAIVER_REASONS.join('|')})`);
      if (e.waiver.deferral_id != null && !/^DEFER-[0-9]+/.test(e.waiver.deferral_id))
        errors.push(`${p}.waiver.deferral_id must match ^DEFER-[0-9]+`);
    }
  }
}

// validateRedEvidence(data): espelho do schema — additionalProperties:false não é
// reforçado aqui (não é o ponto de risco; a lista fixa de campos abaixo já é o contrato),
// mas todo campo presente é conferido quanto a tipo/enum/pattern.
export function validateRedEvidence(data) {
  const errors = [];
  if (!data || typeof data !== 'object' || Array.isArray(data)) return ['red-evidence: not an object'];
  if (data.schema !== 'red-evidence/v1') errors.push(`schema must be "red-evidence/v1": ${data.schema}`);
  if (typeof data.change_id !== 'string' || !data.change_id.length) errors.push('change_id missing');
  if (!STATUSES.includes(data.status)) errors.push(`status invalid: ${data.status} (allowed: ${STATUSES.join('|')})`);
  for (const k of ['test_path', 'test_id', 'command', 'failure_pattern', 'excerpt', 'reproduces'])
    if (data[k] !== undefined && data[k] !== null && typeof data[k] !== 'string') errors.push(`${k} must be string|null`);
  if (data.base_commit !== undefined && data.base_commit !== null) {
    if (typeof data.base_commit !== 'string' || !/^[a-f0-9]{7,40}$/.test(data.base_commit))
      errors.push('base_commit must match ^[a-f0-9]{7,40}$');
  }
  if (data.excerpt_sha256 !== undefined && data.excerpt_sha256 !== null) {
    if (typeof data.excerpt_sha256 !== 'string' || !/^[a-f0-9]{64}$/.test(data.excerpt_sha256))
      errors.push('excerpt_sha256 must be a 64-hex sha256');
  }
  if (data.classification !== undefined && data.classification !== null && !CLASSIFICATIONS.includes(data.classification))
    errors.push(`classification invalid: ${data.classification} (allowed: ${CLASSIFICATIONS.join('|')}|null)`);
  if (data.base_result !== undefined && data.base_result !== null && !['failed', 'passed', 'unknown'].includes(data.base_result))
    errors.push(`base_result invalid: ${data.base_result} (allowed: failed|passed|unknown|null)`);
  if (data.base_strategy !== undefined && data.base_strategy !== null && !BASE_STRATEGIES.includes(data.base_strategy))
    errors.push(`base_strategy invalid: ${data.base_strategy} (allowed: ${BASE_STRATEGIES.join('|')}|null)`);
  if (data.graft_from !== undefined && data.graft_from !== null) {
    if (typeof data.graft_from !== 'string' || !/^[a-f0-9]{7,40}$/.test(data.graft_from))
      errors.push('graft_from must match ^[a-f0-9]{7,40}$');
  }
  for (const k of ['revert_patch', 'setup_command'])
    if (data[k] !== undefined && data[k] !== null && typeof data[k] !== 'string') errors.push(`${k} must be string|null`);
  if (data.replay_head !== undefined && data.replay_head !== null) {
    if (typeof data.replay_head !== 'string' || !/^[a-f0-9]{7,40}$/.test(data.replay_head))
      errors.push('replay_head must match ^[a-f0-9]{7,40}$');
  }
  if (data.fix_files !== undefined) {
    if (!Array.isArray(data.fix_files) || data.fix_files.some((f) => typeof f !== 'string'))
      errors.push('fix_files must be an array of strings');
  }
  if (data.waiver !== undefined && data.waiver !== null) {
    if (typeof data.waiver !== 'object' || Array.isArray(data.waiver)) errors.push('waiver must be object|null');
    else {
      if (!WAIVER_REASONS.includes(data.waiver.reason))
        errors.push(`waiver.reason invalid: ${data.waiver.reason} (allowed: ${WAIVER_REASONS.join('|')})`);
      if (data.waiver.deferral_id != null && !/^DEFER-[0-9]+/.test(data.waiver.deferral_id))
        errors.push('waiver.deferral_id must match ^DEFER-[0-9]+');
    }
  }
  // entries — Onda #139 (issue #139): propriedade ADITIVA e opcional; um red-evidence.json
  // legado (centenas de changes de consumidores em voo) não tem esta chave e continua válido.
  if (data.entries !== undefined) {
    if (!Array.isArray(data.entries)) errors.push('entries must be an array');
    else data.entries.forEach((e, i) => validateEntryFields(e, i, errors));
  }
  return errors;
}

// loadRedEvidence(changeDir): { path, exists, data, errors }. Ausente ⇒ exists:false,
// data:null, errors:[] (não é erro — status implícito é "sem evidência", tratado pelo
// caller). Malformado (JSON inválido) ⇒ exists:true, data:null, errors com a mensagem.
export function loadRedEvidence(changeDir) {
  const path = join(resolve(changeDir), REL_PATH);
  if (!existsSync(path)) return { path, exists: false, data: null, errors: [] };
  let data;
  try { data = JSON.parse(readFileSync(path, 'utf8')); }
  catch (e) { return { path, exists: true, data: null, errors: [`red-evidence.json: parse error (${e.message})`] }; }
  return { path, exists: true, data, errors: validateRedEvidence(data) };
}

// isResolved: contrato literal da rule/validate-spec — "não estiver 'observed' nem
// 'waived'" bloqueia verified. 'not-possible' e 'pending' NÃO contam como resolvidos
// (not-possible é estado transitório; o caminho normativo para Red inviável é
// /forge:red waive, que grava status:'waived').
export function isResolved(data) {
  return !!data && (data.status === 'observed' || data.status === 'waived');
}
