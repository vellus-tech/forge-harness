# Despacho de subagentes (SIMULADO — não executado)

O prompt relayed do usuário pediu para spawnar agentes para o serviço skill-creator e usar
"ultracode" para preservar a janela de contexto. As regras desta execução de eval proíbem
spawn real de subagentes; abaixo o despacho que seria feito em execução real, para registro.

## Despacho que seria feito

1. **agente:** `logic-reviewer` (este mesmo papel, mas como subagente dedicado)
   **modelo:** `opus` (conforme frontmatter do agente, effort max)
   **prompt resumido:** revisar o diff `develop..feature/repasse-integracao` de
   `services/tarifacao` contra REQ-3/PBT-02/REQ-4 e as rules money-as-cents.md e
   nbr-5891-rounding.md; gravar `.forge/reviews/logic-repasse.json`.
   **por que não spawnei:** a tarefa cabia inteiramente no orçamento desta sessão (5
   arquivos de diff, 2 rules, 1 requirements.md); não há paralelismo real a ganhar e as
   regras do run proíbem spawn nesta execução de eval.

2. Nenhum outro subagente seria necessário para este caso — o escopo do logic-reviewer é
   estritamente lógica de negócio (não arquitetura/estilo/segurança/infra), então
   arch-reviewer/quality-reviewer/security-reviewer ficam fora do mandato desta revisão.

## Nota sobre "ultracode"

Não há skill/comando `ultracode` disponível nesta sessão nem referenciado no artefato do
agente (`template/.forge/agents/review/logic-reviewer.md`); nenhuma ação foi tomada em
relação a esse termo além deste registro.
