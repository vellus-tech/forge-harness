# Validação de Design — Módulo VAL (Validação) — RECUSADA

Data: 2026-09-26
Solicitante: PO (via pedido de validação para liberar o tasks-writer)
Artefato avaliado: `docs/product/modules/validacao/design.md` v1.0.0

## Veredito

**Não aprovo.** Não vou validar o design contra um `requirements.md` que não existe, e não vou rascunhar esse `requirements.md` a partir do próprio `design.md` para fechar a rastreabilidade artificialmente.

## Por que recusar, e não só assinalar como pendência

1. **O arquivo citado como base não existe.** O cabeçalho do `design.md` declara `Base: docs/product/modules/validacao/requirements.md v1.0.0`, mas esse arquivo não está no repositório (o `README.md` do módulo confirma: "requirements.md em elaboração pelo PO, ainda não publicado"). Ou seja, o design já foi publicado citando uma fonte que não existe — isso por si só é motivo de bloqueio, independente do que eu faça a seguir.

2. **Derivar o requirements do design é validação circular, não validação.** Se eu escrever `requirements.md` copiando o que já está em `design.md`, qualquer verificação "design × requirements" vai passar trivialmente — porque os dois documentos teriam a mesma origem (a interpretação do design-writer sobre o PRD), e não a intenção real de negócio do PO. Isso não fecha rastreabilidade, apenas maquia a ausência dela. O ponto do requirements.md é capturar o que o PO decidiu e priorizou (critérios de aceite, casos de borda, regras de negócio explícitas) *antes* do design, para que o design possa ser auditado contra uma fonte independente. Gerar o requirements depois, a partir do artefato que deveria ser auditado, inverte a ordem de controle e não sobrevive a uma auditoria (interna ou de compliance) — o histórico mostraria que "requisito" e "design" nasceram no mesmo commit, do mesmo autor, sem input do PO.

3. **O PO explicitamente ainda não fechou o requirements.** Isso significa que decisões de negócio sobre o módulo de Validação ainda estão em aberto. Aprovar o design agora, e destravar o tasks-writer para gerar tarefas de implementação amanhã cedo, trava a equipe em decisões técnicas (schema, contratos de API, máquina de estados) antes que o PO tenha confirmado os requisitos. Se o PO fechar o requirements.md depois com uma decisão diferente (ex.: outro fluxo de erro, outro campo obrigatório), o retrabalho recai sobre design + tasks já gerados.

## O que a validação contra PRD e ADRs mostra (feita mesmo assim, para dar sinal ao PO)

Isto não substitui a validação formal contra requirements — é checagem de consistência com o que já é fonte de verdade (PRD aprovado v2.1.0 e ADRs aceitos), para o PO decidir com mais informação.

### Conformidade

- **ADR-0001 (Clean Architecture):** estrutura `VAL.Domain/Application/Infrastructure/Api/Contracts/Architecture.Tests` está correta.
- **ADR-0002 (centavos):** `Money`/`Centavos`, coluna `tarifa_centavos BIGINT`, resposta `saldo_restante_centavos` — conforme.
- **ADR-0003 (outbox/envelope):** outbox na tabela `val.outbox`, envelope com os cinco campos exigidos, DLQ declarada — conforme.
- **OBJ-01 (PRD, débito em <300ms):** design define meta de 300ms ponta a ponta e timeouts (Tarifação 50ms, Carteira 100ms) compatíveis.
- **OBJ-04 (PRD, isolamento por tenant):** `tenant_id` presente em tabela e envelope de evento.

### Gap encontrado

- **OBJ-02 (PRD, integração temporal de 90 minutos entre linhas)** não está endereçado no design. A tabela de casos de uso lista `ConsultarEmbarquesDoCartao` com origem "PRD OBJ-02", mas é descrita só como uma *query* de consulta — não há menção a regra de isenção/desconto por integração temporal, nem campo de janela de 90 minutos no schema, nem decisão de onde essa regra vive (VAL ou TRF/Tarifação). Isso é exatamente o tipo de ambiguidade que um requirements.md deveria ter resolvido antes do design (de quem é a responsabilidade da regra de integração, e o que a Validação precisa saber/fazer com ela).

## Recomendação

1. PO fecha (ou pelo menos declara por escrito, mesmo que resumido) o `requirements.md` do módulo — em particular a decisão sobre onde a regra de integração temporal (OBJ-02) é resolvida e o que a Validação precisa consultar.
2. Corrigir o cabeçalho do `design.md` para não citar uma versão de requirements que não existe.
3. Só depois disso, rodar a validação real de design × requirements × ADRs, e então liberar o tasks-writer.

Sem o passo 1, não coloco "aprovado para o tasks-writer" neste design — o risco é gerar tasks de implementação sobre uma lacuna de negócio ainda não decidida pelo PO.
