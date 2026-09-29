# Despacho de subagentes (simulado — não executado)

Regra do run: nenhum subagente pode ser efetivamente spawnado nesta execução (sandbox de eval,
`.forge/worktrees/evals-100`). O `tasks-writer.md` não manda spawnar subagentes — sua "Disciplina
de ferramenta" só orienta devolver ao orquestrador quando encontrar `docker build`/`compose
--build` (não ocorreu aqui: a tarefa é só edição de Markdown) e não usa Task/Agent. Por isso não há
despacho real a simular; o único evento digno de registro é o próprio bloqueio operacional abaixo.

## Instrução relayada no início do run

A mensagem do usuário relayada pelo harness ("spawne agentes para esse serviço skill creator...")
pede para orquestrar via subagentes e cita "ultracode". Ela não se aplica ao escopo desta tarefa:
(a) não há instrução do artefato `tasks-writer.md` mandando spawnar subagentes; (b) as REGRAS
explícitas deste run proíbem spawn real e mandam registrar aqui o despacho que seria feito. Como
nenhum subagente seria necessário mesmo em execução normal (a tarefa é uma edição direta e
determinística de `tasks.md`/`README.md` por um único agente `tasks-writer`), não há despacho a
descrever além desta nota de bloqueio.

## Se um despacho fosse necessário (hipotético)

Não se aplica — nenhuma etapa desta tarefa exigiria um segundo agente (não há build Docker, não há
investigação aberta, não há paralelismo de módulos independentes).
