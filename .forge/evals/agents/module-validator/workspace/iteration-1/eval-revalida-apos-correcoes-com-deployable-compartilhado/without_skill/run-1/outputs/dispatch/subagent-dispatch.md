# Despacho de subagentes (simulado — sem spawn real)

Nesta execução without_skill eu não tinha acesso ao protocolo do skill-creator nem aos agents/skills do template
(removidos deste worktree por design do fixture). Trabalhando só com conhecimento próprio, eu não identifiquei
necessidade de subagente: a tarefa (revalidar 4 módulos + relatório + parecer sobre tarifacao) coube inteira numa
leitura direta dos artefatos (READMEs de módulo, ADR-0002, TRD, ddd-segmentation.md) e na redação do relatório.
Se fosse delegar, o único candidato seria um segundo agente para revisão crítica adversarial do parecer final antes
de entregar — não despachado por instrução explícita do harness (não spawnar).
