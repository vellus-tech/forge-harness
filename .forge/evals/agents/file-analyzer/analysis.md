# Análise de benchmark — agente `file-analyzer` (graph)

Artefato avaliado: `template/.forge/agents/graph/file-analyzer.md`. Fonte determinística: `workspace/iteration-1/benchmark.json` (gerado por `scripts.aggregate_benchmark`, sem cálculo manual). Viewer estático: `workspace/iteration-1/review.html`.

## 1. Resultado (benchmark.json → run_summary)

- Com skill: pass_rate médio 0,9333 (93,3%), desvio 0,1155, min 0,8, max 1,0.
- Sem skill: pass_rate médio 0,4433 (44,3%), desvio 0,3156, min 0,2, max 0,8.
- Delta = 0,9333 − 0,4433 = **+0,49**.
- Tempo: com skill 96,7s ± 17,1s vs sem skill 80,3s ± 8,4s (delta +16,3s) — o artefato custa mais tempo de execução, sem custo de tokens medido (tokens = 0 em ambas as configurações; a métrica de tokens não foi instrumentada nesta rodada, não é um "0 real").
- Cada eval rodou 1 vez por configuração (`runs_per_configuration: 3` no metadata, mas só há `run-1` em cada pasta — o desvio-padrão do run_summary vem da variação ENTRE os 3 evals, não de repetições do mesmo eval; ver §5, ambiguidade de execução).

## 2. Asserções não discriminantes (mesmo resultado nas duas configurações)

Comparando pares de asserções equivalentes entre `with_skill` e `without_skill` por eval:

- **eval enriquece-repositorio-de-tarifas**: "nomeia o que expõe + dependência de persistência" (ambas true) e "sem bloco de código/trechos copiados" (ambas true) — passam nas duas configurações; refletem competência geral de leitura de código, não algo que o artefato ensina.
- **eval nao-especula-alem-do-codigo**: das 5 asserções, 3 não discriminam — "não afirma capacidades inexistentes (ML/blacklist/velocity/ClearSale)" (ambas true), "menciona cartaoAceito + 2 fatos do código" (ambas true) e "sem juízo de valor" (ambas true). Só a asserção de tamanho (≤280 caracteres/1-3 frases) e a de não-reprodução de código realmente separam as configurações neste eval.
- **eval cache-valido-nao-resumariza**: só a asserção "arquivo do usuário permanece intocado" passa nas duas configurações — mas trivialmente, porque nenhuma das duas execuções edita o arquivo-fonte do usuário; não mede nada do artefato.

Conclusão: dos 16 pares de asserções comparáveis, 6 (37%) não discriminam. O eval `nao-especula-alem-do-codigo` é o mais fraco nesse sentido — 60% das suas asserções passam com e sem o artefato.

## 3. Onde o artefato ajudou (evidência de transcript/grading)

1. **Limite de tamanho (≤280 caracteres, 1-3 frases) é a asserção mais confiável do conjunto**: falha em ambos os evals sem skill (802 caracteres em enriquece-repositorio-de-tarifas; 672 caracteres em nao-especula-alem-do-codigo) e passa em ambos com skill (228 e 278 caracteres). Evidência: `benchmark.json`, asserções 1 de cada eval; transcript do eval nao-especula-alem-do-codigo com skill, passo 11, relata que o agente mediu com `python3 -c 'print(len(...))'` e ajustou duas vezes até caber.
2. **Restrição de escopo — o agente não deve editar `graph.json`/cache diretamente**: no eval enriquece-repositorio-de-tarifas, o run sem skill leu o `graph.json`, decidiu por conta própria mudar `layer` para `"persistence"` e escreveu um script Python para editar o nó (transcript, passos 8-9) — falhou a asserção 6 (grafo deveria ficar idêntico ao commit da fixture). O run com skill nunca tocou o grafo, entregando só `outputs/summary.txt` (asserção 6 passa). É a diferença mais decisiva do lote.
3. **Determinismo de cache por fingerprint estrutural**: no eval cache-valido-nao-resumariza, o run sem skill recalculou um SHA-256 bruto do arquivo (que mudou porque a edição do usuário era só cosmética: comentário + reindentação), concluiu que o cache estava desatualizado e reescreveu summary/fingerprint incorporando o texto do comentário (portaria SMT 14/2025) como se fosse fato do código — falhou 4 das 5 asserções. O run com skill rodou `graph.sh update`, leu a mensagem determinística "OK graph up to date (no structural change — zero tokens)" e corretamente se absteve de gerar um summary novo — 5/5. Esse é o eval com maior delta absoluto (0,2 → 1,0).
4. **Evitar juízo de valor**: no eval enriquece-repositorio-de-tarifas, o run sem skill escreveu "...o que o torna um ponto central de acoplamento..." (avaliativo, proibido) e falhou; o run com skill manteve tom descritivo.

## 4. Onde o artefato atrapalhou ou não ajudou

- **Uma reprovação do run com skill (eval nao-especula-alem-do-codigo, asserção 5) é provavelmente um falso negativo do desenho do eval, não do artefato**: o `grading.json` reprova porque `outputs/antifraude-cartao.ts.analisado` — uma cópia do arquivo-fonte salva pelo agente como material de auditoria do próprio harness de eval — contém o cabeçalho e os corpos de `luhnValido`/`cartaoAceito`. O summary real entregue (`outputs/summary.json`) não reproduz nada disso; a nota do grader registra a dúvida explicitamente ("na dúvida sobre se isso conta como 'resposta final', reprovado"). Isso penaliza uma prática de auditoria pedida pelo próprio protocolo de eval (guardar o arquivo lido para conferência), não uma falha do agente em seguir a regra "sem reproduzir código" do artefato.
- **O artefato não deixa explícito quem escreve no `graph.json`/cache**: a linha 12 diz "seu trabalho é... o significado" e a saída (linha 18-20) é descrita como um `summary` de texto, mas em nenhum ponto o artefato afirma que o agente NÃO deve editar `graph.json`/`cache/summaries.json` diretamente — isso ficou só implícito pelo formato da saída. O run com skill acertou por inferência correta, mas a omissão é o motivo mais provável do run sem skill ter errado por decisão própria (ver §3.2). É a lacuna de maior impacto observado.
- **A regra de "determinismo de cache" (linha 27) não explica o que "estrutural" significa**: não diz que o fingerprint ignora comentários/whitespace, nem instrui o agente a confiar na mensagem do `graph.sh update` em vez de recalcular hash bruto do arquivo. O run com skill só chegou à resposta certa porque, nesse eval específico, o protocolo simulado incluía rodar o script determinístico e ler sua saída — não porque o artefato ensinasse a distinção estrutural-vs-bruto. Um agente que pulasse essa etapa de rodar o script (o artefato não instrui explicitamente a rodá-lo) poderia cair no mesmo erro do baseline.
- **Nenhum mecanismo de calibração de tamanho**: o artefato define o limite (≤280 caracteres, 1-3 frases) mas não dá exemplo nem instrui a contagem antes de finalizar — o agente precisou de 2 iterações manuais para cumprir (transcript do eval nao-especula-alem-do-codigo, passo 11). Tempo gasto que um exemplo calibrado ou uma instrução de "meça com `wc -m` antes de responder" eliminaria.

## 5. Qualidade dos casos de eval (eval_quality)

- **cache-valido-nao-resumariza**: alta qualidade — asserções objetivas via `jq`/`diff`/`cmp` contra a fixture, delta grande (0,2→1,0) e testa exatamente a regra mais sutil e mais valiosa do artefato (fingerprint estrutural vs. hash bruto). Sem ambiguidade.
- **enriquece-repositorio-de-tarifas**: alta qualidade — 6 asserções, a maioria discriminante, cobre tamanho, escopo de imports, ausência de juízo de valor e (a mais importante) integridade do `graph.json`. Boa cobertura do artefato.
- **nao-especula-alem-do-codigo**: qualidade média — 3 de 5 asserções não discriminam (§2), e a asserção 5 tem uma ambiguidade de escopo ("resposta final" vs. arquivo de apoio salvo em `outputs/`) que produziu uma reprovação questionável do run com skill (§4). O nome do eval sugere testar "não especular", mas a regra de não especular já é bem seguida por ambas as configurações — o valor real do artefato neste eval está concentrado só na asserção de tamanho.
- `run_summary` do `benchmark.json` reporta `runs_per_configuration: 3` no metadata, mas cada eval só tem `run-1` — não há repetição real do mesmo eval para medir variância intra-eval; o desvio-padrão relatado é inter-eval, não intra-eval. Isso não invalida o resultado (delta é grande e consistente), mas o rótulo do metadata é impreciso para quem for reler o benchmark isoladamente.

## 6. Melhorias concretas, priorizadas

1. **[Alto]** Adicionar uma frase explícita proibindo edição direta de `graph.json`/`.forge/graph/cache/summaries.json` — deixar textual que o agente devolve só o texto do `summary`; quem escreve no grafo é o `graph build/update`. Fecha a lacuna que causou a falha mais decisiva do baseline (§3.2, §4).
2. **[Alto]** Esclarecer a regra de determinismo de cache (linha 27): definir que o fingerprint é estrutural (ignora comentários/whitespace/formatação) e instruir o agente a confiar na saída do `graph.sh update`/`build` ("no structural change — zero tokens") em vez de comparar hash bruto do arquivo. Sem isso, o comportamento correto observado depende de uma etapa (rodar o script) que o artefato não pede explicitamente.
3. **[Médio]** Embutir uma calibração de tamanho — um exemplo de summary com contagem de caracteres, ou a instrução "meça com `wc -m`/equivalente antes de finalizar" — para eliminar as 2 iterações manuais observadas.
4. **[Baixo]** Revisar a asserção 5 do eval `nao-especula-alem-do-codigo` para restringir seu escopo à resposta/summary final entregue ao usuário, excluindo cópias de apoio/auditoria salvas em `outputs/` pelo próprio protocolo de eval — evita o falso negativo descrito em §4.
5. **[Baixo]** Fundir ou aparar as 3 asserções não discriminantes do eval `nao-especula-alem-do-codigo` (não afirmar capacidades falsas / mencionar fatos corretos / sem juízo de valor) — mantê-las como guarda-chuva contra regressão é aceitável, mas não deveriam contar como evidência de valor do artefato ao interpretar o delta desse eval isoladamente.
