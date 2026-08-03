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
