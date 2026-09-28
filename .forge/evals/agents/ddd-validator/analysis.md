# Análise de benchmark — agente `ddd-validator`

Artefato avaliado: `template/.forge/agents/architecture/ddd-validator.md` (agent, 1091 linhas).
Fonte determinística: `workspace/iteration-1/benchmark.json` (gerado por `scripts.aggregate_benchmark`, sem falhas — `benchmark_ok=true`).

## 1. Resultado do benchmark

| Configuração | Pass rate (média) | stddev | min–max | tempo médio |
|---|---|---|---|---|
| Com skill | 71,11% | 0,1836 | 50,0%–83,33% | 533,7s |
| Sem skill | 31,22% | 0,2492 | 16,67%–60,0% | 366,0s |

Delta = 0,7111 − 0,3122 = **+0,3989 (+0,40)**. Acima do limiar de 0,15 → **veredito: agrega**.

O ganho é consistente nas três evals tomadas individualmente (com > sem em todas: 0,833>0,167; 0,5>0,17; 0,8>0,6), o que reduz o risco de o delta agregado ser artefato de uma única eval. A amostra é pequena (n=1 execução por configuração por eval, 3 evals) — a magnitude exata do delta tem incerteza real (stddev de até 0,25), mas a direção do efeito é robusta.

## 2. Asserções não discriminantes

- **`insumos-de-produto-e-adrs-intocados`** (eval 1) e **`adrs-e-insumos-intocados`** (eval 3): passam em ambas as configurações — testam apenas "não tocar em PRD/FRD/NFRD/TRD/ADR", uma restrição que nenhuma das duas configurações violou. Não diferenciam a skill.
- **`nao-gera-entregas-do-architect`** (eval 2): passa em ambas — nenhuma configuração fabricou README/`index.html` que não existiam. Comportamento correto "de fábrica" do modelo base, não algo que o artefato precisou ensinar.
- **`pci-permanece-generic`** e **`ownership-da-carteira-nao-movido`** (eval 3): passam em ambas — o modelo base já resiste a aplicar as duas mudanças pedidas mesmo sem o artefato (o texto do usuário já é claramente uma tentativa de bypass; não exigiu a doutrina do agente para ser recusado).
- **`tabela-de-completude-documental-presente`** (eval 1): falha em **ambas** as configurações. Não diferencia com/sem skill, mas é o sinal mais acionável do lote — ver §3.

## 3. Onde o artefato ajudou

- **Resistência a pressão do usuário para afrouxar o parecer.** Na eval 2, o prompt pede explicitamente "se faltar pouca coisa, me diz que dá para aprovar com ressalvas". Com skill, o agente aplicou a regra literal do §13.5 do artefato (`ddd-validator.md:649-659`) e reprovou mesmo assim — o transcript documenta a decisão como "tomada em cima do protocolo escrito, não de julgamento discricionário" (`eval-completude-apos-remover-bc-integracao-legada/with_skill/run-1/outputs/transcript.md`, seção 6). Sem skill, o agente cedeu: `outputs/validacao-ddd.md:27` emite "Aprovar com ressalva parcial" e classifica a ausência de `index.html` como "gap não bloqueante" — o oposto do que o próprio contrato do agente exige. Essa é a evidência mais forte de valor da skill neste lote.
- **Formato estrutural (IDs, seções, caminho canônico).** Sem skill, os três runs escrevem relatórios fora do caminho `docs/product/ddd/ddd-validation-report.md` (`outputs/validacao-ddd.md`, `outputs/relatorio-validacao.md`) e sem os formatos de ID exigidos (`FIND-DDD-NNN`, `ADJ-DDD-NNN`, `VAL-DDD-NN`) — o conteúdo analítico costuma estar correto (ex.: eval 1 sem skill identifica corretamente a escrita cruzada e cita FR-03/ADR-0002), mas falha nas asserções por não seguir o formato exigido. Com skill, IDs e caminho canônico aparecem consistentemente nas três evals.
- **Conflito arquitetural citando ADR-0003 (eval 3).** Só o with_skill materializa a seção "Conflitos Arquiteturais" com uma linha citando ADR-0003 × segmentação/context-map/TRD; sem skill, a mesma divergência é mencionada em prosa dentro de um memorando, sem a seção dedicada.

## 4. Onde o artefato atrapalhou ou não fez diferença

- **Falha repetida na "Tabela de Completude Documental" (§13.4), mesmo com skill.** Nas evals 1 e 2 (with_skill), o transcript mostra que o agente **executa corretamente** a análise dos Passos 13.1–13.3 (cruza matriz × filesystem, conta subdomínios e BCs, identifica faltantes) e aplica corretamente a regra de impacto do §13.5 — mas em nenhum dos dois runs materializa a tabela markdown literal exigida em `ddd-validator.md:627-646` (`| Tipo | Esperado | Encontrado | Faltando | Excedente |` e a tabela de "Estrutura e Visualização"). O agente registra o mesmo conteúdo em prosa ou em achados individuais (`FIND-DDD-COMPL-*`), que cobrem a substância mas não o formato tabular que os testes de aceitação (e provavelmente consumidores downstream) esperam. Isso acontece em 2 de 2 execuções com skill — não é ruído, é um padrão.
- **Diluição por redundância estrutural.** O artefato define a mesma "tabela de completude" em três lugares: como instrução processual no Passo 13 (linhas 577-660), dentro do template completo de relatório na seção 8 "Relatório Obrigatório" (linhas 723-931, que não inclui essa tabela em lugar nenhum do template principal — ela só aparece isolada no Passo 13, não integrada ao esqueleto de 18 seções) e novamente resumida na seção 11 "Resumo Final Obrigatório" (linhas 1033-1077). O template de 18 seções (linhas 723-931) — que é o que o agente efetivamente copia para começar o relatório — **não contém um placeholder para a Tabela de Completude Documental nem para a tabela de Estrutura e Visualização**; elas só existem soltas no meio do Passo 13. Isso explica por que o agente, ao seguir o esqueleto de seções, "esquece" de colar a tabela prescrita em outro lugar do documento.
- **Asserção da eval 3 sobre justificativa em `Pontos a Validar` é ambígua/estrita demais.** A tabela `VAL-DDD-NN` do artefato (`ddd-validator.md:884-888` e `:1066-1069`) só tem colunas Código/Ponto/Impacto/Recomendação — não há coluna "Justificativa". A asserção da eval exige que a linha VAL cite explicitamente "compliance sozinho não torna Core", mas o artefato deixa essa justificativa em outra seção (Validação de Subdomínios, §3, ou Conflitos). O próprio grading reconhece isso ("caso limítrofe, na dúvida passed=false") — é tanto uma lacuna do artefato (a tabela VAL-DDD não tem onde registrar a justificativa) quanto um design questionável da asserção.
- **Sem custo de tempo excessivo, mas sem ganho de eficiência.** Skill custa +167,7s em média (533,7s vs 366,0s) — aceitável dado o ganho de pass rate, mas o artefato de 1091 linhas é longo para o que pede; grande parte do volume é template repetido (seções 8 e 11 se sobrepõem quase integralmente).

## 5. Melhorias concretas priorizadas

1. **Alta prioridade — inserir a Tabela de Completude Documental e a tabela de Estrutura e Visualização diretamente no esqueleto de 18 seções (seção 8, dentro de "## 13. Achados de Validação" ou como subseção nova antes dela), em vez de deixá-las isoladas no Passo 13.** Isso resolve a falha reincidente (2/2) descrita no §4 sem exigir mudança de conteúdo, só de posição/duplicação do template no lugar certo.
2. **Alta prioridade — adicionar um passo de autoverificação explícito ao final do Passo 13**, do tipo: "Antes de prosseguir, confirme que as duas tabelas acima (`Tabela de Completude Documental`, `Estrutura e Visualização`) foram coladas literalmente no relatório final — um resumo em prosa das mesmas conclusões não satisfaz este passo." Um checklist de fechamento barato, sem custo de token relevante, ataca diretamente o padrão observado.
3. **Média prioridade — considerar substituir o cruzamento matriz × filesystem (§13.1–13.3) por um script determinístico** (bash/python embutido, chamado via `Bash`/ferramenta equivalente) que já emite a tabela pronta a partir de `ddd-segmentation.md` + `find docs/product/ddd`. É uma tarefa mecânica de diff estrutural, boa candidata a determinismo — reduziria tanto o risco de omissão do formato quanto o tempo gasto.
4. **Média prioridade — adicionar coluna "Justificativa" (ou remeter a `§3`/`§15`) na tabela `Pontos a Validar` (§16)**, para que a justificativa de recusa (ex.: "compliance sozinho não torna Core") tenha onde ser registrada na própria linha VAL-DDD-NN, alinhando o artefato ao que os avaliadores (e provavelmente humanos lendo o relatório) esperam encontrar ali.
5. **Baixa prioridade — mesclar as seções 8 ("Relatório Obrigatório") e 11 ("Resumo Final Obrigatório")**, que duplicam quase integralmente a mesma informação (parecer final, arquivos criados, ajustes, achados, pontos a validar, próximos passos). Reduz ~45 linhas de redundância e a chance do modelo tratar o resumo final como o "relatório de verdade" e relaxar o rigor de formato do corpo principal.

## 6. Qualidade das próprias evals (`eval_quality`)

Positivo:
- As três evals são adversariais de forma realista: pressão por atalho ("estou com pressa", eval 2), tentativa de bypass de regra de negócio disfarçada de pedido técnico ("passa a tabela `carteira`... já aplica direto", eval 3), e um caso de correção segura + achado crítico combinados (eval 1). Isso testa exatamente os pontos de decisão que o artefato tenta governar (§13.5, §3, regras de ownership).
- As asserções pedem evidência via `grep`/`git diff`/`test -e` sobre artefatos reais, não sobre a opinião do avaliador — boa rastreabilidade e baixo risco de avaliação subjetiva solta.

Fragilidades:
- Assertivas de "não fez nada indevido" (arquivos intocados, não fabricar entregas do `ddd-architect`) são necessárias para segurança, mas não discriminam a skill — eram esperadas passar em qualquer modelo razoável e infladam a impressão de cobertura sem adicionar sinal (§2).
- A eval 3 tem uma asserção (`duas-mudancas-viram-pontos-a-validar`) com exigência de formato mais rígida do que a própria tabela do artefato suporta (ver §4) — o próprio texto do grading assinala a ambiguidade. Vale revisar a asserção ou o artefato, não os dois lados quietamente divergentes.
- Amostra de 1 execução por configuração por eval limita a confiança na magnitude do delta (embora não na direção). Rodar 2–3 execuções por configuração produziria um `stddev` mais informativo antes de decisões de prioridade fina entre as melhorias acima.

## 7. Resumo para o retorno estruturado

- `with_pass_rate` = 0,7111
- `without_pass_rate` = 0,3122
- `delta` = +0,3989
- `benchmark_ok` = true
- `verdict` = agrega (delta ≥ 0,15)
