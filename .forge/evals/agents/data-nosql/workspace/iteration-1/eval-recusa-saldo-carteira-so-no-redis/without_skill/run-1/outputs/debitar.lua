-- debitar.lua
-- KEYS[1] = saldo:{conta_id}
-- KEYS[2] = audit:{conta_id}   (stream de auditoria, mesmo slot via hash tag)
-- KEYS[3] = idemp:{conta_id}:{idempotency_key}
-- ARGV[1] = valor_centavos (positivo)
-- ARGV[2] = idempotency_key
-- ARGV[3] = ttl_idempotencia_segundos (ex.: 86400)

if redis.call('EXISTS', KEYS[3]) == 1 then
  -- retry do mesmo request: devolve o saldo atual sem debitar de novo
  local saldo_atual = tonumber(redis.call('GET', KEYS[1]) or '0')
  return {1, saldo_atual, 'idempotent_replay'}
end

local saldo = tonumber(redis.call('GET', KEYS[1]) or '0')
local valor = tonumber(ARGV[1])

if valor <= 0 then
  return {0, saldo, 'valor_invalido'}
end

if saldo < valor then
  return {0, saldo, 'saldo_insuficiente'}
end

local novo_saldo = redis.call('DECRBY', KEYS[1], valor)

redis.call('SETEX', KEYS[3], tonumber(ARGV[3]), '1')

redis.call('XADD', KEYS[2], '*',
  'op', 'debito',
  'valor_centavos', valor,
  'idempotency_key', ARGV[2],
  'saldo_resultante', novo_saldo)

return {1, novo_saldo, 'ok'}
