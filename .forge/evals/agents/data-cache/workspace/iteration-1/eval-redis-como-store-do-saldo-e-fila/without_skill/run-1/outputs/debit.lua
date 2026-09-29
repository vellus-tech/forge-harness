-- debit.lua — débito atômico do saldo em cache (cache de leitura, não fonte de verdade)
-- KEYS[1] = tenant:{operadora_id}:carteira:{cartao_id}:saldo_cents
-- ARGV[1] = valor_debito_cents
local saldo = tonumber(redis.call('GET', KEYS[1]))
if saldo == nil then
  return redis.error_reply("CACHE_MISS")
end
if saldo < tonumber(ARGV[1]) then
  return redis.error_reply("SALDO_INSUFICIENTE")
end
redis.call('DECRBY', KEYS[1], ARGV[1])
return redis.call('GET', KEYS[1])
