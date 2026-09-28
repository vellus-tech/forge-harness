# Revisão — feat/tarifa-integracao (tarifador)

## Escopo

Diff `main..feat/tarifa-integracao`, 5 arquivos novos em `src/tarifas/`: domínio (`tarifa.ts`, `tarifa-repository.ts`), aplicação (`cotar-integracao.ts` + teste) e infra (`pg-tarifa-repository.ts`). Implementa a cotação de integração ônibus+metrô com 25% de desconto no segundo embarque dentro de 120 minutos.

## Veredito

**Mudanças solicitadas.** O bloqueador é o teste da regra de negócio principal não verificar nada de fato (achado F1). O restante são observações de baixa severidade e notas informativas.

## Achados

1. **[Alto] Teste sem asserção real (`cotar-integracao.test.ts:15`).** O único teste do fluxo de desconto chama `cotarIntegracao` e depois faz `expect(true).toBe(true)`, descartando o retorno. O teste passa independentemente do valor calculado — não protege a regra de 25%/120 min contra regressão. Corrigir capturando o retorno e comparando com o valor esperado (870 centavos no caso do teste atual), e adicionar um caso fora da janela de 120 min.

2. **[Médio] Caminho de erro sem cobertura.** `cotarIntegracao` lança quando alguma tarifa vigente não é encontrada, mas não há teste para esse caminho.

3. **[Baixo] `as keyof typeof tarifas` no fake de teste** mascara erro de tipo se `linhaId` não existir no fixture. Aceitável isoladamente; vale um helper tipado se o padrão se repetir.

4. **[Baixo] Limite de 120 min é inclusive (`<=`) sem comentário nem teste de fronteira** em `tarifa.ts`. Decisão de negócio implícita — documentar e testar o caso exato de 120 min.

5. **[Info] `forge-quality/max-lines` (error, max 300) não é violado por este diff.** O arquivo mais longo adicionado tem 16 linhas. Não consegui rodar `npm run lint` de verdade neste ambiente (sem `node_modules`, sem rede para instalar `typescript-eslint`); a conclusão é por contagem manual de linhas. Recomendo confirmar com `npm ci && npm run lint` no CI antes do merge.

6. **[Info] `no-direct-data-access` não bloqueia `pg` em `src/tarifas/infra`** porque a regra só guarda `layers: ['src/http']`. Consistente com a arquitetura hexagonal do módulo; fora de escopo ampliar a regra neste PR.

7. **[Info, fora de escopo] `src/legacy/relatorio-helper.ts`** usa `console.log` e `any`, o que violaria `no-direct-console` se fosse tocado — mas não faz parte deste diff.

## O que não foi executado

- `npm run lint`: tentado via `npx eslint .`, falhou com `ERR_MODULE_NOT_FOUND` (typescript-eslint) por falta de `node_modules` e de acesso de rede no ambiente do eval.
- `npm test`: não executado — fora do escopo autorizado desta corrida de eval (baseline `without_skill`).

Essas duas lacunas devem ser fechadas pelo CI do repositório antes do merge; esta revisão é estática, por leitura de código e do `eslint.config.mjs`.
