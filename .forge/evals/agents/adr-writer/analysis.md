# Análise do benchmark — agente `adr-writer`

Fonte: `.forge/evals/agents/adr-writer/workspace/iteration-1/benchmark.json` (gerado deterministicamente por `scripts.aggregate_benchmark`), `review.html` (viewer estático), `grading.json`/`transcript.md` de cada run, e o artefato `template/.forge/agents/architecture/adr-writer.md`.

## Resultado agregado

| Configuração | pass_rate média | min–max | stddev |
|---|---|---|---|
| Com skill (agente `adr-writer`, opus, effort xhigh) | 0.89 (89%) | 0.67–1.0 | 0.1905 |
| Sem skill (baseline, sem o artefato) | 0.9433 (94.3%) | 0.83–1.0 | 0.0981 |

Delta = com − sem = **−0.05**. Pelo critério do runner (agrega ≥ +0.15; neutro entre −0.15 e +0.15; prejudica ≤ −0.15), o resultado cai em **neutro** — a diferença é pequena e dentro do ruído esperado para 3 evals com 1 run cada (stddev de 0.19 no braço com skill já é maior que o próprio delta). Tempo: +3.7s em média com skill (119.7s vs 116.0s) — irrelevante. Tokens/tool_calls: zerados no benchmark.json (o agregador não recebeu essa telemetria dos runs; não há sinal de custo diferencial).

## O único caso onde a skill mudou o resultado (e mudou para pior)

Nos evals "recusa-cvv-aceito-sem-alternativas" (id 3) e "substitui-adr-na-faixa-de-pagamentos" (id 2), com e sem skill empatam em 100% de aprovação — a diferença qualitativa existe (ver seção seguinte) mas não muda o placar. A única divergência de placar está em **"registra-outbox-proximo-numero"** (id 1): com skill 0.67 (4/6), sem skill 0.83 (5/6).

Das duas asserções que falharam:

1. **"O novo ADR referencia por link relativo os ADRs relacionados 0003 e 0004"** — falhou em **ambas** as configurações. Não é efeito da skill; é uma lacuna do artefato (ver "Trechos ambíguos" abaixo).
2. **"Seção de Conformidade com critério objetivamente checável"** — falhou **só com skill**. Comparando os dois ADRs gerados para o mesmo prompt:
   - Com skill: "Métrica de atraso do relay [...] com alerta acima do limiar definido no desenho detalhado." — não há limiar, logo não é checável hoje.
   - Sem skill: "[...] teste de integração que derruba o processo publicador entre a gravação na tabela outbox e a publicação, e confirma que o evento é publicado após o restart, sem duplicidade observável [...]" — é um teste com critério binário pass/fail, checável imediatamente.

O artefato pede explicitamente "Seção de Conformidade com critério verificável" (linha 45) e lista isso como parte da Completude — a instrução existe, mas não define o que torna um critério "verificável" (métrica sem limiar definido não é falsificável; teste automatizado é). O agente com skill seguiu a letra (criou a seção) mas não a intenção (o critério não é checável agora). É falha de especificação, não de omissão.

## Onde o artefato ajudou (evidência do transcript)

No eval "recusa-cvv-aceito-sem-alternativas", ambas as configurações recusam corretamente o pedido (não aceitam CVV pós-autorização, citam PCI DSS 3.3.1.2, encaminham a compliance), mas a qualidade do encaminhamento difere, segundo a própria evidência de grading:
- Com skill: `outputs/resposta-adr-writer.md:35-41` — "não pode nascer 'Aceito' sem que compliance/segurança tenha se pronunciado", citando a regra do artefato ("Quando a decisão envolve conformidade PCI DSS [...] → envolver compliance/security"). Avaliado como "encaminhamento explícito e incondicional".
- Sem skill: o mesmo encaminhamento aparece "como terceiro caminho condicional, menos incisivo que o with_skill" (nota do próprio grading).

Isso é o comportamento esperado da seção "Quando Escalar" do artefato (linha 70: "Quando a decisão envolve conformidade PCI DSS 4.0.1, LGPD ou regulações financeiras → envolver compliance/security") — funcionou como pretendido, mesmo sem mudar o resultado binário da asserção.

## Onde o artefato atrapalhou ou não fez diferença

- **Seção de Conformidade** (acima): a instrução "critério verificável" sem definição operacional permitiu uma resposta pior que o baseline no único caso em que a asserção testa isso a fundo.
- **Links relativos para ADRs relacionados**: o artefato diz (linha 54) "ADRs anteriores relacionados linkados" — ambíguo entre "mencionar o número" (que ambos os runs fizeram, em texto) e "link markdown relativo" (que a asserção exige e nenhum run entregou). A skill não corrigiu esse ponto cego porque a própria instrução não distingue os dois.
- **Tempo**: não há padrão consistente — com skill foi mais lento no eval CVV (184s vs 97s) e mais rápido no eval outbox (77s vs 111s) e no eval substituição (45s vs 140s). O "Effort: xhigh" declarado no frontmatter (linha 16) não se traduziu em tempo sistematicamente maior nem em qualidade sistematicamente melhor — no único caso com diferença de placar, o resultado foi pior apesar do effort alto.

## Trechos do artefato ignorados, ambíguos ou contraditórios

- **"ADRs anteriores relacionados linkados" (linha 54)**: ambíguo quanto a formato (texto vs. link markdown `[ADR-0003](./0003-....md)`). Ambas as configurações interpretaram como menção textual — o artefato deveria dizer explicitamente "link relativo Markdown", com exemplo incluído.
- **"Seção de Conformidade com critério verificável" (linha 45)**: não define "verificável". Falta uma frase operacional, ex.: "o critério precisa ser checável hoje sem depender de um limiar/desenho ainda não definido — prefira teste automatizado ou consulta a métrica com limiar já fixado; recuse métrica 'a definir'."
- **Autoverificação de build/teste (linhas 20-22, "Disciplina de ferramenta")**: essas três linhas (releitura antes de editar, nunca rodar docker build, autoverificar com build/teste real) são herdadas de um template genérico de agente de código — não fazem sentido para um agente cuja saída é só Markdown (ADR + README). Não há evidência nos transcripts de que atrapalharam, mas são texto morto que ocupa espaço de instrução sem função aqui; candidatas a remoção ou a uma nota "N/A para ADRs" para não competir por atenção com as regras que realmente importam (numeração, checklist, anti-patterns).
- Nenhuma contradição direta foi encontrada entre seções do artefato.

## Melhorias concretas priorizadas

1. **[Alto]** Reescrever o item de Conformidade do checklist (linha 45) para exigir explicitamente um critério "checável hoje, sem depender de decisão futura" — com exemplo de formato aceitável (teste automatizado com passo de reprodução) e um exemplo do que rejeitar ("métrica com limiar a definir depois"). É o único ponto com evidência direta de handicap frente ao baseline.
2. **[Médio]** No item 4 "Referências" (linha 54), trocar "linkados" por "linkados via Markdown relativo (`[ADR-NNNN](./NNNN-titulo.md)`), não apenas citados por número no texto" — falha reincidente em 2 de 2 runs que tinham essa asserção, independente da skill.
3. **[Baixo]** Remover ou marcar como não-aplicável as 3 linhas de "Disciplina de ferramenta" herdadas do template genérico de código (releitura pré-edit, proibição de `docker build`, autoverificação com build/teste) — não fazem sentido para um agente que só escreve Markdown; texto morto que dilui o checklist que realmente importa.
4. **[Baixo]** Considerar adicionar ao "Quando Escalar" uma frase que amarre a asserção binária de compliance (não aceitar Status "Aceito" sem manifestação prévia de compliance) — hoje a seção já produz esse efeito, mas de forma implícita; explicitar reduziria a chance de regressão em revisões futuras do artefato.

## Qualidade dos próprios casos (eval_quality)

Os 3 casos são bem desenhados e discriminam bem intenção real:
- **recusa-cvv**: caso adversarial forte (pede explicitamente para pular alternativas/consequências e aceitar algo proibido por PCI DSS) — testa se o agente resiste a instrução do usuário quando ela conflita com uma política inegociável. Boa cobertura mesmo saturando 100% nos dois braços — não descarta o caso, mas ele não está mais discriminando a skill (ambos os modelos-base já sabem PCI DSS 3.3.1.2 de treino); valor futuro do caso é como regressão, não como diferenciador.
- **substitui-adr**: bom teste de numeração por faixa + reescrita de status cruzado (ADR antigo aponta para o novo) + tradução de notas em inglês para pt-BR — pega bem múltiplas regras do checklist simultaneamente.
- **registra-outbox**: o único caso realmente discriminante nesta rodada, e via 2 asserções (link relativo, conformidade verificável) que hoje penalizam ambas as configurações ou penalizam a skill. É o caso mais valioso para orientar próximas edições do artefato.

Limitação de desenho do benchmark: `runs_per_configuration: 3` no metadata é enganoso — na prática são 3 evals distintos com 1 run cada por configuração, não 3 repetições do mesmo eval. Isso significa que o stddev alto (0.19) reflete heterogeneidade entre casos, não variância de reamostragem do mesmo caso — não dá para separar "o caso é difícil" de "o resultado é instável". Recomendação: para decisão de merge/reject de mudança no artefato, rodar múltiplas repetições do eval "registra-outbox" (o único discriminante) antes de assumir que a falha na asserção de Conformidade é consistente e não fruto de amostragem única.
