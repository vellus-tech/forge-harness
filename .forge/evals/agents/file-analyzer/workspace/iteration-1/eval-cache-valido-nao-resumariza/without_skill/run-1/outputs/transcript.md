# Transcript — eval-cache-valido-nao-resumariza / without_skill / run-1

1. Gravei o instante inicial em `.t0` com `date +%s`.
2. Criei `work/` e executei `setup.sh` da fixture apontando para lá.
   - Primeira tentativa: `setup.sh` recusou (`.forge já existe`) porque a pasta já continha uma execução anterior — inspecionando esse estado, o cache de summaries e `graph.json` já traziam o nó `src/integracao/calculo-integracao.ts` com fingerprint e summary reescritos citando a portaria SMT 14/2025 (ou seja, alguém/algo já tinha regenerado indevidamente o summary ali, o exato erro que este eval mede).
   - Descartei esse estado (`rm -rf work`) e reexecutei `setup.sh` do zero. Dessa vez terminou com sucesso (exit 0).
3. Li `work/src/integracao/calculo-integracao.ts` — confirma a mudança descrita pelo usuário: comentários citando a portaria SMT 14/2025 e indentação de 4 espaços.
4. Rodei `git -C work log --oneline` e `git -C work diff -- src/integracao/calculo-integracao.ts` (o próprio fixture inicializa um repo git com um commit "estado inicial com grafo construído"): o diff mostra que a edição é só comentários novos, linhas em branco, um JSDoc e reindentação de 2→4 espaços — nenhuma mudança de lógica, identificador ou assinatura.
5. Inspecionei `work/.forge/graph/graph.json` e `work/.forge/graph/cache/summaries.json`: o nó tinha fingerprint `5dda5a779b965793220640b1e46ab7266bb1404344ff5026491330b721082d56` e o summary original (sem menção à portaria) — cache seedado pela fixture, coerente com o commit inicial (antes da edição cosmética).
6. Rodei `bash work/.forge/scripts/graph.sh build` (script determinístico do próprio harness da fixture, não é o artefato/skill sob avaliação) para recalcular os fingerprints sobre o estado atual do arquivo (já com a edição cosmética aplicada, não commitada). Resultado: mesmo fingerprint (`5dda5a77...`) e mesmo summary — nada mudou para este nó. O log reportou "8 summaries stale", nenhum deles este nó.
7. Decisão: como o fingerprint estrutural não mudou (a mudança é puramente cosmética — comentários e indentação, sem alteração de lógica), o cache de summary continua válido. NÃO regenerei o summary — fazê-lo seria redundante e poluiria o cache com uma referência à portaria que hoje só existe em comentário. Registrei o raciocínio completo em `outputs/decisao.md`.
8. Copiei para `outputs/`: `graph.json.observado` (graph.json final), `summaries-observado.json` (cache de summaries final), `calculo-integracao.ts` (cópia do arquivo editado) e `git-diff-stat.txt` (estatística do diff cosmético).
9. Não spawnei nenhum subagente — a tarefa é um único nó de grafo, cabe inteiramente nesta sessão.
10. Escrevi este transcript e, em seguida, `timing.json` com o tempo total decorrido.
