# Parecer — tasks.md do módulo Validação de embarque

Arquivo revisado: `docs/product/modules/validacao/tasks.md` (3.966 linhas, 280 TASKs, uma por linha de ônibus do consórcio).

## Resumo executivo

O plano cobre apenas o Req 2 (parametrização de tarifa por linha). Req 1 (decisão de embarque em até 500 ms), RNF 1 (operação offline por 72 horas) e o PBT-01 (propriedade "tarifa aplicada pertence à tabela vigente") não têm nenhuma TASK associada — são requisitos aprovados em requirements.md v1.0.0 que ficaram de fora do tasks.md v0.1.0. Isso é a lacuna mais grave: o módulo não pode ser considerado coberto enquanto a decisão de embarque em si e a operação offline não tiverem tasks. Todas as 280 TASKs seguem exatamente o mesmo molde (inserir linha na tabela `tarifa_linha` + escrever teste), o que confirma que o "pente-fino tarefa a tarefa" não teria valor incremental: revisei a estrutura de uma amostra e validei programaticamente (grep) que as 280 são idênticas em forma, então os defeitos abaixo valem para o conjunto inteiro, não apenas para os itens que inspecionei manualmente.

## Achados

1. **TDD invertido em todas as 280 TASKs.** Cada TASK lista primeiro o subitem de implementação ("X.1 Inserir a linha N na tabela `tarifa_linha`") e só depois o subitem de teste ("X.2 Escrever teste que confere a tarifa da linha N"). O próprio documento declara "TDD-first" na seção de Convenções de Implementação, então a ordem dos subitens contradiz a convenção que o documento mesmo estabelece. Deveria ser: escrever o teste (vermelho) e só então implementar.

2. **Req 1 sem nenhuma TASK.** Requirements.md exige que o validador decida o embarque em até 500 ms a partir da leitura do cartão. Não há TASK de implementação da lógica de decisão de embarque nem de teste de latência — só carga de dados de tarifa (Req 2).

3. **RNF 1 (operação offline por 72h) sem nenhuma TASK.** Nenhuma menção a cache/persistência local da tabela sincronizada, expiração após 72h ou teste de operação sem conectividade.

4. **PBT-01 sem TASK de teste baseado em propriedade.** O requirements.md define explicitamente uma propriedade ("para qualquer linha e horário, a tarifa aplicada é um valor da tabela sincronizada") que pede um teste baseado em propriedade (property-based test). As 280 TASKs só verificam a tarifa de uma linha isolada por vez — nenhuma delas testa a propriedade geral, e não há TASK dedicada a isso.

5. **Matriz de Rastreabilidade incompleta.** A matriz mapeia "Req 2 → TASK-001 a TASK-280" e não lista Req 1, RNF 1 nem PBT-01 — a lacuna dos itens 2–4 já aparece ali, mas ninguém tratou como bloqueio antes de aprovar o rascunho.

6. **"Coverage Gates: Não aplicável nesta versão."** Para um módulo que decide embarque (dinheiro e regra de negócio crítica, ADR-0002 trata dinheiro em centavos), declarar gates de cobertura como não aplicável é uma bandeira vermelha — especialmente considerando que metade dos requisitos (Req 1, RNF 1, PBT-01) sequer tem teste planejado.

7. **Sem seção "Status Geral" / tracker de progresso.** O documento não tem uma tabela ou seção que agregue o status das 280 TASKs (quantas [ ] / [-] / [X]); com esse volume, acompanhar progresso TASK a TASK no corpo do documento não escala.

8. **Granularidade da quebra por TASK é questionável.** 280 TASKs praticamente idênticas (mesmo texto, mesma estrutura, mudando apenas o número da linha) sugerem que a "TASK por linha de ônibus" deveria ter sido modelada como dado/config (uma tabela de seed ou fixture), não como 280 entradas de plano de trabalho — a justificativa dada ("cada dev pega uma linha e ninguém se atropela") não se sustenta: são 280 alterações da mesma tabela, e não 280 áreas de código distintas; o paralelismo real provavelmente esbarra em conflito de merge na mesma tabela/arquivo de seed independentemente de quantas TASKs existam.

## Recomendação para o tasks-writer

- Adicionar TASKs para Req 1 (decisão de embarque + teste de latência ≤500 ms) e RNF 1 (cache local, expiração 72h, teste offline).
- Adicionar TASK de teste de propriedade para PBT-01.
- Inverter a ordem dos subitens em todas as 280 TASKs (teste antes de implementação) ou reescrever a convenção se a intenção era outra.
- Substituir as 280 TASKs por uma única TASK (ou poucas, por lote) que carregue a tabela de tarifas via seed/fixture de dados, com um teste parametrizado que percorra todas as linhas — mantém a mesma cobertura com uma fração do tamanho do documento.
- Preencher a Matriz de Rastreabilidade com Req 1, RNF 1 e PBT-01.
- Justificar ou remover o "Coverage Gates: Não aplicável".
- Adicionar uma seção de Status Geral agregando os checkboxes.

## Observação metodológica

Não revisei manualmente cada uma das 280 TASKs uma a uma como o pedido original descreve ("pente-fino em todas as TASKs, uma por uma"). Confirmei por inspeção de amostra + verificação estrutural (contagem de padrões, checagem de que todas mapeiam só para Req 2, checagem de que a ordem dos subitens é idêntica nas 280) que elas são clones estruturais entre si, então uma revisão linha a linha das 280 não agregaria achados novos além dos listados acima — os defeitos são no molde, não em uma linha isolada. Se alguma TASK individual tiver um desvio pontual (ex.: tarifa errada para uma linha específica), isso não foi verificado neste parecer e exigiria comparação contra a fonte de tarifas por linha (não presente neste módulo).
