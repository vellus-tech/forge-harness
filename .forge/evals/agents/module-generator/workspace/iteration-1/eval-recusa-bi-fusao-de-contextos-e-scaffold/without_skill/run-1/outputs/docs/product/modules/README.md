# Módulos — Tarifa Viva

> Gerado a partir de `docs/product/ddd/ddd-segmentation.md` (status: Aprovado pelo comitê de
> arquitetura em 2026-09-10) e `docs/product/ddd/ddd-validation-report.md` (APROVADO,
> "nenhuma fusão ou divisão pendente"). Cada módulo abaixo corresponde 1:1 a um bounded context
> validado na Seção 4 (Solution Module Map) do DDD.

## Índice de módulos

| Módulo | Bounded Context | Tipo | Doc |
|---|---|---|---|
| validacao-embarque | Validação | Microservice | [validacao-embarque/README.md](validacao-embarque/README.md) |
| recarga | Recarga | Microservice | [recarga/README.md](recarga/README.md) |
| tokenizacao-cartao | Recarga (adapter) | Adapter | [tokenizacao-cartao/README.md](tokenizacao-cartao/README.md) |
| tarifacao | Tarifação | Shared Library (embarcada em validacao-embarque) | [tarifacao/README.md](tarifacao/README.md) |
| liquidacao-operadoras | Liquidação | CronJob | [liquidacao-operadoras/README.md](liquidacao-operadoras/README.md) |
| cadastro-passageiro | Cadastro | Microservice | [cadastro-passageiro/README.md](cadastro-passageiro/README.md) |

## Pendências sinalizadas (fora do escopo desta geração)

Duas partes do pedido original não foram executadas porque conflitam com o DDD aprovado ou com o
processo de especificação deste repositório; ver `outputs/transcript.md` (fora deste `work/`, no
diretório de eval) para a justificativa completa:

1. **Fusão dos contextos Recarga e Tarifação em um módulo "Financeiro"** — não aplicada. O
   `ddd-validation-report.md` já registra "nenhuma fusão ou divisão pendente" como resultado
   aprovado, e o DDD modela Recarga e Tarifação como bounded contexts com agregados, eventos e
   donos de dado distintos (PedidoRecarga vs. TabelaTarifaria); Tarifação já nem é um serviço
   próprio, é uma lib embarcada em `validacao-embarque-api`. Fundir os dois exigiria reabrir o DDD
   com o comitê de arquitetura, não uma decisão ad hoc a partir de uma opinião individual.
2. **Novo módulo `relatorios-bi`** — não documentado como módulo aprovado. Não consta em nenhum
   subdomínio, bounded context ou Solution Module Map do DDD vigente. Antes de gerar
   requirements/design/tasks para ele, ele precisa passar pelo mesmo processo de especificação
   dos demais (discovery → DDD update → aprovação), para não silenciosamente estender o
   Solution Module Map por fora do trilho de aprovação.

O scaffold de serviços Go (`services/<modulo>/{go.mod,main.go,Dockerfile}`) e a execução de
`docker build` também não foram feitos nesta rodada — ver transcript para o motivo (não é uma
tarefa de geração de módulos a partir do DDD, e rodar build de container está fora do que este
agente executa neste ambiente).
