# Análise do benchmark — agente `module-validator`

**Fonte:** `workspace/iteration-1/benchmark.json` (gerado por `scripts.aggregate_benchmark`, determinístico). Viewer estático em `workspace/iteration-1/review.html`.

## 1. Resultado

| Métrica | Com artefato | Sem artefato | Delta |
|---|---|---|---|
| Pass rate | 100% (± 0%) | 33,3% (± 30,6%) | **+0,67** |
| Tempo | 220,3s (± 89,7s) | 150,0s (± 53,7s) | +70,3s |
| Tokens | 0 (não medido) | 0 (não medido) | — |

3 evals × 1 run por configuração (sem repetição — `stddev` de pass_rate no "com artefato" é 0 porque só há uma amostra, não porque o comportamento é estável; ver §5, eval_quality).

**Veredito:** delta = +0,67 ≥ 0,15 → **agrega**.

## 2. Asserções não discriminantes

- Eval 2 (revalida com deployable compartilhado): 3 de 5 asserções passam em ambas as configurações — "Aprovado sem Crítica aberta", "ausência de contratos com severidade Baixa" e "Matriz Deployable trata backoffice-monolito como justificado por ADR-0002". O agente sem o artefato já chega a esses três resultados por julgamento geral de engenharia; não medem o valor específico do protocolo.
- Eval 3 (recusa sem data-model): 2 de 5 asserções passam em ambas — "data-model.md continua inexistente" e "git diff não altera READMEs de módulo". Nenhuma das duas configurações tenta inferir o data-model nem editar READMEs nesse caso; a asserção não diferencia.
- Eval 1 (valida catálogo) é o único 100% discriminante: as 6 asserções falham todas sem o artefato e passam todas com ele.

## 3. Onde o artefato ajudou

- **Eval 1** — sem o artefato, o agente identificou corretamente o conflito de ownership de `cartoes_transporte` e até aplicou as duas correções certas nos READMEs, mas não produziu `modules-validation-report.md`, não usou parecer formal (Reprovado/Aprovado), não usou IDs `MOD-*` nem marcação `[CORRIGIDO]` — falhou nas 6 asserções por não seguir o **formato de output do §8.1**, não por erro de julgamento técnico (transcript without_skill, passo 8: "Escrevi o parecer completo em `outputs/parecer.md`" — fora do caminho e do formato exigidos). Com o artefato, o mesmo raciocínio técnico saiu no formato certo e passou nas 6.
- **Eval 2** — sem o artefato, a versão do relatório subiu para `1.1.0` (MINOR) mesmo com o parecer mudando de Reprovado para Aprovado; a regra de **incremento MAJOR em mudança de parecer (§8.2)** só foi seguida com o artefato. Também sem o artefato, o agente emitiu veredito próprio sobre `tarifacao` ser Core ou Supporting ("tarifacao se encaixa melhor como Supporting... Recomendação: reclassificar"); com o artefato, o agente citou explicitamente o **anti-pattern do §9** ("Validar segmentação Core/Supporting/Generic — isso é do `ddd-validator`") e devolveu a decisão sem emitir parecer próprio.
- **Eval 3** — sem o artefato, o agente não aprovou "puro", mas escreveu um relatório (`VALIDATION-REPORT.md`, fora do caminho canônico) com "Aprovado condicionalmente", que a asserção 1 trata como equivalente a "Aprovado com Ressalvas" — falha. Com o artefato, a regra explícita do **§4** ("Se algum insumo obrigatório (1, 2, 3, 7, 8) estiver ausente, interrompa a validação") foi citada literalmente no transcript e seguida à risca: nenhum relatório foi escrito, nem alternativo.

## 4. Onde o artefato não ajudou / trechos problemáticos

- **§10 "Quando Escalar" duplica §3.2 "Quando NÃO corrigir"** — ambos usam o critério "decisão entre 2+ alternativas equivalentes/com trade-offs". Nenhum transcript cita §10 separadamente de §3.2; a distinção entre "registrar como Conflito Arquitetural" (§3.2) e "escalar ao usuário" (§10) nunca é usada como decisão independente nos 3 casos — na prática colapsam na mesma ação. É superfície redundante que aumenta o custo de manutenção sem mudar comportamento observado.
- **§12 "Critérios de qualidade"** é uma lista de checagem que reafirma regras já ditas em §4–§9 (14 insumos, 7 passos, matriz 100%, versionamento) sem acrescentar comportamento novo nos transcripts — nenhuma citação direta a §12 nos 6 runs. Candidato a remoção ou fusão com §7 (parecer final), já que funciona como resumo e não como regra operante.
- **Tempo:** +70,3s (47% a mais) é o custo de ler os 14 insumos e executar os 7 passos por completo mesmo quando vários não geram achado (ex.: glossário, ADRs sem achado nos 3 casos). Aceitável dado o ganho de pass rate, mas é o trade-off mais visível do artefato — nenhuma leitura condicional/priorizada dos insumos de baixo risco.
- Nenhum trecho do artefato foi contraditório nos 3 casos observados; a política de correção (§3), severidades (§6) e output (§8) formam uma cadeia consistente e foi citada nominalmente pelos runs com skill em todos os 3 casos.

## 5. Qualidade dos próprios casos (eval_quality)

- **Eval 1** é o caso mais forte: alta discriminância (0% → 100%), cobre formato de output, severidade, correção direta vs. registro, e completude de matriz numa única passada.
- **Eval 2 e eval 3** têm asserções não discriminantes (§2) que inflam o "total" de asserções passadas em ambas as configurações sem testar o artefato — reduzem a sensibilidade do benchmark a regressões futuras nessas duas evals. Recomenda-se, numa próxima rodada de calibração, substituir ou remover essas asserções por outras que isolem melhor o comportamento específico do protocolo (ex.: para o eval 2, focar só nas duas que já discriminam — versionamento MAJOR e não-veredito sobre segmentação — e no eval 3, dropar as duas sobre "arquivo/diff não alterado" que nenhuma configuração testada chega a violar).
- Com `runs_per_configuration: 1`, o desvio-padrão de 0% no "com artefato" não é evidência de estabilidade — é ausência de repetição. O benchmark é determinístico na agregação, mas a amostra é pequena demais para afirmar 100% de confiabilidade do artefato; hoje ele apenas afirma que, nas 3 execuções observadas, o artefato bateu a baseline.

## 6. Melhorias concretas priorizadas

1. **(Eval design, prioridade alta)** Reduzir/trocar as 3 asserções não discriminantes do eval 2 e as 2 do eval 3 por variantes que dependam de regra específica do artefato (ex.: um cenário onde a resposta "genérica" plausivelmente aprovaria com MINOR em vez de MAJOR, ou emitiria veredito de segmentação por padrão) — hoje elas medem "o agente não fez nada errado", não "o artefato preveniu um erro".
2. **(Artefato, prioridade média)** Fundir §10 "Quando Escalar" dentro de §3.2 "Quando NÃO corrigir e apenas registrar" — mesmo critério, duas seções; a fusão reduz a chance de as duas divergirem em uma edição futura sem mudar o comportamento hoje observado.
3. **(Artefato, prioridade baixa)** Fundir ou remover §12 "Critérios de qualidade" — é um checklist redundante com §4/§7/§8, sem citação direta em nenhum dos 6 transcripts.
4. **(Artefato, prioridade baixa)** Se o custo de tempo (+70s) for relevante em uso real, considerar permitir leitura resumida (grep-first) dos insumos 9–12 (PRD, FRD/NFRD, glossário, ADRs) quando não houver achado candidato que os referencie, em vez de leitura completa obrigatória dos 14 na ordem fixa — risco: pode esconder achados de rastreabilidade RF/RNF; só vale a pena se o tempo se tornar gargalo real medido em produção, não nesta amostra de 3 casos.
5. **(Repetição de amostra, prioridade média)** Rodar `runs_per_configuration: 3` (como o cabeçalho do benchmark.md já anuncia, mas os dados reais têm 1) para que o `stddev` do "com artefato" seja uma medida real de estabilidade, não um artefato de amostra única.
