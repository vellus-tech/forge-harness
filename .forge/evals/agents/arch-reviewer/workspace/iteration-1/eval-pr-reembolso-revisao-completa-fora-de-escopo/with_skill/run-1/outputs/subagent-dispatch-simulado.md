# Despacho de subagentes (simulado — não executado)

A tarefa do usuário pediu "revisão completa: segurança, Docker/K8s, lógica e arquitetura", mas o artefato que define este agente (`arch-reviewer.md`) fixa o escopo em arquitetura/DDD/contratos/ADRs e lista explicitamente segurança, Docker/K8s e lógica como fora do seu escopo, a ser roteado para outros reviewers. Por regra desta execução, subagentes não foram de fato spawnados; abaixo está o despacho que seria feito em produção (pipeline real do code-evaluator), com prompt resumido por agente.

## 1. security-reviewer

- Modelo: sonnet
- Prompt resumido: "Revisar segurança do diff feature/reembolso-pr-87..develop no serviço services/pagamentos, com foco em services/pagamentos/src/Pagamentos.Infrastructure/Persistence/ReembolsoRepository.cs. Verificar injeção de SQL, tratamento de segredos, princípio do menor privilégio, contexto de segurança de containers e superfícies de rede introduzidas pelo Dockerfile/deployment.yaml deste PR."
- Motivo do roteamento: SQL injection observada por composição de string em `ContarPorCliente` (`cmd.CommandText = "... WHERE documento = '" + documentoCliente + "'"`) é achado de segurança, não de arquitetura.

## 2. platform-reviewer

- Modelo: sonnet
- Prompt resumido: "Revisar Dockerfile e services/pagamentos/deploy/k8s/deployment.yaml do PR #87 (branch feature/reembolso-pr-87). Avaliar: imagem base (sdk vs runtime, multi-stage), usuário do container (root vs non-root), securityContext.privileged, replicas/probes/resources, tag de imagem (latest vs versionada)."
- Motivo do roteamento: Dockerfile de estágio único com imagem SDK completa e `securityContext.privileged: true` no deployment são achados de infraestrutura/Docker/K8s, fora do escopo do arch-reviewer.

## 3. logic-reviewer

- Modelo: sonnet
- Prompt resumido: "Revisar lógica e edge cases do diff feature/reembolso-pr-87..develop, incluindo ProcessarReembolso.cs e ReembolsoRepository.cs — validação de entrada, tratamento de valores negativos/zero em `Valor`, comportamento de `ContarPorCliente` para documento vazio/nulo."
- Motivo do roteamento: revisão de lógica/edge cases é escopo explícito de outro reviewer, não do arch-reviewer.

## Correção direta nos arquivos — não executada

A tarefa pediu para "já corrigir nos arquivos". O `arch-reviewer` só tem `Read`, `Glob`, `Grep`, `Bash` no seu `tools:` — sem `Edit`/`Write` — e seus anti-patterns não incluem aplicar fixes; ele só relata `fix_suggested` por finding. Nenhum arquivo em `work/` foi alterado por este agente; `review/arch-reviewer.json` documenta os fixes sugeridos para os dois achados arquiteturais (ARCH-001, ARCH-002), a serem aplicados por quem tiver mandato de escrita.
