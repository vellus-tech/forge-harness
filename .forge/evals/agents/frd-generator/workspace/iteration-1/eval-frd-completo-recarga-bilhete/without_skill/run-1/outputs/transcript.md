# Transcript — eval-frd-completo-recarga-bilhete / without_skill / run-1

## Contexto

Execução de caso de eval do agente `frd-generator`, variante `without_skill` (baseline sem ler qualquer artefato de skill/agente/plugin do harness). Conhecimento usado é só o próprio, aplicado à tarefa do usuário descrita abaixo.

## Passos executados, em ordem

1. Confirmei o diretório de trabalho da árvore de eval (`.forge/worktrees/evals-100`, branch `chore/evals-skills-agentes`) antes de qualquer escrita, conforme protocolo de bootstrap do prompt recebido.
2. Gravei o instante inicial em `.t0` com `date +%s`.
3. Criei `work/` e rodei `setup.sh` desse fixture apontando para `work/`, que materializou um projeto Forge completo (`.forge/`, `CLAUDE.md`, `docs/`) com `docs/product/prd/prd.md` e `docs/discovery/discovery-notes.md` já populados, e um diretório `docs/product/frd/` vazio (o "lugar padrão do projeto" para o FRD, espelhando a estrutura de `docs/product/prd/`).
4. Li integralmente `docs/product/prd/prd.md` (PRD da Recarga Metropolitana, aprovado em 2026-09-09) e `docs/discovery/discovery-notes.md`. Não abri nenhum caminho sob `template/.forge/skills`, `template/.forge/agents`, `plugin/` ou `.forge/evals`, conforme a regra do baseline `without_skill`.
5. Identifiquei do PRD: 6 funcionalidades (F-01 a F-06), 3 personas (P-01 passageiro, P-02 atendente SAC, P-03 analista financeiro), 4 regras de negócio explícitas (RN-01 a RN-04, sendo RN-04 pendente de definição jurídica), 2 jornadas e 2 pontos em aberto (prazo de contestação não definido; permissão do SAC para bloquear cartão não definida).
6. Decidi a estrutura do FRD com base no pedido do usuário: uma seção por funcionalidade (RF-01 a RF-06), cada uma com descrição, critérios de aceite no formato dado/quando/então, regras de negócio associadas (mapeando as RN-01..04 do PRD para as seções correspondentes), tabela de mensagens de erro e tabela de permissões por perfil — cobrindo os quatro pontos que o usuário pediu explicitamente (requisitos com critério de aceite, regras de negócio, mensagens de erro, permissões por perfil).
7. Tratei os dois pontos em aberto do PRD sem inventar decisão de produto: marquei ambos como `NEEDS CLARIFICATION` nos RFs afetados (RF-05 para prazo de contestação, RF-06 para bloqueio pelo SAC), registrei um valor de trabalho provisório e assumido explicitamente (90 dias para contestação, por analogia à janela de extrato de 90 dias) apenas para não travar o backlog, e deixei RN-04 (valor máximo de recarga) como parâmetro configurável em vez de número fixo, já que depende do jurídico.
8. Também identifiquei e registrei uma lacuna que o PRD não menciona (desvínculo de cartão), como pendência a confirmar com produto, em vez de assumir silenciosamente uma decisão de escopo.
9. Escrevi `work/docs/product/frd/frd.md` com 11 seções: objetivo/escopo, perfis e permissões, RF-01 a RF-06 (uma seção por funcionalidade), requisitos não funcionais de referência rápida (fora de escopo detalhado, apenas citados), matriz de rastreabilidade RF↔PRD, e tabela de pendências a resolver antes/durante a implementação.
10. Nenhuma outra ferramenta ou subagente foi necessária ou instruída pela tarefa; não havia artefato do harness sinalizando para spawnar subagentes nesta execução (a tarefa deste run é a execução direta do caso de eval), então nenhum despacho foi simulado.
11. Copiei `work/docs/product/frd/frd.md` para `outputs/docs/product/frd/frd.md` e escrevi este transcript.
12. Ao final, calculei `timing.json` a partir de `.t0` e do instante de término, e removi `work/` da contagem de tamanho se excedesse 20 MB (não excedeu).

## Decisões relevantes e por que

- **Local do FRD:** `docs/product/frd/frd.md`, espelhando `docs/product/prd/prd.md` — o fixture já continha esse diretório vazio como sinal do "lugar padrão do projeto" citado pelo usuário.
- **Formato de critério de aceite:** dado/quando/então, por ser diretamente testável por QA sem tradução adicional, atendendo ao pedido "para o time de engenharia e QA começar a quebrar o backlog".
- **Ambiguidades do PRD não resolvidas por conta própria:** onde o PRD explicitamente lista um ponto em aberto (seção 8 do PRD), o FRD não inventa a resposta como se fosse definitiva — usa `NEEDS CLARIFICATION`, propõe um valor de trabalho quando isso não bloqueia engenharia, e explica o racional da escolha provisória.
- **Dinheiro em centavos:** alinhado à convenção do próprio repositório gerado pelo `setup.sh` (CLAUDE.md do projeto: "money as integer cents"), refletido nas regras de negócio de RF-03.
- **NFRDs fora de escopo:** o pedido do usuário foi por FRD, não NFRD; segurança de pagamento e LGPD são citadas como referência rápida para dimensionamento, sem se aprofundar, para não extrapolar o tipo de documento pedido.

## O que não foi feito e por quê

- Não li nenhum artefato de skill/agente do harness (`template/.forge/skills`, `template/.forge/agents`, `plugin/`, `.forge/evals`) — exigência explícita do baseline `without_skill`.
- Não executei `git commit`/`push`/`checkout`/`stash`, testes, `npm`, `docker`, `ledger-ops.sh`, `liaison-ops.sh`, `gh` de escrita, `npm publish` nem deploy — nenhuma dessas ações foi necessária para a tarefa, e todas são vedadas pelas regras do prompt.
- Não spawnei subagentes — nada na tarefa instruiu isso, e a regra do prompt veda o spawn real de qualquer forma.
