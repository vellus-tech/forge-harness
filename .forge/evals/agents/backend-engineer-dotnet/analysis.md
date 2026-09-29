# Análise de benchmark — agente `backend-engineer-dotnet`

Iteração: `iteration-1` (3 evals × 1 run por configuração). Agregação determinística via `scripts.aggregate_benchmark` (sem falhas — rodou de primeira, inclusive na reexecução desta sessão, com números idênticos). Fontes: `benchmark.json`, `benchmark.md`, `review.html` (viewer estático), os seis `grading.json`/`transcript.md`/`entrega.md` de `workspace/iteration-1/eval-*/{with_skill,without_skill}/run-1/`, `agents/analyzer.md` (seção *Analyzing Benchmark Results*) e o próprio artefato `template/.forge/agents/engineering/backend-engineer-dotnet.md`.

## 1. Resultado (benchmark.json → run_summary)

| Configuração | pass_rate médio | min–max | tempo médio (s) |
|---|---|---|---|
| with_skill | 0.7433 (74.3%) | 0.60–0.83 | 483.0 |
| without_skill | 0.5567 (55.7%) | 0.40–0.67 | 337.0 |

Delta = +0.1867 (arredondado +0.19). `benchmark_ok = true` (script rodou sem erro, sem correções de estrutura necessárias). Veredito pelo corte do protocolo (delta ≥ 0.15 → agrega): **agrega**.

O agente com skill também gasta ~146s a mais em média — custo de tempo real, não só de qualidade; maior parte desse tempo veio do eval 2 (697s vs. 473s), onde o with_skill teve de contornar um `401 Unauthorized` de NuGet e dois erros de compilação adicionais (ver §3).

## 2. Asserções não discriminantes

- **Regra "sem git commit" (eval 3, ambas as configs, expectativa 1):** passa 100% nas duas configurações — ambos os runs respeitaram a regra absoluta §22/26 do agente (nunca commitar em modo standalone). Não diferencia valor do artefato, mas confirma que essa regra absoluta é seguida de forma robusta independente do skill.
- **Teste de reentrega/idempotência do consumer (eval 2, expectativa 4):** falha 100% nas duas configurações. Nenhum dos dois runs escreveu um teste que entrega o mesmo `eventoId` duas vezes para verificar dedup — é uma lacuna de capacidade (ou de instrução), não algo que o skill hoje cobre.
- **Baseline `.NET` ausente / `TreatWarningsAsErrors` (eval 1, expectativa 4):** passa com skill, falha sem skill — mas o crédito é parcial mesmo com skill: o with_skill relata a lacuna corretamente (grading `passed: true`), enquanto o without_skill nem menciona o `dotnet-baseline.sh`. Ver §3 para o mecanismo.

## 3. Onde o artefato ajudou (evidência do transcript/grading)

1. **Contrato AsyncAPI atualizado (eval 2, expectativa 5).** Com skill, `contracts/asyncapi/cashback.yaml` ganhou o canal `bilhetagem.viagens` (0.3.0→0.4.0); sem skill, o arquivo ficou intocado (`git diff --quiet -- contracts` confirma). O artefato tem uma seção inteira (§9, "Contratos são fonte da verdade... atualize `contracts/asyncapi/` quando houver mudança de evento consumido") que o baseline sem skill simplesmente não seguiu — mesmo tendo lido a mesma documentação de integração. Efeito direto e mensurável do artefato.

2. **Formato de saída obrigatório (eval 1, expectativa 5 — os seis cabeçalhos `##`).** Com skill, `entrega.md` usa exatamente os seis cabeçalhos do §25 (`Resumo do que foi alterado`, `Arquivos alterados`, `Testes executados`, `Testes recomendados`, `Riscos conhecidos`, `Pendências`). Sem skill, o mesmo agente produziu um relatório de qualidade equivalente, mas com títulos livres ("## O que foi feito", "## Decisões e trade-offs" etc.) que não batem contrato nenhum — grading marca `passed: false` só por isso. O artefato transforma um output de qualidade subjetiva em um contrato verificável por grep.

3. **Baseline de build reportado com precisão (eval 1, expectativa 4).** Com skill, o transcript mostra o agente rodando `bash .forge/scripts/dotnet-baseline.sh --check` (instrução explícita do §8) e citando o resultado (`Directory.Build.props`, `.editorconfig`, `Directory.Packages.props` ausentes) em `entrega.md`. Sem skill, o mesmo script existe no repositório mas nunca é mencionado — o agente sem a definição não sabe que esse comando existe nem que é obrigatório rodá-lo antes de codificar.

4. **Decisão de não aplicar retry cego em operação não idempotente (eval 2, expectativas 2–3).** As duas configurações acertaram aqui — mas vale notar que o baseline sem skill chegou à mesma decisão correta lendo só `docs/integracoes/carteira-api.md` (a doc do domínio, não o artefato). Isto é evidência de que essa asserção específica testa conhecimento geral de engenharia (idempotência em pagamentos), não o valor incremental do artefato — reforça a nota do §2 sobre asserções pouco discriminantes, mesmo passando em ambas.

## 4. Onde o artefato atrapalhou ou não ajudou

1. **CHANGELOG sob `[Unreleased]` (eval 1, expectativa 6) — único caso em que with_skill perde e without_skill ganha.** Com skill, a entrada foi parar sob `[0.2.0]` em vez de `[Unreleased]` (mesmo o `entrega.md` dizendo textualmente "CHANGELOG.md — entrada `0.2.0`", grading cita a linha). Sem skill, a entrada foi corretamente para `[Unreleased]`. O artefato (§19) só diz "atualize `CHANGELOG.md`... quando aplicável", sem instruir *onde* dentro do arquivo a entrada deve entrar (seção `[Unreleased]` vs. criar uma versão nova) — ambiguidade que, neste run, levou o with_skill a inventar uma versão nova em vez de seguir a convenção Keep-a-Changelog padrão.

2. **Contradição interna §3 vs. §23 sobre parar antes de codificar (eval 3, expectativas 2 e 4 — falha nas duas configurações).** §3 diz, taxativo: *"Se houver divergência entre `tasks.md`, briefing, documentação e código existente, pare e sinalize a inconsistência antes de criar código novo."* §23 diz *"Não faça perguntas desnecessárias quando for possível avançar com segurança usando o contexto existente"* e lista como gatilho de parada apenas "a mudança exigir decisão arquitetural **ainda não tomada**" — que não é o caso aqui, porque `design.md` (DD-002/DD-003/DD-004) já resolve a divergência entre TASK-05 e o design. O resultado, nas duas configurações, foi o agente **implementar integralmente** a TASK-05 seguindo o design (em vez do texto literal da task) e só documentar a divergência em `entrega.md` — o que é uma leitura defensável de §23 ("a decisão arquitetural já foi tomada, está em design.md"), mas viola a letra de §3 ("pare... antes de criar código novo"). O artefato não reconcilia os dois parágrafos, e nenhuma das duas configurações "parou": isto não é um efeito do skill (falha em ambas), é uma ambiguidade do texto do artefato que merece correção (ver §5).

3. **Custo de tempo sem ganho proporcional no eval 2.** O with_skill gastou 697s contra 473s do without_skill no mesmo eval, boa parte perdida contornando um `401` de NuGet de infraestrutura da máquina de execução (não do artefato) e dois erros de compilação (`Host`, `ExchangeType`) que também apareceram no without_skill. Não é uma instrução do artefato que causou o atraso, mas indica que o artefato não orienta um passo de sanity-check de restore/build *antes* de escrever a lógica de negócio, o que poderia ter isolado esses erros de ambiente mais cedo em vez de no meio da implementação.

## 5. Trechos ignorados, ambíguos, contraditórios ou que desperdiçam tempo

- **Contradição §3 × §23** (detalhada acima): reescrever para deixar explícito que "pare antes de criar código novo" (§3) e "avance com segurança quando possível" (§23) coexistem assim — task diverge de design.md/requirements.md **e** o design já resolve → implemente conforme o design, mas **não prossiga sem antes emitir um sinal de bloqueio explícito e aguardar confirmação quando a mudança afeta schema de banco ou contrato público** (que é exatamente o caso do eval 3: `ALTER TABLE`/coluna monetária). Hoje o artefato deixa essa fronteira para o julgamento do modelo, e o modelo, nas duas condições, escolheu implementar.
- **§19 (CHANGELOG) sem instrução de "onde" inserir a entrada.** Ambiguidade real, comprovada pelo próprio par de runs do eval 1 divergindo exatamente nesse ponto. Vale uma frase objetiva: "nova entrada sempre sob `[Unreleased]`; só mova para uma versão numerada em fluxo de release explícito."
- **§10 (mensageria) e §18 (testes) nunca mencionam teste de reentrega/dedup explicitamente.** A seção de mensageria diz "garanta idempotência no consumo" e "crie testes para consumers e producers", mas não instrui, como caso de teste nomeado, "publique a mesma mensagem duas vezes e verifique que o efeito colateral (chamada externa, side effect) ocorre uma única vez ou é idempotente." A ausência desse caso de teste nomeado é a única expectativa que falhou nas duas configurações no eval 2 — sinal de que é uma lacuna do artefato, não falha aleatória do agente.
- **§8 (`dotnet-baseline.sh`)** é seguido à risca com skill e ignorado sem skill nas três evals — não é ambíguo, é só um comando que o baseline sem definição não tem como conhecer (não está em nenhuma doc do repositório-alvo, só no artefato). Não é um problema do artefato, é o próprio ponto de comparação do benchmark.
- **Nenhum trecho do artefato apareceu como desperdício de tempo per se** — a diferença de tempo do eval 2 (§4.3) veio de ambiente (NuGet, erros de compilação replicados em ambas configs), não de instrução do artefato.

## 6. Melhorias concretas priorizadas

1. **Alta prioridade — reconciliar §3 e §23 (contradição confirmada em 2/2 runs do eval 3).** Adicionar ao final de §3 (ou como novo parágrafo em §23) algo como: *"Divergência entre `tasks.md` e `design.md`/`requirements.md` não é, por si só, motivo para parar de implementar quando o `design.md` já resolve a ambiguidade — implemente conforme o design e registre a divergência em `entrega.md`. É motivo para parar e aguardar decisão humana antes de qualquer commit ou entrega quando a divergência envolver schema de banco, contrato público ou dado monetário — nesses casos, declare explicitamente 'implementação pronta, aguardando decisão X ou Y' em vez de marcar a TASK como concluída."* Isso fecha a lacuna que hoje reprova as expectativas 2 e 4 do eval 3 nas duas configurações.

2. **Média prioridade — instrução objetiva de posição da entrada de CHANGELOG (§19).** Acrescentar: *"Toda entrada nova de `CHANGELOG.md` entra sob `[Unreleased]`; nunca crie uma seção de versão numerada nova a menos que a tarefa seja explicitamente um release."* Baixo custo de texto, e o próprio benchmark mostrou o with_skill errando exatamente nisso.

3. **Média prioridade — caso de teste nomeado para dedup de consumer (§10 e/ou §18).** Acrescentar em §10: *"Ao consumir eventos com garantia at-least-once, inclua no mínimo um teste que entrega a mesma mensagem (mesmo id de correlação/evento) duas vezes e verifica que o efeito colateral externo (chamada HTTP, escrita) não duplica — ou que a chave de idempotência enviada é sempre a mesma."* Isso teria potencialmente convertido a única expectativa que falha 100% nas duas configurações do eval 2 em um ganho exclusivo do skill.

4. **Baixa prioridade — script a embutir para restore/build sanity-check.** Sugerir, antes do passo de implementação (entre §3 e §8), um `dotnet restore`/`dotnet build` "a seco" contra o estado atual do serviço, para isolar erros de ambiente (pacotes faltando, `using` ausente) do trabalho de lógica de negócio — reduziria o tempo do eval 2 sem mudar o resultado de qualidade. Não é urgente: o custo é de tempo (~146s médios a mais com skill), não de corretude.

5. **Não fazer:** não mexer no §8 (`dotnet-baseline.sh`) nem no §9 (contratos) — ambos já funcionam como pretendido e são a maior fonte de vantagem mensurável do artefato (eval 1 expectativa 4, eval 1 expectativa 5, eval 2 expectativa 5). Fusão ou remoção de qualquer um desses trechos reduziria o delta medido.

## 7. Qualidade dos casos (eval_quality)

Os três casos são de boa qualidade — específicos, com asserções verificáveis por comando/grep citado na própria evidência do grading (não são julgamentos vagos), e cobrem eixos distintos do artefato (TDD + contrato OpenAPI; idempotência de mensageria + contrato AsyncAPI; divergência task/design + disciplina de commit). Dois pontos a observar:

- O eval 3 (`task-split-diverge-design-pede-commit`) tem uma expectativa (2: "nenhum arquivo alterado, só `entrega.md`") que pressupõe uma leitura estrita de §3 ("pare antes de criar código novo") que o próprio artefato contradiz em outro lugar (§23) — não é um caso mal escrito, mas expõe que o caso está testando um comportamento que o artefato hoje não garante de forma inequívoca. Recomendo manter o caso (é exatamente o tipo de cenário-limite que vale testar) e tratar a falha como sinal para corrigir o artefato (§6.1), não como caso a descartar.
- Nenhum dos três casos testa custo/tempo como critério de aprovação — o que é correto (tempo não deveria reprovar um caso), mas o `benchmark.json` expõe a diferença de 483s vs. 337s sem que nenhuma nota qualitativa do processo capture *por que* (o `analyzer.md` propositalmente não pede causas, só padrões — este documento adiciona a causa observada em §4.3 como contexto extra, não como substituto das notas do analyzer).

`eval_quality`: boa — sem casos ruins o suficiente para tornar o benchmark inconclusivo.
