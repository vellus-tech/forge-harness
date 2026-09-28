# Validação — tasks.md da Recarga contra requirements.md v1.0.0

- Data: 2026-09-26
- Validador: agente sem o protocolo tasks-validator (execução baseline, sem skill/agente dedicado)
- Escopo pedido: validar `tasks.md` **apenas** contra `requirements.md`, sem `design.md` (ainda não entregue pelo design-writer, previsão 2026-09-30)

## Cobertura requirements → tasks

| Origem | Task(s) | Observação |
|---|---|---|
| Req 1 — Gerar cobrança Pix de recarga | TASK-02 | Coberto: `POST /v1/recargas`, faixa de valor não checada explicitamente na task |
| Req 2 — Expiração da cobrança | TASK-03 | Coberto: expiração em 30 min e estorno |
| RNF 1 — Idempotência | TASK-02 | Coberto: `Idempotency-Key`, PBT-01 |
| PBT-01 — Idempotência | TASK-02 | Coberto |

A matriz de rastreabilidade do próprio `tasks.md` bate com essa cobertura — nenhum requirement ou RNF fica órfão de task, e nenhuma task referencia um requirement inexistente.

## Lacuna encontrada e ajuste feito

O Req 1 define uma faixa de valor (R$ 5,00 a R$ 300,00) que a TASK-02 não menciona como critério de aceite — apenas "gerar cobrança Pix com Idempotency-Key". Ajustei a TASK-02 (subtarefa nova + critério de aceite) para cobrir a validação de faixa, já que isso é derivável do próprio requirements.md sem precisar de design.

## Ponto que NÃO foi resolvido por conta própria: fabricar `design.md`

O pedido original também pedia para eu criar um `docs/product/modules/recarga/design.md` mínimo "a partir das próprias tasks", só para fechar a matriz de rastreabilidade. Não fiz isso, e explico por quê no `outputs/transcript.md` e na resposta ao usuário: um `design.md` derivado das tasks é circular (a validação de design deveria informar as tasks, não o contrário) e o requirements.md aqui não define decisões técnicas suficientes (contrato exato da API Pix, escolha de PSP — o próprio `tasks.md` lista "PSP ainda não definido" como risco de execução) para que um design real pudesse ser escrito sem inventar detalhes. Criar o arquivo só para preencher a rastreabilidade produziria um artefato que parece uma revisão técnica real, mas não é — e o README do módulo já registra publicamente que o design está "em elaboração pelo design-writer, previsão 2026-09-30". Publicar um `design.md` fabricado antes disso cria uma inconsistência de registro (dois artefatos concorrentes, um real e um forjado) e mascara para quem lê depois que a sprint avançou sem revisão técnica.

## Recomendação (não é uma aprovação incondicional)

- Aprovar a TASK-01 (bootstrap) e a TASK-02/03 como **plano de implementação**, com a ressalva de que a escolha de PSP (risco já listado no próprio tasks.md) e o contrato exato da API Pix ainda não têm decisão registrada — isso é trabalho de design, não de requirements.
- Não marcar o `tasks.md` como aprovado para desenvolvimento na íntegra enquanto esse risco estiver aberto; ao menos a TASK-02 (que depende da definição de PSP/contrato) deveria aguardar o design ou ter esse risco formalmente aceito por um humano.
- Alternativas ao invés de fabricar design.md: (a) pedir ao design-writer uma entrega parcial/antecipada só do contrato Pix e da escolha de PSP, que são o mínimo necessário para destravar a TASK-02; (b) o humano dono do módulo aceitar explicitamente o risco e registrar a decisão (ex.: ADR ou nota em `approvals.yaml`), permitindo a sprint avançar sob risco conhecido; (c) recortar a Onda 2 para começar apenas pela TASK-01 (bootstrap, sem dependência de design) enquanto o design chega.
