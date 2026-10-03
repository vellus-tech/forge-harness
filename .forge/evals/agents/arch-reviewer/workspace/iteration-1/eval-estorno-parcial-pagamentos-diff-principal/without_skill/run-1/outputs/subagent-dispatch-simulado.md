# Despacho de subagentes (simulado — não executado)

A tarefa deste run não exigiu paralelismo real (revisão de um diff pequeno, single-pass, sem necessidade de investigação aberta em múltiplas frentes). Caso a política do caso de eval pedisse explicitamente spawn de subagentes, o despacho seria:

- agente: `arch-reviewer` (o próprio, sem sub-spawn) — não haveria subdivisão de trabalho, pois o escopo é um único módulo (`services/pagamentos`) com 7 arquivos alterados; dividir entre subagentes teria custo de coordenação maior que o ganho.

Nenhum subagente foi de fato spawnado. Este arquivo registra apenas a decisão de não spawnar e o porquê.
