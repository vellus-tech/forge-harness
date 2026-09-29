# Despacho de subagentes simulado (não executado)

O prompt computado desta tarefa proíbe spawnar subagentes dentro desta árvore restrita e pede para registrar aqui o que seria despachado. A análise do benchmark do agente `grader` (4 passos: agregação determinística, viewer estático, leitura de grading.json/transcripts/artefato, e redação de analysis.md) é sequencial e de escopo único — cada passo depende do anterior e não há paralelismo real a explorar dentro de um único artefato avaliado, então o despacho hipotético abaixo é apenas ilustrativo do que a orquestração completa da issue #176 faria por artefato quando há muitos artefatos independentes em paralelo.

Despacho que seria feito pela orquestração pai (não pela análise deste único artefato):

- Agente: `analyzer-worker` — modelo: `haiku` — prompt resumido: "Rode aggregate_benchmark.py e generate_review.py para o artefato <nome>, leia grading.json/transcripts, escreva analysis.md no caminho <path>, sem git/tests/publish."
- Um agente desses por artefato (skill ou agent) da lista de 100, disparados em paralelo pela orquestração pai, cada um confinado ao seu próprio subdiretório de `.forge/evals/`.

Nesta execução específica, a tarefa foi resolvida diretamente por este subagente, sem fan-out adicional, por ser um único artefato com passos sequenciais.
