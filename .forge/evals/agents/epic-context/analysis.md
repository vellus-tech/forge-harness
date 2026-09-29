# Análise do benchmark — agente `epic-context`

Fonte determinística: `outputs/benchmark.json` (gerado por `scripts.aggregate_benchmark`, sem cálculo manual). Viewer estático em `outputs/review.html`. Despacho simulado de subagente (não executado, por regra da tarefa) em `outputs/dispatch.md`.

## 1. Resultado

`run_summary` do benchmark.json: with_skill pass_rate média 0.86 (± 0.13, min 0.75, max 1.0); without_skill pass_rate média 0.40 (± 0.53, min 0.0, max 1.0). Delta = 0.86 − 0.40 = **+0.46**. Tempo: with_skill 99.3s vs without_skill 100.3s (diferença desprezível, a favor de without_skill por 1s — a skill não pesa no tempo de execução). Tokens: ambos 0 (não instrumentado nesta execução — metadado zerado em `metadata`/`run_summary`, não é sinal real de custo).

Atenção estrutural: `metadata.runs_per_configuration` declara 3, mas só existe `run-1` em cada `eval-*/{with,without}_skill/`; os dois outros runs por configuração não foram materializados. O `benchmark_ok=true` (o script rodou e produziu números), mas o desvio-padrão do without_skill (±0.53) é artefato de n=1 por eval agregado sobre 3 evals heterogêneos, não de repetição real da mesma condição — tratar como indicativo, não como medida de variância estatisticamente sólida.

Veredito: delta = +0.46 ≥ 0.15 → **agrega**.

## 2. Asserções não discriminantes

- Eval 1, asserção 6 (formato de linha única "epic_context.md gerado — N decisões, M contratos, K invariantes.") falha em **ambas** as configurações (with e without), mas por um motivo que não é do agente: nem o run with_skill nem o without_skill desta fixture gravaram um artefato de resposta final ao chamador separado do transcript narrativo — o próprio grading admite "na dúvida, falha". Não diferencia a skill; diferencia a captura do harness (ver §5, eval_quality).
- Eval 1 e Eval 2, asserção "fora das remoções do setup, único arquivo novo é o epic_context.md do change" passa em ambas as configurações no Eval 2, mas falha em without_skill no Eval 1 só porque o nome do arquivo saiu errado (`epic-context.md` em vez de `epic_context.md`) — a asserção testa duas coisas ao mesmo tempo (ausência de arquivos extras + nome correto) e mistura sinais.
- Eval 3, asserções 1, 2 e 4 (arquivo não reescrito, manifest/stories intocados, resposta ≤3 linhas sem dump de seções) passam em **ambas** as configurações — não diferenciam a skill; o comportamento de idempotência ("não fazer nada quando já está pronto") é dedutível por bom senso, sem precisar do artefato.

## 3. Onde a skill ajudou

- **Disciplina de escopo de leitura** (Eval 1 e Eval 2): with_skill nunca menciona ADR-0021/ADR-0020/Kafka/Debezium/Redis/Redlock (Eval 1) nem ADR-0018/Firebase/FCM/`enviarPushFcm`/`LIMIAR_SALDO_PADRAO_CENTAVOS` (Eval 2), mesmo quando o prompt do usuário sugere explicitamente puxar esse contexto ("o projeto já tem ADR de push na baseline... se ajudar", Eval 2). O transcript do Eval 2 with_skill é explícito sobre isso: "o protocolo do agente epic-context restringe as seções ADRs e Contratos externos ao que está listado no manifest ou mencionado no design.md — nenhum dos dois cita ADR-0018 [...] Optei por não incorporar". Sem a skill, o mesmo prompt faz o agente ler `push.ts` e o ADR da baseline e despejar `LIMIAR_SALDO_PADRAO_CENTAVOS`, `enviarPushFcm` e a fila `notificacoes.push` direto no epic_context.md (Eval 2 without_skill, 3 de 5 asserções falham só por vazamento de contexto externo ao change).
- **Contrato de cabeçalhos/nome de arquivo estável**: with_skill produz `# Epic context — <id>` e os seis `##` exatos, na ordem, em todas as 3 fixtures. Sem a skill, o Eval 1 usa `epic-context.md` (hífen) com título `# Contexto épico —` e headings livres (`## Problema e objetivo`, `## ADRs relevantes`, etc.) — quebra qualquer consumidor automatizado (`/forge:shard`) que dependa do path/formato fixo. Isso é o valor mais concreto e reprodutível da skill: sem ela, a saída é semanticamente razoável mas estruturalmente incompatível com o pipeline.
- **Idempotência corretamente reconhecida** (Eval 3): with_skill lê o manifest, vê `epic_context_compiled: true`, e não reescreve — comportamento certo, mas empatado com without_skill (que chegou à mesma conclusão por bom senso).

## 4. Onde a skill atrapalhou

- **Eval 3, asserção 3 — regressão real causada pelo próprio artefato.** with_skill é a única configuração que falha esta asserção neste eval (without_skill passa). A causa é rastreável ao texto do agente: a seção "Missão" diz "idempotente: se `epic_context.md` já existir e `epic_context_compiled: true` no manifest, retorne OK sem reescrever", mas a seção "Saída ao chamador" só define **um** template fixo — `epic_context.md gerado — <N> decisões, <M> contratos, <K> invariantes.` — sem variante para o caminho idempotente. O transcript confirma a escolha deliberada: "Mensagem única, conforme o formato exigido pela especificação do agente: `epic_context.md gerado — 3 decisões...`" mesmo nada tendo sido gerado. O grading trata isso como contraditório e reprova ("a resposta é contraditória: diz 'gerado' sem ter gerado"). without_skill, sem esse template a seguir literalmente, escreveu uma frase natural ("já está compilado e atualizado [...] nenhuma recompilação foi necessária") e passou. **A skill, aqui, piora o resultado por seguir seu próprio texto ao pé da letra.**
- **Ambiguidade sobre quem atualiza `dev_loop.epic_context_compiled`.** Em nenhuma das 3 fixtures with_skill o agente grava o campo no manifest — ele interpreta "escreve apenas epic_context.md" como proibição de tocar no manifest, mesmo quando o manifest não tem o bloco `dev_loop` (Eval 1) ou quando `epic_context_compiled` seria o próprio sinal de que a compilação ocorreu (Eval 1: "o manifest do fixture também não define o campo [...] então nenhuma edição de gate foi feita"). Se ninguém mais no pipeline seta essa flag, a checagem de idempotência do próprio agente ("se [...] compiled: true [...] retorne OK") nunca vai disparar em changes novos, e o agente recompila do zero a cada chamada — o oposto do que a seção de idempotência promete. O artefato nunca resolve explicitamente essa propriedade (quem escreve a flag, e quando).

## 5. Trechos ignorados, ambíguos, contraditórios ou que desperdiçam tempo

- **Contraditório** — "## Saída ao chamador" vs. "idempotente [...] retorne OK sem reescrever" (seção Missão): o template de saída não tem ramificação para o caso idempotente. Já causou a única falha real atribuível à skill (§4). É o achado de maior prioridade.
- **Ambíguo** — escopo de escrita "escreve apenas epic_context.md nesse change" (frontmatter `description`) colide com a necessidade implícita de marcar `epic_context_compiled: true` para a idempotência funcionar depois. O artefato nunca diz explicitamente se essa flag é responsabilidade do agente, do `/forge:shard` que o invoca, ou de nenhum dos dois.
- **Ignorado, sem custo aparente** — a etapa "4. Limites" ("Não faça inferências além do que está nos artefatos") funcionou bem nos 3 casos e não parece ter sido violada em nenhum run with_skill; não é um problema, é confirmação de que essa instrução está clara e sendo seguida.
- **Nenhum trecho de código embutido no artefato** (script, exemplo de shell) — o "Protocolo" é só prosa + um template Markdown; não há nada a "embutir como script" aqui, dado que a tarefa do agente é leitura+síntese, não uma operação mecânica automatizável por script determinístico.

## 6. Melhorias concretas priorizadas

1. **(Alta — corrige a única regressão observada)** Adicionar ao artefato uma segunda saída explícita para o caminho idempotente, distinta do template "gerado —", por exemplo: `epic_context.md já compilado — nenhuma reescrita.` A seção "Saída ao chamador" deveria mostrar os dois templates lado a lado (gerado vs. já compilado) para eliminar a ambiguidade que fez with_skill reproduzir literalmente um texto contraditório.
2. **(Alta — fecha o buraco de idempotência)** Explicitar no protocolo quem escreve `dev_loop.epic_context_compiled: true` após a primeira compilação bem-sucedida: se for o próprio `epic-context`, adicionar um passo 3.5 "atualize `spec-manifest.yaml` com `dev_loop.epic_context_compiled: true`" (ajustando a descrição de escopo de escrita, hoje restrita a "escreve apenas epic_context.md"); se for responsabilidade do `/forge:shard` chamador, dizer isso explicitamente no artefato para não deixar a suposição a cargo do modelo.
3. **(Média)** Separar a asserção composta "único arquivo novo é o X" + "nome correto é X" em duas verificações independentes nos casos de eval — hoje uma falha de nomenclatura (Eval 1, without_skill) contamina a leitura de "nenhum arquivo espúrio foi criado", quando são dois fatos distintos.
4. **(Média, qualidade de eval)** Padronizar a captura da resposta final ao chamador em todas as fixtures (hoje: `agent-response.md` só existe no Eval 3 with_skill; nos demais casos a resposta final não é gravada como artefato isolado, o que torna a asserção de formato de saída (Eval 1, item 6) estruturalmente não verificável em 2 de 3 evals — não é falha do agente, é lacuna do harness de captura).
5. **(Baixa)** Reforçar com um exemplo negativo curto no artefato (1-2 linhas) do tipo de vazamento que a skill já evita bem na prática — "não copie constantes/identificadores de código-fonte para o resumo, mesmo que o usuário sugira consultá-los" — para blindar contra prompts que pressionam explicitamente por esse vazamento (como no Eval 2), embora a skill já tenha resistido a essa pressão nos 3 runs observados; é reforço, não correção de defeito.

## 7. Qualidade dos casos de eval (`eval_quality`)

Os 3 casos cobrem cenários bons e complementares (change scale 3 com distratores cross-change, change scale 1 sem design.md com pressão do usuário para vazar contexto externo, e idempotência pós-crash) — desenho de cenário é forte e as asserções em geral são objetivas e verificáveis por grep/git diff, com evidência textual anexada por expectativa. Dois problemas reduzem a nota:

- A asserção de formato da resposta final (Eval 1, item 6) depende de um artefato (resposta ao chamador) que a fixture não instrui a capturar de forma padronizada — ela é, na prática, quase sempre "falha por falta de evidência" independente do comportamento real do agente, o que a torna uma medição fraca (ver §2 e §6.4).
- `metadata.runs_per_configuration: 3` no benchmark.json não corresponde aos dados reais (apenas 1 run por configuração por eval existe em `workspace/iteration-1`) — não invalida o resultado agregado (aggregate_benchmark rodou sobre o que existia), mas infla a aparência de robustez estatística do desvio-padrão relatado.

Qualidade geral: **boa, com uma lacuna de instrumentação (captura da resposta final) e uma imprecisão de metadado (contagem de runs) a corrigir antes da próxima rodada.**

## 8. Veredito

- with_skill pass_rate: 0.86
- without_skill pass_rate: 0.40
- delta: +0.46
- benchmark_ok: true
- **veredito: agrega** (delta ≥ 0.15), com uma correção pontual recomendada no próprio artefato (item 1 de §6) antes de considerá-lo pronto — a regressão do Eval 3 é pequena em impacto agregado, mas é a única causada pela skill em si, não pela ausência dela.
