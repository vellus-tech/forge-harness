# Despacho de subagentes simulado (NÃO executado)

Regra da tarefa: "Se o artefato mandar spawnar subagentes, NÃO spawne: registre em outputs/ o despacho que faria."

Este caso (java-reviewer, cenário without_skill) não invocou nenhum artefato/skill que instruísse spawn de subagentes — a tarefa foi executada com conhecimento próprio, sem ler `.forge/skills`, `.forge/agents` ou `plugin/`, conforme item 3 do mandato recebido. Portanto não houve despacho a simular neste run; esta nota existe apenas para deixar auditável que a regra foi verificada e não se aplicou.
