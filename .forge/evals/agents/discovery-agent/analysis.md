# Análise de benchmark — discovery-agent (agents)

Artefato avaliado: `template/.forge/agents/specifications/discovery-agent.md` (765 linhas).
Benchmark determinístico gerado por `scripts.aggregate_benchmark` (sem erro na primeira execução) em
`.forge/evals/agents/discovery-agent/workspace/iteration-1/benchmark.json` e `benchmark.md`; viewer estático em
`.../iteration-1/review.html` (gerado sem erro). `benchmark_ok = true`.

## 1. Resultado (lido de `run_summary` do benchmark.json)

| Configuração | pass_rate média | min | max | stddev |
|---|---|---|---|---|
| with_skill | 0.80 (80%) | 0.40 | 1.00 | 0.3464 |
| without_skill | 0.00 (0%) | 0.00 | 0.00 | 0.0000 |

Delta = 0.80 − 0.00 = **+0.80** → **veredito: agrega** (limiar ≥ 0.15 amplamente ultrapassado).

Três evals rodados, um run por configuração cada (`eval_metadata.json` não define repetições; o campo
`runs_per_configuration: 3` do benchmark.json é um placeholder herdado do agregador genérico de skills — não
reflete runs reais, já que só existe `run-1` em cada pasta `with_skill/`/`without_skill/`). Sem skill nenhum
eval passou nenhuma asserção; com skill, dois evals (`brownfield-recarga-pix-inicia-pelo-scan` e
`recusa-gerar-prd-e-stack-no-lugar-do-discovery`) fecharam 100%, e um (`consolida-notas-legadas-da-raiz`) fechou
40% (2/5), puxando a média para baixo e concentrando o valor real de melhoria a fazer no artefato.

## 2. Asserções não discriminantes

Nenhuma. Em nenhum dos três evals uma asserção passa igualmente nas duas configurações (nem sempre-passa nem
sempre-falha nos dois lados) — todo o conjunto de 14 asserções únicas discrimina a favor do skill (passa com,
falha sem) ou, no caso das três que falham mesmo com skill (eval `consolida-notas-legadas-da-raiz`), expõe um
gap real do artefato e não do desenho do eval. Isso é um sinal de que os casos estão bem calibrados — não há
"peso morto" a podar do benchmark.

## 3. Onde o artefato ajudou

- **Recusa de escopo (eval `recusa-gerar-prd-e-stack-no-lugar-do-discovery`, 100% com skill vs. 0% sem):** sem
  o artefato, o agente aceitou o pedido do usuário para gerar PRD e escolher stack diretamente
  (`transcript.md:13`: "decidi atender ao pedido explícito do usuário: gerar o PRD diretamente, escolher a
  stack e montar o esqueleto"), criando `docs/prd/prd.md`, `package.json`, `src/app/page.tsx`, `prisma/schema.prisma`
  etc. Com o artefato, a Seção 11 (Proibições: "gerar PRD", "escolher stack pelo usuário sem validação") e a
  Seção 9/10 (papel do discovery = alimentar o PRD Generator depois) produziram uma recusa fundamentada em
  substância (`outputs/agent-response.md:1`: "não posso pular direto para o PRD nem escolher a stack por conta
  própria — isso não é papel do discovery").
- **Estrutura obrigatória do `discovery-notes.md` (eval `brownfield-recarga-pix-inicia-pelo-scan`, 100% com skill
  vs. 0% sem):** sem o artefato, o agente escreveu um documento livre (`DISCOVERY-recarga-pix.md`, títulos como
  "## O que já li no repositório") e fez sete perguntas simultâneas (`transcript.md:20`: "Formulei sete perguntas
  de esclarecimento"). Com o artefato, a Seção 5 (estrutura obrigatória) e a Seção 3.1 (uma pergunta por vez)
  produziram o caminho oficial `docs/discovery/discovery-notes.md`, as nove seções `## 0` a `## 8` e exatamente
  uma pergunta (Q1) na resposta final.
- **Workspace scan como pré-requisito (Seção 3.5/4):** nos dois evals acima e no terceiro, a tabela 0.1 e as
  subseções 0.2/0.3 só aparecem com o artefato — sem ele o agente lista achados em bullets soltos ou nem lista.

## 4. Onde o artefato atrapalhou ou não bastou

Único ponto fraco real: eval `consolida-notas-legadas-da-raiz` (2/5 mesmo com skill), quando o usuário retoma
o discovery numa única mensagem que reafirma o problema **e** adianta voluntariamente decisões de perguntas
futuras (monetização = Q6, stack/plataforma = Q8/Q9) antes de o agente perguntar.

- **Contradição entre Seção 3.2 e Seção 7 (a causa raiz):** a Seção 3.2 ("Ordem obrigatória") diz "mesmo quando
  o workspace tiver informações úteis, use essas informações apenas para contextualizar a pergunta, não para
  pular a validação com o usuário" — mas só fala de informação vinda do *workspace*, não de informação que o
  *usuário* voluntaria fora de ordem na própria mensagem. A Seção 7 ("Registro de decisões") diz, sem
  condicionar à ordem das perguntas, "sempre que o usuário declarar uma decisão, registre" em `## 6. Decisões
  Registradas`. O agente seguiu a Seção 7 ao pé da letra e registrou Stack (4.1) e Plataforma (4.2) como fato
  decidido (`work/docs/discovery/discovery-notes.md:84,88`: "4.1 Stack: React..."; "4.2 Plataforma: PWA...") e
  criou DEC-001/002/003 — exatamente o que a asserção 4 do eval reprova. O artefato não resolve o conflito entre
  "sempre registre decisão declarada" e "nunca pule a ordem/validação", e a ambiguidade foi resolvida do lado
  errado pelo modelo.
- **Rule 3.4 (fatos decididos, proibição de hedges) sem exceção para citar o legado:** o agente, ao descrever
  no `0.2 Resumo do Contexto Existente` e em `1.2 Usuário Principal` o que o rascunho legado dizia, citou os
  próprios termos do legado ("possivelmente com luva e sol forte", "aparentemente") para ser transparente sobre
  a origem da incerteza (`discovery-notes.md:22,44`). A asserção 2 do eval reprova qualquer ocorrência dessas
  palavras no arquivo oficial, mesmo entre aspas/atribuídas ao legado. A Seção 3.4 não distingue "usar hedge como
  fato próprio" (proibido, correto) de "citar/relatar que o legado usava hedge, na Seção 0 que é sobre o que já
  existe" (uso legítimo de contexto) — o artefato não dá ao agente uma forma aprovada de reportar incerteza
  herdada sem tropeçar na lista de proibições.
- **Pergunta descrita, não feita:** a asserção 3 falhou porque a resposta final não contém nenhuma pergunta
  (`grep -c '?' outputs/transcript.md` = 0); o texto oficial diz, em prosa, que "a próxima pergunta obrigatória é
  a Q2" em vez de literalmente fazer essa pergunta ao usuário. As Seções 3.1/6.1 definem a ordem e o texto exato
  de cada pergunta (Q1..Q11), mas não dizem explicitamente que toda resposta do agente, mesmo numa retomada
  complexa, **deve terminar com a pergunta seguinte formulada de verdade** — nunca com a menção de qual seria.

## 5. Trechos ignorados, ambíguos, contraditórios ou que desperdiçam tempo

- **Contraditório:** Seção 3.2 ("ordem obrigatória", só fala de info do workspace) × Seção 7 ("sempre que o
  usuário declarar uma decisão, registre", sem falar de ordem) — ver §4. É a causa das 3 falhas do eval mais
  fraco.
- **Ambíguo:** Seção 3.4 lista palavras proibidas sem escopo — não diz se a proibição vale só para as seções
  1–6 (fatos do produto) ou também para a Seção 0 (Workspace Scan, que por natureza descreve incerteza alheia).
- **Duplicação que desperdiça espaço sem gerar erro:** a estrutura completa do `discovery-notes.md` aparece
  **três vezes** quase idênticas no artefato: linhas 209–253 (dentro de "4.2 Como registrar a inspeção", só a
  Seção 0), linhas 254–354 (Seção 5, "Estrutura obrigatória", documento inteiro) e de novo fragmentada nas
  Seções 7/8/9/10 (linhas 546 a ~660, repetindo os blocos "## 6. Decisões Registradas", "## 7. Pontos a Validar"
  e o resumo final). Nenhum eval acusou inconsistência entre as três cópias, mas são ~150 linhas de redundância
  em 765 — todo ajuste futuro na estrutura do documento precisa ser replicado em três lugares manualmente, o que
  é o tipo de coisa que historicamente diverge com o tempo.
- **Não exercitado por nenhum eval:** Seção 12 (Diferença entre tipos de iniciativa: Greenfield/Brownfield/Nova
  feature/Refatoração) tem conteúdo detalhado (linhas 694–745) mas nenhum dos três casos testou o comportamento
  de Refatoração nem validou se o agente detecta corretamente o tipo de iniciativa sozinho (o metadado "Tipo de
  iniciativa" aparece nos outputs mas nenhuma asserção verifica se foi classificado certo). Não é defeito do
  artefato, é lacuna de cobertura do benchmark (ver §6, qualidade dos casos).

## 6. Melhorias concretas priorizadas

1. **(Alto impacto, resolve a causa raiz do eval mais fraco) Reconciliar Seção 3.2 × Seção 7.** Adicionar à
   Seção 7 uma frase explícita: "Se o usuário, numa única mensagem, adiantar voluntariamente a resposta de uma
   pergunta futura (fora da ordem obrigatória da Seção 3.2), não registre em `## 6. Decisões Registradas`
   ainda — registre em `## 7. Pontos a Validar` citando a fala do usuário como motivo, e confirme
   formalmente quando a pergunta chegar na ordem." Isso fecha a asserção 4 do eval `consolida-notas-legadas-da-raiz`
   sem exigir reescrita do fluxo principal.
2. **(Alto impacto, mesmo eval) Delimitar o escopo da proibição de hedges (Seção 3.4).** Acrescentar: "Esta
   proibição vale para as Seções 1 a 6 (fatos do produto). Na Seção 0 (Workspace Scan), ao resumir o que um
   documento legado dizia, você pode citar/parafrasear a linguagem de incerteza do legado entre aspas, deixando
   claro que é uma citação do legado e não um fato assumido pelo discovery atual." Resolve a asserção 2.
3. **(Médio impacto) Tornar explícito, na Seção 3.1 ou na Seção 9, que toda resposta do agente — inclusive numa
   retomada complexa com múltiplos pontos a validar — deve terminar com a próxima pergunta obrigatória
   literalmente formulada, nunca apenas mencionada em prosa ("a próxima pergunta é Q2").** Uma linha bastaria:
   "Nunca descreva qual seria a próxima pergunta sem de fato fazê-la ao usuário nesta mesma mensagem."
4. **(Baixo impacto, manutenibilidade) Consolidar a estrutura do `discovery-notes.md`, hoje duplicada em três
   lugares (linhas ~209–253, ~254–354, ~546–660), numa única definição canônica referenciada pelas outras
   seções** (ex.: "ver estrutura completa na Seção 5; ao registrar decisões, use o bloco `## 6` definido lá").
   Não corrigiu nenhuma falha de eval, mas reduz o risco de as três cópias divergirem numa edição futura.
5. **(Cobertura de teste, não do artefato) Adicionar um eval de "Refatoração" ou "Nova feature" exercitando a
   Seção 12** e uma asserção que confira se o "Tipo de iniciativa" no cabeçalho bate com o cenário da fixture —
   hoje esse campo é preenchido mas nunca conferido.

## 7. Qualidade dos próprios casos (eval_quality)

Boa, com uma ressalva. Pontos fortes: os três `eval_metadata.json` têm asserções específicas e verificáveis por
comando (grep/test/git status com trechos e linhas citados como evidência no `grading.json`), cobrem três
ângulos distintos e realistas (scan inicial + pergunta única; retomada com legado + adiantamento de resposta;
recusa de escopo diante de pedido explícito do usuário para pular etapas) e nenhuma asserção é redundante entre
si (ver §2). A ressalva: a asserção 3 do eval `brownfield-recarga-pix-inicia-pelo-scan` tem uma nota do próprio
grading admitindo que "a resposta é a mensagem simulada gravada pelo executor... não uma sessão interativa
real" — como o protocolo é fundamentalmente multi-turno (uma pergunta por vez, aguardar resposta), avaliar por
uma única mensagem simulada de "retomada" é uma aproximação necessária para benchmark automatizado, mas deixa
de testar o comportamento real de manter estado entre turnos ao longo de Q1 a Q11. Não invalida os resultados
(delta ainda é fato observável e grande), mas limita o quanto dá para generalizar "with_skill = 80%" para uma
sessão real de dezenas de turnos.
