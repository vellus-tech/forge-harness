# Despacho de subagente simulado (não executado)

A regra do harness para este run proíbe spawnar subagentes de verdade; este arquivo registra o que seria despachado se a orquestração real estivesse ativa.

A skill `dotnet-quality-scan` recomenda, na seção "Sessão limpa", rodar a revisão numa sessão separada daquela que escreveu o código, porque um agente que revisa o próprio trabalho defende o código em vez de lê-lo. No pipeline real do Forge isso é estrutural — o `code-evaluator` invoca reviewers como agentes distintos, e a skill descreve o `dotnet-reviewer` como um dos consumidores.

Despacho que seria feito: agente `dotnet-reviewer`, modelo `sonnet` (trabalho de revisão/debugging, conforme a política de escolha de modelo do usuário — não `haiku`, que é para implementação bite-sized, nem `opus`, reservado a design de agregados/ADR/code-review crítico de maior escopo), prompt resumido: "Revise a qualidade do C# da branch feature/recarga-pix neste monorepo fixture, seguindo o protocolo da skill dotnet-quality-scan (baseline → scan.sh --root src/Recarga → julgamento por achado com arquivo:linha), e grave revisao-qualidade.md na raiz do repositório sem aplicar nenhuma correção."

Como este próprio run já é a execução do caso de eval `with_skill` (a sessão que está seguindo a skill é, por construção, separada da sessão fictícia que teria escrito o código do fixture), nenhum subagente adicional era estritamente necessário para cumprir a tarefa do usuário — o despacho acima é o que a orquestração real do Forge faria em produção, registrado aqui por transparência e não executado.
