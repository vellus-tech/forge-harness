# Análise do benchmark — skill `frontend-ui-review`

Fonte: `workspace/iteration-1/benchmark.json` (agregação determinística via `aggregate_benchmark`), `workspace/iteration-1/*/outputs/transcript.md`, `evals.json`, e `template/.forge/skills/frontend-ui-review/SKILL.md` + `scripts/scan-phantom-tokens.py`.

## 1. Resultado

| | with_skill | without_skill |
|---|---|---|
| pass_rate (média) | 1.00 | 0.2433 |
| min / max | 1.00 / 1.00 | 0.00 / 0.40 |
| tempo médio | 242.0s | 208.0s |

Delta = 1.00 − 0.2433 = **+0.76**. `benchmark_ok = true` (aggregate_benchmark rodou na primeira tentativa, sem erro). Veredito: **agrega** (delta ≥ 0.15, por larga margem). Custo de tempo: +34s em média (+16%) para passar de 24% para 100% de acerto — ROI muito favorável. Tokens não foram medidos (`tokens: 0` em ambas as configurações; métrica não instrumentada neste executor, não é um dado real de custo zero).

## 2. Asserções não discriminantes

Das 16 asserções (6+5+5), 4 passaram em ambas as configurações e por isso discriminam pouco o valor da skill isoladamente:
- eval 1: `token-fantasma-fora-do-diff-detectado` e `veredito-bloqueado` passaram sem a skill também (o executor sem skill já tende a bloquear PR com token fantasma óbvio e a citar arquivos fora do diff quando os vê).
- eval 2: `surface-2-causa-do-dark` e `guid-bu-e-achado-de-backend` passaram sem a skill também (achados "óbvios" de leitura de código, que um agente competente encontra mesmo sem checklist).

Isso não invalida o resultado — as outras 12 asserções (formato de gates A1-A5, tratamento de fallback como máscara, separação de `--progress` runtime vs bug, escalonamento de primitivo faltante ao dono do DS, cobertura de superfície inteira, auditoria da qualidade dos testes) só passaram com a skill — mas mostra que parte do ganho vem de disciplina/formato, não só de detecção de bug.

## 3. Onde o artefato ajudou (evidência de transcript)

- **Ordem gates→semântica evitou aprovação falsa (eval 3).** Sem a skill, o executor aprovou a tela e recomendou fechar o ticket UI-231 mesmo sem conseguir confirmar tokens definidos (`without_skill/run-1/outputs/ui-review.md:7` "Aprovado... pode fechar a UI-231"), tratando a ausência de fonte de tokens como "ressalva não bloqueante". Com a skill, o mandato explícito do A0 ("sem a lista de tokens definidos... você não julga nada") levou o mesmo tipo de agente a bloquear e pedir o pré-requisito (`with_skill/.../ui-review.md:16`). Este é o efeito mais forte da skill: transforma ausência de evidência em bloqueio, não em aprovação por omissão.
- **Gate A5 (cobertura da superfície inteira) mudou o escopo da revisão (eval 1).** Sem a skill, o relatório restringiu a análise aos 2 arquivos do diff e declarou explicitamente que achados em `partners` "não bloqueiam este merge" (`without_skill/.../ui-review.md:25`). Com a skill, o transcript mostra passo 7: `git checkout feat/faturas-ds -- .` seguido de leitura de arquivos fora do diff (`PartnersTable.css`) exatamente por causa do mandato do A5, resultando em A5=FAIL e um segundo token fantasma capturado.
- **C1 (primitivo faltante ≠ improviso) e C2 (dado cru = achado de backend) mudaram o encaminhamento das recomendações (eval 2).** Sem a skill, o `<select>` improvisado foi tratado como "inconsistência local de PartnersPage" sem mencionar o dono do design system; com a skill, o transcript liga explicitamente partners+users como evidência de "N telas já pediram" e encaminha ao dono do DS, replicando literalmente o vocabulário do SKILL.md (§ C1).
- **Fase D (qualidade dos testes) foi aplicada de forma consistente com a skill, ausente sem ela** (eval 3): o transcript with_skill cita textualmente o precedente dos "2174 testes verdes" do SKILL.md ao classificar os testes de `SettingsPage.test.tsx` como estruturais, não comportamentais.

## 4. Onde o artefato atrapalhou ou gerou trabalho extra (evidência de transcript)

- **A4 (scan de controles nativos) tem um filtro morto.** O comando de exemplo em `SKILL.md:90` é `grep -v 'design-system'` para excluir componentes do próprio DS já encapsulados. Nas fixtures (e provavelmente na maioria dos projetos reais), a pasta do DS se chama `ds`, `components/ds` ou `ui`, nunca literalmente `design-system` — o filtro nunca casa. O transcript de `eval-pr-faturas-migracao-ds/with_skill` (passo 11) confirma o sintoma: o grep aponta `FileUpload.tsx` como controle nativo suspeito mesmo já sendo o componente do DS que encapsula corretamente o `<input type="file">`, obrigando o agente a ler o arquivo manualmente para descartar o falso positivo. Funcionou porque o agente compensou com julgamento, mas é exatamente o tipo de gate que a skill promete ser "determinístico e de custo zero" — aqui ele delega a triagem de volta para leitura manual.
- **Exit code do A1 fora do que o comentário do script documenta, na borda "fonte ausente".** `scan-phantom-tokens.py` retorna exit 1 quando há fantasmas (documentado no cabeçalho e em `SKILL.md:54`), mas retorna exit 2 tanto para uso incorreto (`argv` insuficiente) quanto para "arquivo de tokens não encontrado" — um caso de negócio real (A0 falhou), não um erro de uso. O SKILL.md não menciona esse exit 2 nem instrui o que fazer quando ele ocorre; o agente do transcript (`eval-aprovar-padronizacao-sem-tokens/with_skill`, passo 6) teve que abrir o `.py` e ler o código-fonte para descobrir esse comportamento antes de decidir como registrar A1. Isso é retrabalho evitável: bastava a skill dizer explicitamente "exit 2 = A0 não estabelecido, trate como bloqueio, não como token limpo".
- **Fase B (verificação de tema light/dark) não é executável em nenhum dos 3 fixtures** (sem dev server/Storybook no ambiente de eval) e a skill não prevê esse caso — os três transcripts com skill tiveram que decidir, cada um por conta própria, como registrar essa fase como "não executada" sem transformar a omissão em aprovação tácita. Funcionou nos três casos, mas por sorte de os agentes já internalizarem o princípio central da skill (ausência de evidência ≠ aprovação); a skill não instrui explicitamente o que escrever no relatório quando a Fase B é inexequível no ambiente disponível.

## 5. Trechos do artefato ignorados, ambíguos ou contraditórios

- **Ambíguo:** "Ordem de execução: gates determinísticos primeiro... revisão semântica depois" não diz o que fazer quando um gate não pode nem rodar (A0 ausente / sem app renderizável para Fase B) — os 3 transcripts tiveram que inventar uma convenção própria ("N/A", "não avaliável", "pendência INFO") porque o formato de saída (`SKILL.md:150-164`) só prevê `OK|FAIL` para a maioria dos gates e `OK|WARN` para A3/A4, sem um terceiro estado formal para "não executável".
- **Não usado nos 3 evals, mas presente na skill:** C3 (borda/espaçamento/raio/sombra) e C4 (estados e acessibilidade) quase não aparecem nos relatórios gerados — nenhuma fixture tinha sinal forte nessas dimensões, então nenhuma asserção de eval cobre C3/C4 e não há evidência de que a skill os opera bem na prática. Ponto cego do benchmark, não da skill.
- **Nenhuma contradição interna encontrada** no texto do SKILL.md.

## 6. Melhorias concretas, priorizadas

1. **(alto impacto, correção de gate)** Trocar o filtro `grep -v 'design-system'` do A4 (`SKILL.md:90`) por um padrão configurável do caminho real do DS do projeto (ex.: variável `$DS_DIR` documentada, ou instrução para o agente descobrir o caminho do catálogo do DS no A0 e reusar aqui), evitando falso positivo sistemático em qualquer projeto cuja pasta de componentes não se chame literalmente `design-system`.
2. **(alto impacto, documentação do script)** Documentar explicitamente em `SKILL.md` § A1 o exit code 2 de `scan-phantom-tokens.py` ("A0 não estabelecido — trate como bloqueio, não deixe A1 como OK/vazio") em vez de deixar o agente inferir isso lendo o `.py`. Uma linha evita reabrir o script em toda execução.
3. **(médio impacto, formato)** Formalizar um terceiro estado de gate "N/A / não executável" no formato de saída (`SKILL.md:150-164`), com a regra explícita "N/A nunca conta como OK para efeito de veredito" — fecha a ambiguidade que hoje cada execução resolve de um jeito diferente (embora hoje resolvam bem).
4. **(médio impacto, script)** Embutir um segundo script para A2/A3/A4 (hoje só A1 tem `.py`; A2-A4 são comandos `rg` soltos no corpo do SKILL.md), incluindo a correção do item 1. Isso tornaria os 4 primeiros gates igualmente reproduzíveis em CI, como o próprio § D da skill recomenda ("os gates A1/A2 devem virar CI gate").
5. **(baixo impacto)** Adicionar uma frase de fallback para a Fase B quando não há ambiente renderizável ("registre como pendência, nunca como conformidade implícita"), cobrindo o caso que os 3 transcripts já resolveram corretamente por bom senso, mas sem instrução — reduz variância entre execuções futuras/outros modelos.

## 7. Qualidade dos próprios casos de eval (`eval_quality`)

Os 3 casos são de boa qualidade: cada um isola um mecanismo diferente da skill (A0/ausência de fonte da verdade; A5/cobertura fora do diff; C1+C2/encaminhamento correto de achados) e as asserções são checáveis por evidência textual objetiva (grep/linha), não por opinião — o que o próprio `benchmark.json` confirma, já que o agregador conseguiu computar pass/fail com evidência de arquivo:linha em 100% das 33 verificações. Pontos fracos: (a) 4 das 16 asserções não discriminam a skill (ver §2) — ainda úteis como guarda-corpo de regressão, mas infladoras da taxa de acerto "sem skill"; (b) nenhum caso cobre C3 (bordas/espaçamento) nem C4 (estados/acessibilidade), então o benchmark não valida essas duas seções do artefato; (c) `runs_per_configuration: 3` no metadata do benchmark não bate com a realidade (`workspace/iteration-1` só tem `run-1` em cada configuração) — o campo do agregador parece um valor default não substituído pelo gerador de workspace, não um dado real desta rodada.

`eval_quality`: **boa, com lacunas de cobertura em C3/C4 e um metadado de run-count inconsistente com os dados reais.**
