# Rules — Índice de Diretrizes

Diretrizes obrigatórias que todo agente de IA deve seguir ao contribuir com `<project_name>`. Todo rule é um contrato do time — não uma sugestão.

## Ancoragem em ADR (`based_on`) — guardrail G3

Uma rule que **codifica uma decisão arquitetural** deve declarar no frontmatter o ADR que a fundamenta:

```yaml
based_on: [ADR-0007]   # esta rule deriva desta decisão aceita
```

`bash .forge/scripts/validate-rules.sh` (e o `validate-harness`/`doctor`) flagra **drift**: rule cujo `based_on` aponta para um ADR inexistente no baseline ou cujo status não é `accepted`. Isso impede o cenário do incidente do piloto — uma rule que dizia seguir um ADR mas codificava a decisão oposta. Rules sem `based_on` (ou `based_on: []`) são convenções não atreladas a uma decisão específica — válidas, apenas não verificadas contra ADR. O mecanismo é **opt-in por projeto**: o template não traz ADRs (são decisões do projeto, criadas por `/forge:adr`), então as rules do template usam `based_on: []`. Precedência quando rule e ADR divergem: o ADR vence (FORGE.md §2.1; `conventions/conflict-handling.md`).

## Como Usar

Antes de qualquer modificação, leia os rules das categorias aplicáveis à sua tarefa:

1. `conventions/` — leia sempre, independente do tipo de mudança
2. `architecture/` — leia para mudanças em código backend
3. `domain/` — leia para qualquer código que toca valores monetários ou auditoria
4. `testing/` — leia antes de escrever qualquer teste

## Catálogo

### `conventions/` (9 arquivos)

| Arquivo | Descrição | Prioridade |
|---|---|---|
| [language-policy.md](./conventions/language-policy.md) | Idioma de código vs. documentação | Alta |
| [naming.md](./conventions/naming.md) | Convenções de nomenclatura por tipo de artefato | Alta |
| [conventional-commits.md](./conventions/conventional-commits.md) | Padrão de mensagens de commit + scopes | Alta |
| [lsp-impact-analysis.md](./conventions/lsp-impact-analysis.md) | Análise de impacto antes de editar (LSP/grep + diagnóstico por stack) | Alta |
| [git-worktree.md](./conventions/git-worktree.md) | Workflow com git worktree | Média |
| [database-naming.md](./conventions/database-naming.md) | Nomenclatura de tabelas/colunas | Alta |
| [docker-naming.md](./conventions/docker-naming.md) | Nomenclatura de imagens Docker | Média |
| [document-versioning.md](./conventions/document-versioning.md) | Versionamento SemVer de documentos vivos | Média |
| [no-summary-files.md](./conventions/no-summary-files.md) | Proibição de arquivos de resumo | Baixa |

### `architecture/` (12 arquivos)

| Arquivo | Descrição | Prioridade |
|---|---|---|
| [clean-architecture.md](./architecture/clean-architecture.md) | Camadas, dependências, anti-patterns | Alta |
| [ddd.md](./architecture/ddd.md) | Entidades, value objects, agregados, eventos | Alta |
| [api-and-contracts.md](./architecture/api-and-contracts.md) | Contract-first, versioning, error envelope | Alta |
| [observability.md](./architecture/observability.md) | OTel, logs, métricas, traces | Alta |
| [security-and-secrets.md](./architecture/security-and-secrets.md) | Gerenciamento de secrets | Alta |
| [security-and-compliance.md](./architecture/security-and-compliance.md) | LGPD, PCI DSS, vulnerabilidades | Alta |
| [jwt-authentication.md](./architecture/jwt-authentication.md) | JWT como mecanismo de auth | Média |
| [jwt-permissions.md](./architecture/jwt-permissions.md) | Modelo de permissões em JWT | Média |
| [mtls-internal-services.md](./architecture/mtls-internal-services.md) | mTLS entre serviços internos | Média |
| [internal-grpc-communication.md](./architecture/internal-grpc-communication.md) | gRPC por padrão na comunicação síncrona interna | Média |
| [docker-image-security.md](./architecture/docker-image-security.md) | Hardening de imagens | Alta |
| [docker-multi-arch.md](./architecture/docker-multi-arch.md) | Multi-arch (amd64 + arm64/Graviton) | Média |

### `domain/` (3 arquivos)

| Arquivo | Descrição | Prioridade |
|---|---|---|
| [money-as-cents.md](./domain/money-as-cents.md) | Money sempre como inteiro em centavos | Alta |
| [nbr-5891-rounding.md](./domain/nbr-5891-rounding.md) | Arredondamento NBR 5891 ToEven | Alta |
| [audit-immutability.md](./domain/audit-immutability.md) | Append-only em audit logs | Alta |

### `frontend/` (1 arquivo)

| Arquivo | Descrição | Prioridade |
|---|---|---|
| [design-system.md](./frontend/design-system.md) | Tokens, componentes, Storybook, a11y, naming e anti-patterns do design system <project_display> (white-label parametrizável) | Alta |

### `testing/` (2 arquivos)

| Arquivo | Descrição | Prioridade |
|---|---|---|
| [tdd.md](./testing/tdd.md) | Ciclo Red-Green-Refactor | Alta |
| [quality-gates.md](./testing/quality-gates.md) | Gates de qualidade e cobertura | Alta |

## Como Adicionar um Novo Rule

1. Escolha a categoria correta ou crie uma nova
2. Crie o arquivo seguindo o front-matter padrão (`title`, `applies_to`, `priority`, `last_reviewed`)
3. Atualize este índice
4. Referencie no `AGENTS.md` se for de alta prioridade
5. Considere adicionar hook em `.forge/hooks/` para validação automática
