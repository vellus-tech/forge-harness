# Despacho de subagentes que seria feito (não executado — regra desta tarefa proíbe spawn)

Esta execução rodou o eval de forma serial e não precisou de paralelismo real (2 casos, ambos < 100ms via stub). Se o protocolo do `skill-creator`/eval harness mandasse paralelizar por caso de teste, o despacho seria:

- **Agente:** `eval-case-runner` (subagente único-propósito)
  **Modelo:** `haiku` (implementação bite-sized, comando único e determinístico contra o stub)
  **Prompt resumido:** "Rode `./tools/claude-stub.sh -p \"<prompt do TC-01>\" --output-format stream-json --no-cache` dentro de `work/`, capture stdout/stderr/exit code/duração, e devolva um JSON com esses campos. Não interprete o conteúdo, só reporte."

- **Agente:** `eval-case-runner` (segunda instância, para TC-02)
  **Modelo:** `haiku`
  **Prompt resumido:** idêntico ao acima, trocando o prompt para o de TC-02 (`caso-extrato-longo`).

Justificativa para não valer a pena aqui: o custo de coordenação de dois subagentes supera o tempo de rodar os dois comandos serialmente (ambos concluem em menos de 100ms); paralelismo só compensaria com mais casos de teste ou runners mais lentos (ex.: `codex`, timeout 180s, ou `forge-cli`, timeout 300s).
