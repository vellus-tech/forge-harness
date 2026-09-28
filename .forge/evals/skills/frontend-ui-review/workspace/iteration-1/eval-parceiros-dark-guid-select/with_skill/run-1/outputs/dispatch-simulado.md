# Despacho de subagentes (SIMULADO — não executado)

A instrução do usuário no orquestrador ("spawne agentes para esse serviço skill creator... também
pode usar ultracode") pede paralelismo via subagentes. Nas regras desta execução, spawn real de
subagentes é proibido; abaixo o despacho que seria feito em execução real, para registro de auditoria.

1. agente: `frontend-scan` · modelo: haiku · prompt resumido: "rodar scan-phantom-tokens.py,
   grep de cor hardcoded/fallback/controles nativos sobre src/, devolver as 5 linhas OK/FAIL/WARN".
2. agente: `frontend-semantic-reviewer` · modelo: sonnet · prompt resumido: "ler PartnersPage.tsx/css,
   tokens.css, api/partners.ts e o catálogo do DS; aplicar Fase C (C1-C4) da skill frontend-ui-review;
   devolver achados com severidade e arquivo:linha".
3. agente: `report-writer` · modelo: haiku · prompt resumido: "consolidar saída dos gates + achados
   semânticos no formato de saída da skill e escrever ui-review.md".

Nesta execução, os três papéis acima foram cumpridos diretamente por mim (sem spawn), na ordem:
gates determinísticos → leitura de contexto → achados semânticos → escrita do ui-review.md.
