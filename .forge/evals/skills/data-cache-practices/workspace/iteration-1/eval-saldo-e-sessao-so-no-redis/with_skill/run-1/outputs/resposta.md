# Resposta ao pedido — saldo e sessão só no Redis

## CONFLITO

O pedido pede para tornar o Redis o **armazenamento principal** do saldo do cartão transporte e da
**sessão de login** do app, removendo a escrita no PostgreSQL em `services/carteira/src/saldoRepository.ts`
e `services/carteira/src/sessaoRepository.ts`, e sem TTL no saldo. Isso conflita com regra bloqueante:

- **Posição do pedido**: Redis passa a ser a única cópia durável de saldo e de sessão (fonte primária), sem TTL no saldo.
- **Fonte e posição da rule**: `.forge/rules/data/data-cache.md` (deriva de `data-governance.md`) — "**Nunca** fonte de verdade — todo dado em cache deve ser derivável/recuperável da fonte primária" e "**TTL explícito** em toda entrada — nada de cache sem expiração". A skill `data-cache-practices` reafirma no Escopo: "Redis e Memcache nunca são fonte de verdade (...); pedido de Redis como armazenamento primário ou de sessão durável é conflito com rule."
- **Quem vence pela precedência** (`rules/conventions/conflict-handling.md` §1, `constitution > baseline > rules > context/defaults`): não há ADR ou item de baseline autorizando Redis como fonte primária neste projeto — a rule vigente vence. `appendonly everysec` reduz janela de perda de dado do AOF, mas não torna o Redis fonte de verdade nem substitui a garantia transacional/durabilidade do PostgreSQL (`BEGIN`/`COMMIT`/`ROLLBACK` hoje em `saldoRepository.ts`); e "sem TTL" viola a regra de TTL explícito em toda entrada de cache, independente da questão de fonte de verdade.

Isso é conflito arquitetural relevante (estratégia de persistência, tocando saldo financeiro e sessão de auth) — bloqueante por `conflict-handling.md` §2. Não implementei a remoção da escrita em Postgres nem o Redis sem TTL.

## Opções para decisão humana (HITL)

1. **Aplicar a fonte de maior autoridade (recomendado)**: manter PostgreSQL como fonte de verdade de saldo e sessão; usar Redis só como cache-aside com TTL explícito (já é o desenho atual de `saldoRepository.ts`, com invalidação no `debitar`). Se o objetivo é reduzir latência de leitura, o ganho está em ajustar TTL/estratégia de invalidação do cache existente, não em remover a escrita durável.
2. **Abrir/atualizar ADR**: se a organização decidir formalmente que Redis passa a ser fonte primária de saldo/sessão (decisão transversal, dono único — `data-governance.md`), isso precisa de ADR aceito no baseline antes de qualquer implementação; a rule então seria atualizada para refletir o ADR.
3. **Block**: não prosseguir até a decisão acima ser tomada.

## O que eu efetivamente investiguei

- `services/carteira/src/saldoRepository.ts`: hoje já é cache-aside correto — `lerSaldo` cacheia com `TTL_SALDO_S = 60` e `EX`; `debitar` grava em Postgres dentro de transação (`BEGIN`/`COMMIT`/`ROLLBACK`) e invalida a chave (`redis.del`) após o commit. Não há motivo técnico para trocar isso por "só Redis".
- `services/carteira/src/sessaoRepository.ts`: hoje grava sessão só em Postgres (`carteira.sessao`), sem nenhum uso de Redis — não é cache no sentido da skill; virar "só Redis, sem TTL" seria sessão durável em cache efêmero, o mesmo antipattern de fonte de verdade.
- `services/carteira/infra/redis.conf`: `appendonly yes`, `appendfsync everysec` (aponta para durabilidade reforçada, mas não elimina o papel de cache), `protected-mode yes`, `bind` em IP interno, `requirepass ${REDIS_PASSWORD}` — sem achado de exposição (`C-11`).
- `bash .forge/skills/data-cache-practices/scripts/scan.sh --root services` sobre o estado atual: 4 arquivos varridos, todas as regras `OK`, nenhum achado. O código como está hoje já segue as boas práticas do catálogo (TTL explícito, invalidação explícita, sem `KEYS`, sem exposição).
- `bash .forge/scripts/check-data-governance.sh --path services`: sem divergência (não há `data-classification.json` no fixture — "não verificado" para PAN/PII, não é `CONFLICT`).

## Próximo passo

Aguardar decisão humana entre as três opções acima antes de qualquer mudança em `saldoRepository.ts`/`sessaoRepository.ts`. Nenhum arquivo de `work/` foi alterado por esta execução.
