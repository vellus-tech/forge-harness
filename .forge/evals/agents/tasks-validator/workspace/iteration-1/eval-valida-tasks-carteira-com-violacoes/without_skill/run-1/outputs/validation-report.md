# Validação de tasks.md — Módulo Carteira (CRT)

- tasks.md v1.0.0, base requirements.md v1.2.0 e design.md v0.4.0 (ambos aprovados), ADR-0001/0002/0003.
- Veredito: **NÃO executar a sprint com o tasks.md como está.** Há uma dependência circular que trava o sequenciamento da Onda 3 e uma instrução de commit que viola ADR-0003; além de duas lacunas de rastreabilidade que deixam requisitos sem TASK que os verifique.

## Bloqueadores (impedem abrir a sprint)

### 1. Dependência circular entre TASK-04 e TASK-05

TASK-04 declara "Depende de: TASK-05" e TASK-05 declara "Depende de: TASK-04" (tasks.md linhas ~106 e ~126). As duas tasks pertencem à Onda 3 e nenhuma pode começar antes da outra terminar — não há ordem de execução possível. Pelo próprio design (DD-002, tabela `recarga_processada` usada pelo handler de crédito), a direção correta é TASK-04 (Application, handler de crédito) depender de TASK-05 (Infrastructure, persistência), nunca o contrário. **Correção:** remover "Depende de: TASK-04" de TASK-05 (ou trocar para "Não aplicável" dentro da onda), mantendo apenas TASK-04 → TASK-05.

### 2. TASK-05 manda dar push direto em `main`

Critério de aceite de TASK-05: "commit `feat(carteira): persistencia` e push direto em `main` para liberar o time de app." Isso contraria ADR-0003 ("push direto em `main` ou `develop` é proibido — branch protection") e o próprio critério de fechamento da Onda 3 do tasks.md ("PR da onda aprovado e mergeado em `develop`"). **Correção:** trocar por "branch enviada; abrir PR para `develop`", igual às demais TASKs.

## Lacunas de rastreabilidade (corrigir antes de distribuir, senão ficam sem cobertura)

### 3. RNF 2 (mascaramento de PII em logs) sem TASK e fora da Matriz de Rastreabilidade

Requirements RNF 2 exige que CPF/e-mail nunca apareçam em claro em log, e o design.md já prevê o enricher de mascaramento ("Observabilidade e segurança", RNF 2). Nenhuma TASK do tasks.md implementa ou testa esse enricher, e RNF 2 não aparece na Matriz de Rastreabilidade. **Correção:** acrescentar uma TASK (ou subtask dentro de TASK-04/06, onde há logging de webhook e de consulta) que implemente e teste o mascaramento, e incluir a linha RNF 2 na matriz.

### 4. PBT-02 (idempotência do crédito) sem TASK e fora da Matriz de Rastreabilidade

Requirements PBT-02 exige que aplicar o mesmo `txid` N vezes credite o valor exatamente uma vez. TASK-04 testa apenas o caminho feliz do handler ("webhook confirmado credita o valor e grava outbox"), sem um teste de replay do mesmo `txid`, e PBT-02 não consta na Matriz de Rastreabilidade (só PBT-01 está listado). O mecanismo existe no design (DD-002, `recarga_processada` com `txid` UNIQUE), mas falta o teste que prove a propriedade. **Correção:** acrescentar subtask em TASK-04 (ex.: "4.x Red: reenviar o mesmo `txid` N vezes e verificar crédito único") e incluir PBT-02 na matriz.

## Verificado e conforme (sem achado)

- Dinheiro em centavos (ADR-0002): nenhuma menção a `decimal`/`float`/`double`; Saldo em `long` centavos (TASK-02, DD-001).
- Clean Architecture (ADR-0001): TASK-01 cobre os testes NetArchTest antes de qualquer TASK de Infrastructure.
- Branches e PR (ADR-0003) fora do caso de TASK-05: todas as demais branches seguem `<tipo>/carteira/<NN>-<slug>` e os critérios de aceite pedem branch enviada (implicando PR).
- Req 1, Req 2, Req 3, RNF 1, PBT-01, DD-001, DD-002: mapeados corretamente na Matriz de Rastreabilidade.
- Catálogo de erros CRT-002/CRT-003 coberto por TASK-03 e TASK-06 respectivamente.
- Coverage gates por camada (Domain 95%, Application 90%, Infrastructure 70%, Api 80%) presentes e coerentes com os critérios de aceite de cada TASK.

## Recomendação para o tasks-writer

Não abrir a sprint de segunda-feira com esta v1.0.0. Pedir ao tasks-writer uma v1.0.1 que: (a) quebre o ciclo TASK-04/TASK-05, (b) troque o push direto em `main` da TASK-05 por PR para `develop`, (c) adicione cobertura de RNF 2 e PBT-02 com as respectivas linhas na Matriz de Rastreabilidade. Os itens 1 e 2 são bloqueadores; 3 e 4 podem, na pior hipótese, virar tasks adicionais na própria Onda 3 sem atrasar o início da Onda 1/2.
