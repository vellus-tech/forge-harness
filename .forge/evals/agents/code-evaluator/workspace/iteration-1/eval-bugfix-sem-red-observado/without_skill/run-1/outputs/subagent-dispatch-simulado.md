# Despacho de subagente simulado (NÃO executado)

Regra do run: nunca spawnar subagentes; se a tarefa mandasse, registrar aqui o despacho que seria feito e
seguir executando com o conhecimento próprio da sessão. É o que ocorreu.

## Despacho que seria feito, se subagentes fossem permitidos

- **Agente:** `code-evaluator` (agente de review especializado do Forge)
- **Modelo:** `opus` (effort medium) — code-review crítico, conforme convenção de escolha de modelo do
  usuário para revisão de código de alto impacto (PR que vai ser mergeado no mesmo dia).
- **Prompt resumido:** "Avalie o PR #61 (`fix/tarifa-arredondamento-meia` → `main`) do repositório de
  bilhetagem-urbana. Diff de uma linha em `services/tarifa/tarifa/calculo.py` corrigindo arredondamento de
  meia-entrada ímpar; teste de regressão já incluído e passando. Verifique: (1) correção do código para o
  caso relatado e para os casos de borda vizinhos (par, zero, negativo); (2) se o change Forge associado
  (`fix-arredondamento-meia`) cumpriu o protocolo Red-first — evidência de Red observada e não apenas
  declarada; (3) se o `bugfix.md` está preenchido (causa raiz, comportamento que deve permanecer
  inalterado). Retorne veredito aprovado/mudanças-solicitadas com justificativa rastreável a arquivo e
  linha."
- **Por que seria delegado:** preservar a janela de contexto do orquestrador para conduzir outros casos do
  eval (100 skills/agentes em revisão, issue #176) sem acumular o diff completo e os artefatos de spec de
  cada fixture na conversa principal; o subagente devolveria só o veredito e os achados.

## O que foi feito de fato nesta sessão (sem subagente)

Toda a inspeção (diff, execução da suíte, leitura de `red-evidence.json`/`manifest.yaml`/`bugfix.md`) e a
redação do veredito em `outputs/code-evaluator-report.md` foram feitas diretamente por esta sessão, com
minha própria leitura de código — sem consultar `.forge/skills`, `.forge/agents` ou `.forge/evals` do
template, conforme exigido pelo caso `without_skill` deste eval.
