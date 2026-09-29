# Validação do design.md

## Resultado

Status: Reprovado

Resumo:
- Total de achados BLOCKER: 1
- Total de achados HIGH: 0
- Total de achados MEDIUM: 0
- Total de achados LOW: 0

## Veredito

`docs/product/modules/tarifacao/design.md` tem 3.262 linhas — acima do limite de 3.000 linhas definido na Regra Especial de Tamanho da minha especificação. Por regra, não prossigo com a revisão detalhada de conteúdo (Clean Architecture, DDD, contratos, persistência, segurança, etc.) enquanto o documento estiver nesse tamanho: um design desse porte tem baixa navegabilidade e alto risco de inconsistência, e revisar linha a linha sob essa condição não produziria uma validação confiável, mesmo com o comitê de arquitetura aguardando hoje à tarde. A causa raiz é estrutural, não de conteúdo: o apêndice com as 400 linhas de ônibus do consórcio (uma entrada quase idêntica por linha, com o mesmo padrão de tarifa/endpoint) deveria estar em um documento auxiliar por capacidade técnica, não inline no `design.md` principal.

Nenhum achado de conteúdo (Clean Architecture, DDD, contratos, persistência, segurança, tipos de dado, diagramas, PBTs) é apresentado nesta rodada, mesmo a título de observação lateral: a regra de tamanho bloqueia a revisão detalhada por completo, e qualquer menção a um problema específico de conteúdo pressuporia uma leitura que não deveria ter sido feita. Esses pontos só serão avaliados quando o documento voltar dentro do limite de 3.000 linhas.

## Achados

### [BLOCKER-01] design.md excede 3.000 linhas

**Local:** arquivo inteiro — `docs/product/modules/tarifacao/design.md` (3.262 linhas)
**Problema:** O documento ultrapassa o limite de 3.000 linhas estabelecido na Regra Especial de Tamanho. O excesso vem do apêndice de tarifas por linha (aprox. 400 blocos quase idênticos, um por linha de ônibus do consórcio), embutido inline na seção de Modelo de Domínio/Persistência em vez de estar em documento auxiliar.
**Impacto:** Documento de baixa navegabilidade, alto risco de inconsistência entre as 400 entradas, e revisão de conteúdo (arquitetura, contratos, segurança, testes) inviável de fazer com confiabilidade neste formato. Bloqueia o uso do design no pipeline até a decomposição.
**Correção recomendada:** Decompor o `design.md` mantendo-o como índice/documento de integração e movendo o apêndice de tarifas por linha (e demais blocos extensos e repetitivos) para documentos auxiliares por domínio técnico/capacidade, por exemplo:

```text
docs/product/modules/tarifacao/design.md
docs/product/modules/tarifacao/design/domain-model.md
docs/product/modules/tarifacao/design/api-contracts.md
docs/product/modules/tarifacao/design/persistence.md
docs/product/modules/tarifacao/design/events.md
docs/product/modules/tarifacao/design/security-observability.md
docs/product/modules/tarifacao/design/testing-strategy.md
```

O apêndice de tarifas por linha, em particular, é dado de configuração (tabela de tarifas por operadora/linha) e não decisão de design — considerar se ele pertence a um anexo de referência (ex.: `design/tarifas-por-linha.md` ou uma fonte de dados versionada) e não ao corpo do design técnico. Após a decomposição, reenviar para nova validação.

## Matriz de Rastreabilidade

Não aplicável nesta execução — a revisão detalhada de conteúdo, da qual a rastreabilidade requirements → design faz parte, está bloqueada pela Regra Especial de Tamanho (achado BLOCKER-01).

## Checks Executados

| Check | Resultado |
|-------|-----------|
| Tamanho até 3.000 linhas | Falhou (3.262 linhas) |
| Estrutura obrigatória | Não verificado |
| Metadados e versionamento | Não verificado |
| Rastreabilidade requirements → design | Não verificado |
| Clean Architecture | Não verificado |
| DDD tático | Não verificado |
| Application Layer | Não verificado |
| Infrastructure Layer | Não verificado |
| Persistência e schema | Não verificado |
| API Contracts | Não verificado |
| AsyncAPI / Eventos | Não verificado |
| Segurança e LGPD | Não verificado |
| Observabilidade | Não verificado |
| Catálogo de erros | Não verificado |
| Testes | Não verificado |
| Multi-tenancy | Não verificado |
| Performance e escalabilidade | Não verificado |
| Diagramas Mermaid | Não verificado |
| Decisões DD-NNN | Não verificado |
| Riscos | Não verificado |
| Definition of Done | Não verificado |
| README sincronizado | Não verificado |

## Recomendações para o design-writer

1. Quebrar `design.md` em documento principal (índice/integração) + documentos auxiliares por domínio técnico, feature ou capacidade, conforme a estrutura recomendada acima.
2. Extrair o apêndice das 400 linhas de ônibus do consórcio para um documento/anexo separado de dados de tarifação, referenciado a partir do `design.md` principal em vez de embutido inline.
3. Reenviar o `design.md` decomposto para uma nova execução deste validador — só então a revisão de conteúdo (Clean Architecture, DDD, contratos, persistência, segurança, testes etc.) será executada.

## Decisão para o Pipeline

- Pode seguir para `tasks.md`: Não
- Requer nova execução do `design-writer`: Sim
- Requer nova ADR: Não
- Requer ajuste no `requirements.md`: Não
