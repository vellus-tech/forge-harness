# Análise do benchmark — skill `c4-render`

Fonte determinística: `workspace/iteration-1/benchmark.json` (gerado por `scripts.aggregate_benchmark`), `workspace/iteration-1/review.html` (viewer estático), grading.json e transcript.md de cada `eval-*/{with_skill,without_skill}/run-1`, e o artefato `template/.forge/skills/c4-render/SKILL.md`.

## 1. Resultado

| Configuração | Pass rate | Detalhe por eval |
|---|---|---|
| Com skill | 86.7% (média de 3 evals; min 60%, max 100%) | eval 1 (geração overview): 100% (6/6) · eval 2 (curadoria de rótulo): 100% (5/5) · eval 3 (recusa de inventar relação): 60% (3/5) |
| Sem skill | 33.3% (min 0%, max 60%) | eval 1: 0% (0/6) · eval 2: 40% (2/5) · eval 3: 60% (3/5) |
| Delta | **+0.53** | benchmark_ok = true (script rodou sem erro na primeira tentativa) |

Veredito: **agrega** (delta ≥ 0.15).

Ressalva de leitura: `benchmark.md`/`metadata.runs_per_configuration` dizem "3 runs each per configuration", mas cada eval só tem `run-1` — são 3 evals × 1 run, não 3 runs por config. É um rótulo herdado do script de agregação (genérico, não específico deste dogfood), não um erro de dado; a média/stddev exibidas são sobre os 3 evals, o que é a leitura correta.

## 2. Asserções não discriminantes

- Eval 3, asserção 1 ("C2 não ganha aresta billing→ledger/notifications") e asserção 2 ("nada commitado sob `.forge/graph/c4/` ou `overview.html`") passam em **ambas** as configurações (com e sem skill). Não diferenciam a skill: mesmo sem instrução nenhuma, o agente não inventou aresta nem rodou `git commit` (a regra global do harness proibindo commit nesta execução já garante isso, independente da skill). Candidatas a sair do benchmark ou a virar somente sanity-check.
- Eval 2, asserção "rótulos curados persistem no estado final" (não volta a exibir `src/billing (2)`) também passa nas duas configurações — mede se o agente evitou re-rodar `c4.sh` depois de editar à mão, comportamento que nenhuma das duas execuções violou.

## 3. Onde o artefato ajudou

- Eval 1 (sem skill, 0/6): o agente releu o repositório manualmente, escreveu os três C4 em `docs/architecture/c4-*.mmd` usando sintaxe `C4Context/C4Container/C4Component` (não Mermaid `flowchart`), gerou `docs/architecture/overview.html` em vez de `.forge/graph/overview.html`, e usou em-dash no rótulo (linha 2 de `c4-context.mmd`). Todas as seis asserções falharam porque o caminho/protocolo de saída (§17.7 "entrada estreita, saída estreita" e "não relê o repositório") só existe na skill. Com a skill, o mesmo tipo de tarefa passou 6/6: grafo garantido via `graph.sh build`, C4 gerado via `c4.sh` em `.forge/graph/c4/*.md`, overview em `.forge/graph/overview.html`, resposta final apontando o arquivo sem colar Mermaid/HTML.
- Eval 2 (rótulo com ponto e travessão): sem skill, o agente gravou o texto literal pedido pelo usuário (`"Pagamentos Core v1.4.0 — PCI DSS 4.0.1"`), violando a convenção de labels e quebrando potencialmente o parser Mermaid — e não avisou o usuário da adaptação necessária. Com a skill, a seção "Convenção de labels (inegociável)" foi citada explicitamente no transcript (`transcript.md:26-28`) e o agente sanitizou (`v1 4 0`, `4 0 1`, sem em-dash) e explicou a divergência ao usuário. Isso é o núcleo de valor da skill: uma regra que o modelo não infere sozinho (a convenção é arbitrária ao harness) e que, sem o artefato, é violada silenciosamente.
- Eval 3 (com skill, 3/5): a skill deu ao agente a base para recusar a fabricação de arestas — citou literalmente "não invente relações que o grafo não tem" (`transcript.md:7`). Ainda assim, a execução sem skill também recusou a fabricação (3/5, mesmo padrão de acerto/erro), então aqui a skill não foi decisiva; ver seção 4.

## 4. Onde o artefato atrapalhou ou não bastou (eval 3, com skill, 2 falhas)

- **Asserção "consulta ao grafo antes de recusar" falhou mesmo com a skill.** O agente verificou a ausência de import de `billing` para `ledger/notifications` lendo o código-fonte em `work/src/` (`transcript.md:9-13`), não com `graph.sh query`/`graph.sh path`. O `SKILL.md` nunca menciona esses subcomandos — só manda "garantir o grafo" (`build`/`update`) e "gerar tudo" (`c4.sh`); não há orientação de como *consultar* o grafo para validar ou refutar uma relação antes de aceitar/recusar uma edição pedida pelo usuário. Isso contraria a premissa do §17.7 citada na própria skill ("não relê o repositório") — na prática o agente relê o repositório para decidir, porque a skill não lhe dá outro caminho.
- **Asserção "explica que `.forge/graph/c4/` e `overview.html` são artefatos gerados, fora do commit, a regenerar" falhou.** O agente ofereceu comitar os C4 "exatamente como estão" (`despacho-simulado.md:14`, `resposta-ao-usuario.md:18`). O `SKILL.md`, seção "Limites", só diz que **`overview.html`** "é artefato de visualização (fora do commit)" — não estende essa regra aos `.md` de `.forge/graph/c4/`, nem diz explicitamente "não commitar `.forge/graph/`" em lugar nenhum do artefato. O agente não tinha de onde tirar essa regra; a frase da skill é ambígua sobre se cobre só o HTML ou toda a árvore gerada.
- A execução sem skill teve o mesmo padrão de acerto/erro no eval 3 (3/5, falhando nas duas mesmas asserções), então este é o caso onde a skill **não** move a agulha — indício de que a lacuna é real (afeta as duas condições igualmente) e não um efeito do prompt do fixture.

## 5. Trechos do artefato ignorados, ambíguos, contraditórios ou que desperdiçam tempo

1. **Extensão errada no protocolo (contradiz a implementação).** Passo 2 do "Protocolo": `bash .forge/scripts/c4.sh` → `.forge/graph/c4/*.mmd` + `.forge/graph/overview.html`. O gerador real (`lib/c4-gen.mjs`, comentário nas linhas 4-8 e `writeFileSync` na linha 48) escreve **`.md`** (Markdown envolvendo um bloco ```mermaid), justamente para renderizar em qualquer previewer — e ativamente remove `.mmd` legado (linha 200: `if (f.endsWith('.mmd')) rmSync(...)`). Um agente que confiar literalmente no `SKILL.md` para localizar/nomear arquivos vai procurar `*.mmd` e não achar nada (foi exatamente o engano do agente sem skill no eval 1, que criou `.mmd` do zero). Correção: trocar `*.mmd` por `*.md` no protocolo.
2. **"Não relê o repositório" (§17.7) sem alternativa de consulta.** A skill afirma a garantia mas não ensina como validar/refutar uma relação sem ler o código — falta uma linha citando `graph.sh query <termo>` e `graph.sh path <a> <b>` (ambos já existem no script, ver `graph.sh:7,29-59`) como o caminho correto para checar se uma relação existe antes de aceitar ou recusar uma edição pedida por humano. Isso é a causa direta da falha 1 do eval 3.
3. **"Limites" ambíguo sobre o que fica fora do commit.** "O `overview.html` [...] é artefato de visualização (fora do commit)" — a frase não diz se `.forge/graph/c4/*.md` também é gerado/fora do commit, ou se só o HTML final é. Um agente literal (como o do eval 3) pode legitimamente entender que os `.md` do C4 podem ser versionados. Causa direta da falha 2 do eval 3.
4. **Nenhuma orientação sobre o caso "usuário pede uma aresta que o grafo não sustenta"** — o cenário mais delicado do artefato (fabricar relação vs. recusar) é coberto por uma frase genérica ("não invente relações que o grafo não tem"), sem dizer o que fazer em seguida (registrar como ADR, marcar TODO no C2, oferecer regenerar após implementar). O agente teve que improvisar a alternativa nas duas condições — funcionou, mas por bom senso do modelo, não por instrução do artefato.

## 6. Melhorias concretas priorizadas

1. **(alta, corrige contradição factual)** No "Protocolo", trocar `.forge/graph/c4/*.mmd` por `.forge/graph/c4/*.md` — alinhar com o que `c4-gen.mjs` de fato grava. Sem isso, qualquer agente que precise localizar os arquivos gerados por nome de extensão erra.
2. **(alta, fecha a lacuna do eval 3)** Adicionar ao "Protocolo" ou aos "Limites" uma linha: *"Para checar se uma relação existe antes de aceitar/recusar uma curadoria de aresta, use `bash .forge/scripts/graph.sh query <termo>` ou `graph.sh path <origem> <destino>` — não releia o código-fonte manualmente."* Isso resolve a asserção 3 do eval 3 e reforça a garantia de "entrada estreita" que a skill já promete.
3. **(alta, fecha a outra lacuna do eval 3)** Estender explicitamente a frase de "Limites" para: *"`overview.html` e todo `.forge/graph/c4/*.md` são artefatos gerados de visualização, fora do commit — regenere-os a partir do grafo em vez de versioná-los ou editá-los para adicionar semântica que o grafo não sustenta."* Isso também fecha uma segunda leitura possível hoje (que só o HTML é gerado).
4. **(média)** No "Limites", acrescentar uma frase de próximo-passo para o caso "usuário pede relação que o grafo não tem": *"Recuse a aresta, mostre a evidência do grafo (query/path) e ofereça: (a) implementar a chamada real e regenerar, ou (b) registrar a relação pretendida em ADR/TODO — nunca adicionar a seta a mão."* Isso transforma um comportamento hoje dependente do bom senso do modelo em instrução auditável.
5. **(baixa, higiene do benchmark)** As três asserções listadas na seção 2 (não inventar aresta, não commitar nada, rótulo curado persistir) não discriminam com/sem skill neste conjunto de fixtures — considerar removê-las do eval ou trocá-las por uma checagem mais específica (ex.: exigir explicitamente a citação de `graph.sh query/path` na resposta, que é justamente a lacuna real encontrada).

## 7. Qualidade dos casos (eval_quality)

- Os três casos cobrem bem o espectro esperado da skill: geração do zero (eval 1), curadoria de rótulo dentro da convenção inegociável (eval 2) e o caso adversarial de fabricação de aresta + pedido de commit (eval 3) — boa cobertura de "quando usar" e dos dois limites documentados (labels e relações).
- Eval 3 é o mais valioso e o mais bem desenhado (mistura dois pedidos no mesmo prompt — inventar aresta e commitar — forçando duas decisões independentes), mas duas de suas cinco asserções (seção 2) não discriminam e deveriam ser podadas ou ajustadas para testar exatamente o que falhou (uso de `graph.sh query/path`, e o entendimento de que os `.md` do C4 também são gerados).
- Os `grading.json` trazem evidência de comando (`grep`, `diff`, caminho:linha) para cada asserção, o que torna a análise auditável e reduz risco de avaliação por "olho" — boa prática do harness de eval, não da skill em si.
- Achado de processo (fora do escopo do texto da skill, mas relevante para quem mantém o benchmark): `benchmark.json.metadata.runs_per_configuration = 3` e o cabeçalho de `benchmark.md` ("3 runs each per configuration") não correspondem aos dados reais (1 run por eval/config, 3 evals) — rótulo herdado do agregador genérico; não invalida o resultado, mas pode confundir quem ler só o `.md`.

**Qualidade geral dos casos: boa** (cobertura correta dos limites documentados; pequeno excesso de asserções não discriminantes em 1 de 3 casos, sem impacto no veredito).
