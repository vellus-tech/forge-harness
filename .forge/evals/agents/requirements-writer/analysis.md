# Análise de benchmark — agent `requirements-writer`

Issue #176 (forge-harness). Protocolo skill-creator, agregação determinística via `scripts.aggregate_benchmark` (sem estatística no olho).

## Resultado (benchmark.json → run_summary)

| Configuração | pass_rate (média) | stddev | min | max | tempo médio (s) |
|---|---|---|---|---|---|
| with_skill (agente carregado) | 1.00 | 0.00 | 1.00 | 1.00 | 150.3 |
| without_skill (agente ausente) | 0.457 | 0.319 | 0.17 | 0.80 | 163.3 |

**Delta = 1.00 − 0.457 = +0.54** → **veredito: agrega** (delta ≥ 0.15, folgado).

`benchmark_ok = true` — o script rodou de primeira sem correção de estrutura. Viewer estático (`generate_review.py`) também gerou `review.html` sem erro.

3 evals × 1 run cada configuração (`runs_per_configuration: 3`, mas cada eval só tem `run-1` — ausência de repetição por eval é uma limitação da suíte, ver "qualidade dos casos" abaixo).

## Onde o artefato ajudou (evidência de transcript)

- **Eval `cria-tarifacao-a-partir-do-prd` (maior diferencial: 1.00 vs 0.17).** Sem o agente, o executor produz um documento plausível mas com estrutura própria (`## 1. Objetivo` … `## 12. Perguntas em aberto`, `FR-01`, critérios Dado/Quando/Então) que não bate com nenhuma das 6 asserções de forma — sem tabela "Histórico de Versões", sem `### Req N`, sem seção de PBT. Com o agente, a "Estrutura Obrigatória" (linhas 52-94 do artefato) e o "Padrão de cada Requisito Funcional" (115-135) são seguidos ao pé da letra — inclusive o Status "Rascunho para revisão" em vez de "Aprovado", que é exatamente a armadilha que o prompt monta ("pode deixar pronto para o time pegar"). O transcript with_skill cita textualmente a regra "Não marque como Aprovado para desenvolvimento sem solicitação explícita" (linha 440 do artefato) como motivo da escolha.
- **Eval `recusa-regressao-rascunho-double-e-kiro` (1.00 vs 0.40).** A seção "Anti-Patterns que Você Bloqueia" (462-478) funciona como checklist direto: o transcript with_skill mapeia cada um dos três pedidos do usuário a um anti-pattern nomeado (money-as-cents, documento aprovado não regride, `.kiro/specs` proibido) e recusa os três, sem editar o arquivo. Sem o agente, o executor tenta ser "útil" e concede um meio-termo em cada um dos três pontos — inclusive criando a cópia em `.kiro/` (violação direta) e regredindo o Status para "Rascunho" (a asserção 5 falha explicitamente por isso). O ponto notável é que a regra de versionamento (253-272) *também* está disponível ao executor sem-skill via `AGENTS.md`/`CLAUDE.md` do próprio projeto-fixture (o transcript without_skill lê `.forge/rules/domain/money-as-cents.md` e `conventions/document-versioning.md` por conta própria) — ou seja, boa parte do ganho aqui vem menos da regra de conteúdo (que já vaza pelo projeto) e mais da postura de **recusa explícita e nomeada dos três pedidos** que só o artefato prescreve com essa força ("Você nunca deve... Anti-Patterns que Você Bloqueia").
- **Eval `adiciona-req-offline-em-doc-aprovado` (1.00 vs 0.80).** Diferença pequena: sem o agente, o executor acerta cabeçalho, histórico de versões, Req 5-7 e lista canônica, mas esquece de sincronizar o `README.md` do módulo — exatamente o passo 7 do "Workflow de Escrita" (442-459, "Sincronizar README.md do módulo"), que é um passo de checklist e não de conhecimento de domínio. Isso sugere que o valor do artefato aqui é in-context checklist compliance, não know-how que o modelo não teria.

## Onde o artefato pode ter atrapalhado ou tem folga não coberta

- Nenhuma asserção teve `with_skill` pior que `without_skill` — não há indício de "atrapalha" nos três casos rodados.
- **Feedback do próprio benchmark (`eval_feedback.suggestions`) aponta duas asserções não-discriminantes** que o benchmark de fato saturou nos dois lados:
  - Em `adiciona-req-offline`: a asserção do código `DENIED_OFFLINE_LIMIT` passa em ambos com "descrição mínima", sem checar se o comportamento fica amarrado a um critério de aceite verificável.
  - Em `recusa-regressao`: a asserção de versionamento "byte a byte igual OU versão maior com linha no histórico" passa mesmo quando o `without_skill` regride o Status para Rascunho e edita o conteúdo a pedido — a asserção mede só o *shape* do bump, não se o bump foi legítimo. Da mesma forma, a asserção sobre `double`/`float` passa no `without_skill` mesmo o documento tendo cedido ao pedido de expor `double` na borda (6 menções), porque a redação da asserção permite menção "restrita à camada de apresentação/integração" — o que tecnicamente ambos cumprem, mascarando que o `without_skill` *aceitou negociar* o pedido em vez de recusar.
- **Efeito colateral não coberto por asserção**: o próprio `eval_feedback` do caso `adiciona-req-offline` registra que o `with_skill` "mexeu no glossário e em PBTs, apesar do pedido para não mexer no resto" — nenhuma asserção do eval verifica escopo de edição além dos pontos citados, então esse desperdício de tempo/risco de regressão silenciosa passa batido nas duas configurações.
- **Tempo de execução não favorece o artefato**: `with_skill` tem tempo médio 150s vs 163s sem skill — a diferença é pequena e o delta é negativo (artefato mais rápido), então não há custo de latência a reportar; mas o N é baixo (3 runs) para tirar conclusão de tempo.

## Trechos do artefato ignorados, ambíguos, contraditórios ou que desperdiçam tempo

1. **"Regra de Tamanho e Decomposição" (220-249) nunca é exercitada** pelos 3 evals — nenhum documento de fixture se aproxima de 2.000 linhas. É uma seção morta neste benchmark; não é possível avaliar se o agente decompõe corretamente quando deveria. Risco: pode estar mal calibrada e ninguém percebeu.
2. **Ambiguidade sutil na seção "4. Lista canônica"**: o artefato diz "adaptada ao módulo" com exemplos (papéis, tipos de evento, etc.) mas não diz o que fazer quando o módulo tem *duas* candidatas a lista canônica plausíveis (ex.: no caso `tarifacao`, "Perfis Tarifários" vs. um catálogo de "regras de negócio RN-0x") — o `eval_feedback` já sinaliza problema análogo ("Nenhuma verifica também seções extras alteradas"), sugerindo que o agente tem liberdade demais aqui e isso não é auditado.
3. **A seção "Padrão de cada PBT" lista 6 categorias de Tipo (183-209) mas nenhuma asserção testada confere se o `Tipo:` escolhido é *coerente* com a propriedade descrita** — só confere que existe um `Tipo:` da lista. Isso é uma abertura para o agente rotular qualquer PBT com o tipo mais conveniente sem penalidade.
4. **Contradição potencial entre "Não encerre com resumo genérico" (502) e "Saída Esperada" pedir 10 itens de checklist (484-501)**: nos 3 transcripts with_skill, a resposta final é estruturada como uma lista dos 10 itens — que é, na prática, um resumo (ainda que específico). Não é um problema grave, mas a instrução "não resuma" e "entregue estes 10 itens" empurram para o mesmo formato de saída em toda execução, o que é redundante com a estrutura do próprio documento já entregue.
5. **Passo "5. Multi-persona review interna" (419-429) é declarado como revisão "mental"** — os transcripts o relatam como uma lista de bullets pós-hoc, não como evidência de mudança real de conteúdo por causa da revisão. É plausível que essa seção produza principalmente uma narrativa de justificativa e pouca mudança de comportamento; nenhuma asserção testa se a revisão efetivamente pega algo que não seria pego sem ela.

## Qualidade dos próprios casos de eval (eval_quality)

- **Cobertura dos 3 casos é boa e bem desenhada como armadilhas comportamentais** (deixar "pronto para dev" sem aprovação explícita; pedido de regressão de status + tipo errado + path errado simultâneos; edição cirúrgica em doc aprovado sem tocar no resto) — não são testes triviais de formatação.
- **Fragilidade principal: 1 run por configuração por eval.** O `run_summary.without_skill.stddev = 0.319` (pass_rate variando de 0.17 a 0.80) já é alto com apenas 3 pontos — não dá para saber se essa variância é do eval ou do executor sem-skill ser genuinamente inconsistente; sem repetição (`run-2`, `run-3`) o "veredito agrega" está correto na direção mas a magnitude exata do delta tem baixa confiança estatística.
- **Duas asserções não discriminam** (identificadas acima, já sinalizadas pelo próprio `eval_feedback` embutido no grading) — reduzem o poder de teste de 16 para ~14 asserções efetivas across os 3 evals.
- **Falta um caso que force decomposição de documento grande** (a "Regra de Tamanho" nunca é exercitada) e falta um caso que teste a seção de RNF isoladamente (os RNFs aparecem sempre como coadjuvante dos RFs, nunca como foco do eval).
- Os `eval_metadata.json` são específicos e verificáveis por grep/diff determinístico (nomes de arquivo, linhas exatas, valores numéricos) — boa prática, reduz avaliação subjetiva do grader.

## Melhorias concretas priorizadas

1. **[Alta] Reescrever a asserção de versionamento do eval `recusa-regressao-rascunho-double-e-kiro`** para exigir explicitamente que o Status não regrida *e* que nenhuma mudança de conteúdo negociada com o pedido proibido seja aceita — hoje ela passa com um "bump legítimo" que na prática validou uma regressão de status. Separar em duas asserções: (a) Status nunca vira Rascunho; (b) se houver bump, a razão registrada no Histórico não pode ser "atendimento ao pedido do time do app" — reforço da recusa, não de acomodação.
2. **[Alta] Adicionar ao artefato uma linha explícita no "Padrão de cada Requisito Funcional" ou no workflow**: "Ao recusar um pedido, produza um artefato de resposta explícita (`resposta-agente.md` ou equivalente na saída) nomeando a regra violada por item — não silencie a recusa apenas via ausência de edição." Isso já é o comportamento observado no with_skill, mas não está escrito como requisito formal — está sendo emergente da leitura de "Anti-Patterns". Torná-lo explícito reduz variância entre execuções.
3. **[Média] Adicionar limite de escopo de edição ao workflow**: uma frase do tipo "Ao editar um documento existente por um pedido pontual, não toque em seções não mencionadas (glossário, PBTs) salvo se a mudança pedida exigir consistência direta" — resolveria o achado do `eval_feedback` sobre o with_skill mexer no glossário/PBTs em `adiciona-req-offline` sem que o pedido tivesse mandado.
4. **[Média] Adicionar 1-2 evals novos**: um caso que force a "Regra de Tamanho e Decomposição" (documento de fixture próximo de 2.000 linhas, pedindo adição) para validar se o agente de fato recomenda/decompõe; e um caso focado em RNF isolado (ex.: pedido de adicionar só um requisito não-funcional de observabilidade) para testar a seção 150-179 sem o RF "carregando" o teste.
5. **[Baixa] Rodar ao menos `run-2` e `run-3` por eval/configuração** antes de fechar o veredito definitivo desta issue — o delta de +0.54 é grande o suficiente para não mudar de categoria (agrega), mas o `stddev` de 0.32 no sem-skill merece mais amostra antes de virar número citável em relatório executivo.
6. **[Baixa] Podar ou testar a seção de Multi-persona review** — hoje é puramente narrativa nos transcripts; ou se adiciona uma asserção que force uma correção rastreável decorrente dela, ou se reduz a prescrição para não inflar o artefato com uma etapa que não muda output observável.

## Despacho de subagentes que seriam usados (não spawnados, conforme regra do run)

Nenhum subagente foi necessário para esta análise — leitura + 2 execuções de script + síntese cabiam em uma única sessão. Se fosse decompor: um agente por eval (3, modelo `sonnet`, prompt "leia grading.json + transcript.md de `<eval>` e escreva 3-5 bullets de achados") teria sido a divisão natural, mas o volume de dados (3 evals × 2 configs × ~1 grading.json pequeno + transcript ≤ 84 linhas) não justificou o overhead de coordenação.
