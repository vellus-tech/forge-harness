# Despacho de subagentes (simulado — não executado)

Este run é o baseline "without_skill": nenhum subagente foi de fato spawnado (proibido pelas regras do harness para este run). Caso este fosse um fluxo real orquestrado, o despacho seria:

- Agente: `dotnet-reviewer` (ou revisor genérico de código .NET)
  Modelo: sonnet
  Prompt resumido: "Revise o diff de hotfix/extrato-portador contra main em <repo>, aplique correções diretas para achados de segurança (SQL injection, secrets hardcoded, exposição de PII em log, falta de autorização) e grave findings em review/dotnet-review.json + resumo em review/resumo.md."

Como o caminho já estava claro (diff pequeno, dois arquivos, achados bem delimitados) e a tarefa cabia inteiramente nesta sessão, não haveria ganho real em paralelizar — a revisão foi conduzida diretamente.
