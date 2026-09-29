# Análise de impacto — change 2026-09-webhook-adquirente

**Scale:** 3 · **Escopo declarado:** `src/webhooks/` (assinatura HMAC do webhook da adquirente) · **Método:** leitura manual do código + `grep` recursivo (sem grafo de código construído, sem skill impact-scan — baseline `without_skill`).

## Arquivo-alvo

`src/webhooks/signature.ts` — expõe `verifySignature(body, sig)`, que calcula HMAC-SHA256 sobre `body` usando `process.env.ACQ_WEBHOOK_KEY` e compara com `sig` via `===`.

## Cadeia de dependência (quem importa quem)

Busquei ocorrências de `signature`, `verifySignature`, `acquirer`, `onAcquirerEvent` e `reconcile` em todo `src/`:

1. `src/webhooks/signature.ts` — exporta `verifySignature`.
2. `src/webhooks/acquirer.ts` — importa `verifySignature` de `./signature`; expõe `onAcquirerEvent(body, sig)`, que lança `Error('401')` se a assinatura falhar, senão faz `JSON.parse(body)`.
3. `src/settlement/reconcile.ts` — importa `onAcquirerEvent` de `../webhooks/acquirer`; expõe `reconcile(b, s)`, que retorna `onAcquirerEvent(b, s).amount`.
4. `src/api/routes/webhooks.ts` — importa `onAcquirerEvent` de `../../webhooks/acquirer`; expõe a rota `post(b, s)`, que chama `onAcquirerEvent(b, s)` diretamente.

Nenhum outro arquivo em `src/` referencia esses símbolos (grep sem resultados adicionais).

## Consumidores diretos e transitivos de `signature.ts`

| Nível | Arquivo | Símbolo | Efeito de uma mudança na assinatura HMAC |
|---|---|---|---|
| Direto | `src/webhooks/acquirer.ts` | `onAcquirerEvent` | Qualquer mudança de algoritmo, de chave (`ACQ_WEBHOOK_KEY`) ou de formato de comparação em `verifySignature` muda o comportamento de aceitar/rejeitar (`401`). |
| Transitivo (via acquirer) | `src/settlement/reconcile.ts` | `reconcile` | Se a verificação passar a rejeitar payloads antes aceitos (ou vice-versa), `reconcile` deixa de processar liquidação ou passa a processar payload não confiável. |
| Transitivo (via acquirer) | `src/api/routes/webhooks.ts` | rota `post` | É o endpoint HTTP público que recebe o webhook da adquirente; qualquer regressão na verificação de assinatura vira uma superfície de ataque (aceitação de payload forjado) ou uma quebra de disponibilidade (rejeição de webhooks legítimos, ex.: se a adquirente rotacionar o algoritmo/formato do HMAC).

## Riscos específicos do trecho tocado

- Comparação de assinatura feita com `===` (comparação de string comum), não em tempo constante — potencial timing attack ao validar HMAC; vale considerar `crypto.timingSafeEqual` na mudança.
- `ACQ_WEBHOOK_KEY` vem de variável de ambiente sem fallback seguro (`?? ''`): se a env var não estiver setada, `createHmac` roda com chave vazia e pode aceitar assinaturas triviais — checar se o change adiciona validação de presença da chave.
- `onAcquirerEvent` faz `JSON.parse(body)` sem try/catch após a verificação — payload malformado (mas assinado) derruba a rota; não é o foco do change, mas está na mesma função tocada indiretamente.
- Não há nenhum arquivo de teste no repositório (`find` por `*test*`/`*.spec.ts`/`*.test.ts` não retornou nada) — não existe rede de segurança automatizada para esta mudança; a validação terá que ser manual/exploratória.

## Superfícies fora de `src/` a considerar

- `package.json` não declara scripts de `test`/`build`/`typecheck` — não há gate de CI local conhecido para rodar antes do PR.
- `.forge/FORGE.md` deste workspace de eval tem os campos `runtime.test`/`runtime.typecheck` vazios — não há comando determinístico configurado para validar a mudança neste projeto.

## Recomendação para o PR de hoje

1. Anexar a lista acima (3 consumidores: `acquirer.ts` → `reconcile.ts` e `webhooks.ts` rota) como o raio de impacto do change scale 3.
2. Cobrir manualmente (não há testes automatizados): (a) assinatura válida → aceita; (b) assinatura inválida → 401; (c) `ACQ_WEBHOOK_KEY` ausente → não deve aceitar silenciosamente.
3. Como não há grafo de código construído neste workspace, esta análise foi feita 100% por leitura de arquivo + grep manual; para projetos maiores que este fixture de 4 arquivos, esse método não escala e o raio de impacto real pode ficar subestimado (imports dinâmicos, reexports, uso via DI/reflection não apareceriam num grep simples).
