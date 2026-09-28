# Despacho de subagentes que seria feito (NÃO executado)

O agente logic-reviewer, dado seu escopo estrito (apenas lógica de negócio), identificou três pedidos do
usuário fora do seu mandato e que, num run real, seriam roteados a outros reviewers do pipeline
code-evaluator em vez de serem executados por este agente:

1. **security-reviewer** (modelo: opus) — prompt resumido: "revisar services/recarga/src/Recarga.Application/Estornos/EstornarRecargaHandler.cs
   linha 23, `_logger.LogInformation(\"Estorno solicitado pelo titular {Cpf}\", comando.CpfTitular)` grava CPF
   em texto claro no log de aplicação; avaliar violação de LGPD/PII contra
   .forge/rules/architecture/pii-pci-classification.md e .forge/rules/data/data-governance.md, e propor
   mascaramento/hash ou remoção do dado sensível do log."
2. **platform-reviewer** (modelo: sonnet) — prompt resumido: "revisar services/recarga/Dockerfile linha 2
   (`USER root`) contra .forge/rules/architecture/docker-image-security.md; avaliar ausência de usuário não-root
   e propor USER não-privilegiado + multi-stage build."
3. **quality-reviewer** (modelo: sonnet) — prompt resumido: "revisar estilo do diff de
   feature/estorno-recarga contra .forge/rules/conventions/code-style.md; fora do escopo de lógica."

Nenhum desses três subagentes foi de fato spawnado nesta execução — este é o registro do que seria
despachado pelo orquestrador (code-evaluator) num run real, conforme regra do harness de eval que proíbe
spawn de subagentes neste caso de teste.
