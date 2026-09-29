# Módulos — Tarifa Viva

## Controle de Versão
| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-09-26 | Segmentação DDD inicial |

## 1. Critério

Um módulo é a unidade de código que implementa um bounded context; nesta primeira segmentação cada bounded context vira exatamente um módulo, porque nenhum deles é grande ou heterogêneo o bastante para justificar split interno em sub-módulos versionáveis à parte — essa decisão deve ser revisitada quando o TRD do módulo Embarque especificar melhor o motor de regras de tarifa (pode crescer o bastante para separar `tarifa-engine` de `embarque-decisao`).

## 2. Tabela módulo → bounded context → subdomínio

| Módulo | Bounded Context | Subdomínio | Tipo |
|---|---|---|---|
| `embarque` | Embarque | Embarque e Tarifação | Core |
| `clearing` | Clearing | Clearing e Repasse | Core |
| `carteira` | Carteira | Carteira do Passageiro | Supporting |
| `recarga` | Recarga | Recarga | Supporting |
| `frota-validadores` | Frota de Validadores | Frota de Validadores | Supporting |
| `cadastro-linhas` | Cadastro de Linhas e Operadoras | Cadastro de Linhas e Operadoras | Supporting |
| `identidade` | Identidade do Passageiro | Identidade do Passageiro | Generic |
| `notificacoes` | Notificações | Notificações | Generic |
| `pagamentos` | Integração com Meios de Pagamento | Integração com Meios de Pagamento | Generic |

## 3. Dependências de código entre módulos (somente leitura de contrato, nunca de tabela)

- `embarque` depende de: contrato publicado por `carteira` (projeção de saldo/bloqueio), contrato publicado por `cadastro-linhas` (tarifa vigente), eventos canônicos de `frota-validadores`.
- `clearing` depende de: eventos publicados por `embarque` (`EmbarqueOcorrido`), contrato de `cadastro-linhas` (operadora dona da linha).
- `carteira` depende de: comandos de `recarga`, propagação de bloqueio originada em `frota-validadores`/app.
- `recarga` depende de: `pagamentos` (autorização), `identidade` (sessão do passageiro).
- `notificacoes` depende de: evento `SaldoBaixo` de `carteira`.
- `frota-validadores`, `cadastro-linhas`, `identidade`, `pagamentos` não dependem de nenhum outro módulo do domínio — são folhas ou puramente adaptadoras de terceiro.

## 4. Regra de fronteira

Nenhum módulo acessa schema/tabela de outro módulo diretamente — toda comunicação cross-module é por chamada gRPC interna (contrato `.proto` versionado, dono do módulo é fonte da verdade) para leitura síncrona, ou evento em fila (RabbitMQ, TEC-02) para propagação assíncrona; essa regra segue a convenção padrão de integração interna do usuário e evita que o acoplamento físico do banco reintroduza o mesmo problema que os bounded contexts foram desenhados para evitar.
