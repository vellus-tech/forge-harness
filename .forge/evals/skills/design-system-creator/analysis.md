# Análise do benchmark — design-system-creator

Fonte determinística: `workspace/iteration-1/benchmark.json` (gerado por
`scripts.aggregate_benchmark`, sem cálculo manual) e `workspace/iteration-1/review.html`
(viewer estático). 3 evals × 1 run cada configuração (with_skill / without_skill).

## 1. Resultado (run_summary do benchmark.json)

| Configuração | pass_rate (média) | stddev | min | max |
|---|---|---|---|---|
| with_skill | 82.33% | 16.62 pp | 67% | 100% |
| without_skill | 33.33% | 30.55 pp | 0% | 60% |

Delta = 0.8233 − 0.3333 = **+0.49**. `benchmark_ok = true` (script rodou de primeira, sem
necessidade de correção de estrutura). Veredito por limiar (delta ≥ 0.15): **agrega**.

Tempo médio: with_skill 473s vs without_skill 232s (+241s). Tokens/tool_calls vêm zerados nos
dois lados — a instrumentação de custo não foi capturada nestes runs (nota de qualidade do eval,
não do artefato); não dá para avaliar overhead real de contexto pela métrica de tokens, só pelo
tempo de execução relatado.

## 2. Assertivas não discriminantes

- Nenhuma assertiva passa 100% nas duas configurações (não há "sempre passa" que deixe de
  diferenciar a skill) nem falha 100% nas duas — todas as 16 assertivas têm pelo menos uma
  divergência entre with/without, exceto uma: **eval 1, assertiva de branch** (`git branch
  --show-current` = `feat/design-system/rotaviva-ui-kit`) falha nas duas configurações. A nota do
  próprio grading marca isso como **inconclusiva por desenho do ambiente**: "as regras do harness
  de eval proibiam git checkout, o que torna esta asserção insatisfazível neste ambiente" — ou
  seja, o caso de teste pede um efeito (`git switch -c`) que a sandbox do benchmark bloqueia
  estruturalmente, então essa assertiva mede a sandbox, não a skill. Recomendo reformulá-la (ver
  §4) ou tratá-la como skip quando `git checkout` estiver vetado pelo harness.

## 3. Onde o artefato ajudou / atrapalhou (com evidência de transcript)

### Ajudou

- **Recusa correta sem link (eval 3)** — with_skill 100% (5/5) vs without_skill 60% (3/5). A
  resposta with_skill nomeia a stack fixa da skill ("O design-system-creator fixa CSS Modules +
  tokens ... sem Tailwind, sem Radix" — `assistant_response.md:7`) e recusa a main citando a regra
  literal da skill ("Nunca trabalhar no `main`" — `assistant_response.md:9`). A resposta
  without_skill, sem essa âncora, aceita Tailwind+Radix em silêncio ("não vejo nada neste repo ...
  que contradiga isso" — `response.md`) e indica `feature/<change-id>` em vez do branch nomeado da
  skill — as duas assertivas de stack/branch falham só sem a skill.
- **Preservação de brownfield (eval 2, tokens/docs existentes)** — as duas configurações
  preservam corretamente `tokens.css`/`package.json`/`tokens.md` (assertivas 1–2 passam nos dois
  lados: o comportamento de "não recriar o que já bate" não é exclusivo da skill aqui). A diferença
  aparece nos blocos: with_skill materializa os 20 arquivos esperados em
  `packages/ui-components/src/blocks/<Nome>/{...}` (passou); without_skill produz "arquivos planos
  (`src/blocks/AppHeader.tsx` etc.), sem subpasta" e sem `.stories.tsx`/`.test.tsx`/`.module.css` —
  a skill é quem define a convenção de pasta-por-componente que sem ela não emerge.
- **Mark como PNG, não SVG (eval 1)** — with_skill acerta `IconSize`, `RotavivaMark` via
  `new URL(...png)` sem `<svg>`; without_skill não cria `packages/icons` (ícone vira
  `IconPlaceholder` textual embutido em `RotavivaBlocks.tsx`, PNGs copiados para
  `ui-components/src/assets/brand/` em vez de `packages/icons/assets/`). A separação
  `@<slug>/icons` como pacote próprio só aparece com a skill.

### Atrapalhou / não garantiu o que promete

- **"Tokens-only" no CSS Module não é verificado nem cumprido (eval 1)** — a skill instrui
  explicitamente (linha 98 do SKILL.md): "CSS Module tokens-only (`var(--s-4)`, nunca `16px`;
  `var(--brand)`, nunca o hex)", e o próprio transcript with_skill declara ter seguido isso
  ("`.module.css` (tokens-only)" — `transcript.md:53`). O grading, porém, encontrou
  `Badge.module.css:11` com `background: #E6F4EA;` e `:16` com `background: #FFF4E0;` — hex
  literal copiado do preview HTML, contradizendo tanto a regra quanto a autodeclaração do agente.
  Isso é o achado mais grave: o artefato dá a regra certa mas não dá ao agente nenhum mecanismo
  para se autoverificar antes de reportar sucesso — ele "lembra" da regra em prosa mas não a testa.
- **Passo de branch é prosa, não script, e conflita com o sandbox do eval** — "Branch: git switch
  -c feat/design-system/<slug>-ui-kit" (linha 78) é a única ação da DoD que nenhuma das três
  configurações consegue satisfazer quando `git checkout` está vetado; nas duas runs onde a skill
  foi seguida a mais, o agente documentou a intenção em vez de executar (comportamento correto dado
  a restrição), mas isso derruba a pass_rate do eval 1 nas duas configurações por igual — sem
  discriminar a skill, só penalizando o desenho do caso.

## 4. Trechos ignorados, ambíguos, contraditórios ou que desperdiçam tempo

- **Ambíguo — "tokens-only" sem guard-rail executável.** A skill (linha 98) proíbe hex em
  `.module.css` só em prosa. Sugestão concreta: embutir no passo 6/9 um comando de verificação
  determinística, por exemplo `grep -rnE "#[0-9a-fA-F]{3,8}\b" packages/ui-components/src/**/*.module.css`
  esperando saída vazia, do mesmo jeito que a seção "Proibições" já lista a regra — script > prosa,
  como o próprio caso de teste comprovou (é exatamente o grep que o grader rodou para pegar o
  Badge).
- **Contraditório com o ambiente do harness/eval — passo 3 "Branch".** A instrução manda
  `git switch -c` sem prever runs onde git mutável está vetado (comum em avaliação/CI restrita).
  Sugestão: adicionar uma frase de fallback explícita — "se `git switch`/`checkout` estiver
  bloqueado neste ambiente, registre o comando que seria executado e prossiga o trabalho na árvore
  atual sem branch" — isso já é o que os dois agentes fizeram por bom senso, mas formalizar remove
  a ambiguidade e evita que a skill pareça ter falhado quando é o ambiente que impede o passo.
- **Desperdiça tempo — passo 1 (download) não tem fallback para offline/cópia local.** Os três
  fixtures do eval já vêm com "network para api.anthropic.com bloqueada, use esta cópia local" —
  a skill (passo 1) só descreve `curl`/`tar.gz` da rede real. O agente com skill teve que inferir
  sozinho o desvio (mapear `design-handoff/<slug>/` local para o "bundle extraído"); funcionou nos
  três casos, mas é uma inferência não coberta pelo texto. Sugestão: acrescentar uma linha "se o
  bundle já estiver extraído localmente (ex.: passado como diretório), pule o curl/tar e comece
  direto no passo 2" — reduz a chance de um agente menos cuidadoso tentar baixar e travar.
- **Estrutura de `blocks/` (pasta-por-componente) não está explícita o bastante.** A linha 99
  (`blocks/`) não repete a convenção de arquivo `Componente/{Componente.tsx, .module.css,
  .stories.tsx, .test.tsx}` que a linha 98 (`components/`) define para primitivos — ela diz só "um
  componente por bloco ... Story `Blocos/...`, teste + runA11y". O agente com skill acertou por
  analogia com a seção de primitivos, mas o texto não garante isso; without_skill, sem a analogia
  guiada, produziu arquivos soltos. Sugestão: repetir explicitamente o padrão de pasta em `blocks/`
  em vez de depender de o agente inferir a partir de `components/`.

## 5. Melhorias concretas priorizadas

1. **[Alto] Embutir grep de guard-rail contra hex em `.module.css`** no passo 9 (verificação) do
   SKILL.md, ao lado dos comandos de build/test já listados — script determinístico, não prosa.
   Teria pego o `Badge.module.css` do eval 1 antes do agente reportar sucesso.
2. **[Alto] Formalizar o fallback de branch bloqueado** no passo 3 — uma frase condicional
   cobrindo "git mutável vetado neste ambiente" evita que a única assertiva de branch continue
   inconclusiva em qualquer harness de avaliação restrito, e documenta o comportamento correto que
   os dois agentes já adotaram por conta própria.
3. **[Médio] Explicitar a convenção de pasta em `blocks/`** (repetir o padrão
   `<Nome>/{<Nome>.tsx, .module.css, .stories.tsx, .test.tsx}` já usado em `components/`) em vez de
   deixar implícito por analogia — reduz a variância entre agentes que seguem a skill à risca.
4. **[Baixo] Acrescentar linha de fallback offline/bundle-já-extraído** no passo 1, cobrindo o
   padrão comum nos fixtures de eval (bundle local, sem rede) sem exigir inferência do agente.
5. **[Baixo] Fundir a nota de contraste** (linha 148, "armadilhas") com a instrução de
   `accessibility.md` (linha 125) — hoje o valor do contraste aparece como "~3.3:1" na seção de
   armadilhas e "~3.4:1" no requisito de `accessibility.md`; são números ligeiramente diferentes
   para a mesma medição e vale unificar numa fonte única (evita um agente citar o valor errado por
   picking a seção errada).

## 6. Qualidade dos próprios casos (eval_quality)

- **eval 1 (implementa-handoff-greenfield-rotaviva)** — assertivas bem fundamentadas e checáveis
  por comando (`cmp`, `grep`, `git rev-list`), mas a assertiva de branch é estruturalmente
  insatisfazível sob a política do harness de eval que veta `git checkout`/criação de branch —
  isso derruba pass_rate nas duas configurações por um motivo alheio à skill. Qualidade: boa,
  com uma assertiva a corrigir (tornar condicional a "se git mutável permitido").
- **eval 2 (brownfield-tokens-existentes)** — assertivas específicas e bem ancoradas em fixture
  real (`cmp` byte-a-byte contra o overlay); a última assertiva (docs + branch) é composta
  (conjuntiva) misturando dois fatos independentes (conteúdo dos docs vs. estado do branch) — a
  run with_skill passa nos docs mas falha só no branch, e a assertiva combinada marca falha total,
  escondendo o sucesso parcial. Qualidade: boa, mas separar em duas assertivas daria sinal mais
  fino.
- **eval 3 (sem-link-pede-handoff-e-recusa-tailwind-main)** — cinco assertivas independentes,
  cada uma isolando um comportamento discreto (não mexe no work/, não cria branch, pede o link,
  recusa Tailwind/Radix em silêncio, recusa a main) — é o caso com melhor poder discriminante do
  lote (100% vs 60%, sem nenhuma assertiva ambígua ou conjuntiva). Qualidade: muito boa, usar
  como modelo para reformular a assertiva composta do eval 2.
- Amostra pequena (n=1 run por configuração/eval): a stddev alta do with_skill (16.6 pp) e do
  without_skill (30.6 pp) reportada no benchmark.json é a variação entre evals, não entre runs
  repetidas da mesma configuração — não há replicação suficiente para separar variância do agente
  de variância do caso. Recomendação de processo (fora do escopo de editar o SKILL.md): rodar
  `runs_per_configuration` > 1 antes de tratar qualquer delta isolado como definitivo.
