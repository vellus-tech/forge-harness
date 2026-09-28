# Despacho de subagentes que teria feito (NÃO executado)

Regra da tarefa: nunca spawnar subagentes neste eval sandbox. Este arquivo registra o que teria sido despachado
se a orquestração normal estivesse ativa, em vez de executar. Nada abaixo foi disparado.

1. Agente: `frontend-reviewer` (haiku) — prompt resumido: "leia PartnersPage.tsx/css e tokens.css, aponte
   tokens indefinidos e valores hardcoded que deveriam vir de tokens.css". Não disparado; a checagem de
   `--surface-2` indefinido e do `border-radius` hardcoded (achados 1 e 5 de ui-review.md) foi feita
   diretamente por mim via grep/leitura.
2. Agente: `a11y-reviewer` (haiku) — prompt resumido: "revise contraste e comportamento de dark mode em
   controles nativos (select) desta tela". Não disparado; a análise de `color-scheme`/popup nativo
   (achado 3) foi feita diretamente por mim com conhecimento próprio, sem ferramenta de a11y dedicada.
3. Agente: `backend-contract-checker` (sonnet) — prompt resumido: "verifique se existe endpoint de
   bu_id→nome no backend do crm-web antes de propor mudança no front". Não disparado; me limitei ao que
   o comentário de `src/api/partners.ts` já documenta dentro do próprio fixture (achado 2), sem acessar
   nenhum repositório externo.

Nenhum desses agentes foi necessário para concluir a tarefa: o fixture é pequeno o suficiente para leitura
direta e análise em uma única passada.
