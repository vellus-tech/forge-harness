# Despacho de subagentes (simulado, não executado)

Regra da tarefa: "Se o artefato mandar spawnar subagentes, NÃO spawne: registre em outputs/ o
despacho que faria." A definição do agente `quality-reviewer` (`template/.forge/agents/review/quality-reviewer.md`)
não manda o agente spawnar subagentes — ele é, ele próprio, um agente de revisão único, invocado
pelo `code-evaluator` com `model: haiku`, escopo fechado em forma (nomenclatura, idioma, commits,
testes, PostgreSQL, arquivos proibidos). Não há orquestração multi-agente prevista neste artefato.

Se este caso de eval precisasse de paralelismo (por exemplo, revisar os três commits em três
sub-revisões independentes, ou rodar `dotnet format --verify-no-changes` em um subagente separado
para não poluir o contexto principal), o despacho que eu faria seria:

- Agente: `general-purpose` (ou um subagente dedicado tipo `lint-runner`)
  Modelo: `haiku` (tarefa mecânica, sem julgamento — executar `dotnet format --verify-no-changes`
  nos arquivos tocados e devolver só o diff/erro, sem overhead de análise).
  Prompt resumido: "Rode `dotnet format --verify-no-changes` em
  `services/recarga/src/Recarga.Domain/SingleTopUp.cs` e no diretório de Migrations tocado pelo
  diff feature/recarga-avulsa..develop; devolva apenas stdout/stderr e o exit code."

- Agente: `general-purpose`
  Modelo: `haiku`
  Prompt resumido: "Confirme se existe `SingleTopUpTests.cs` em qualquer branch/tag do
  repositório (não só na branch atual) via `git log --all --diff-filter=A -- '**/SingleTopUpTests.cs'`,
  para descartar teste esquecido de outro commit."

Nenhum desses dois foi de fato necessário para fechar a revisão: os grep/git log/git show diretos
já bastaram para os oito findings registrados em `revisao/quality-reviewer.json`, e a definição do
agente não obriga rodar `dotnet format` quando não há config de lint visível no fixture. Registro
o despacho aqui só para cumprir a regra da tarefa — nada foi spawnado.
