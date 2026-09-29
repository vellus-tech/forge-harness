# DDD Segmentation — Tarifa Viva

Status: Aprovado pelo comitê de arquitetura em 2026-09-10.

## 1. Subdomínios

| Subdomínio | Tipo |
|---|---|
| Validação de Embarque | Core Domain |
| Recarga | Supporting Subdomain |
| Tarifação | Core Domain |
| Liquidação com Operadoras | Supporting Subdomain |
| Cadastro de Passageiro | Generic Subdomain |

## 2. Bounded Contexts

| Bounded Context | Subdomínio | Aggregates | Linguagem ubíqua |
|---|---|---|---|
| Validação | Validação de Embarque | Viagem, CartaoTransporte | Embarque, Validador, Lista de Bloqueio |
| Recarga | Recarga | PedidoRecarga | Recarga, Token de Cartão, Estorno |
| Tarifação | Tarifação | TabelaTarifaria | Tarifa Inteira, Meia Estudantil, Integração |
| Liquidação | Liquidação com Operadoras | LoteLiquidacao | Lote, Repasse, Operadora |
| Cadastro | Cadastro de Passageiro | Passageiro | Passageiro, Gratuidade, Comprovante |

## 3. Eventos de Domínio

| Evento | Publicado por | Consumido por |
|---|---|---|
| EmbarqueValidado | Validação | Liquidação |
| RecargaConfirmada | Recarga | Validação |
| RecargaEstornada | Recarga | Validação |
| LoteLiquidacaoFechado | Liquidação | (externo: operadoras via arquivo) |
| PassageiroElegivelAtualizado | Cadastro | Tarifação, Validação |

## 4. Solution Module Map

| Módulo | Tipo | Bounded Context | Observação |
|---|---|---|---|
| validacao-embarque-api | Microservice | Validação | Recebe validações dos validadores; cache de lista de bloqueio |
| recarga-api | Microservice | Recarga | Orquestra pedido de recarga; nunca recebe PAN, só token |
| tokenizacao-cartao-adapter | Adapter | Recarga | Único ponto que recebe PAN do app; tokeniza e autoriza na adquirente |
| tarifacao-lib | Shared Library | Tarifação | Regras de cálculo de tarifa embarcadas na validacao-embarque-api; sem deploy próprio |
| liquidacao-operadoras-worker | CronJob | Liquidação | Fecha lote diário e gera arquivo CNAB por operadora |
| cadastro-passageiro-api | Microservice | Cadastro | Dono dos dados pessoais do passageiro |

## 5. Candidate Deployables

| Deployable | Módulos |
|---|---|
| validacao-embarque-api | validacao-embarque-api + tarifacao-lib |
| recarga-api | recarga-api |
| tokenizacao-cartao-adapter | tokenizacao-cartao-adapter |
| liquidacao-operadoras-worker | liquidacao-operadoras-worker |
| cadastro-passageiro-api | cadastro-passageiro-api |

## 6. Data Ownership Matrix

| Dado | Dono da escrita | Consumo por outros |
|---|---|---|
| Viagem / saldo do CartaoTransporte | Validação | Evento EmbarqueValidado |
| PedidoRecarga (token, nunca PAN) | Recarga | Evento RecargaConfirmada |
| TabelaTarifaria | Tarifação (versionada no pacote) | Package |
| LoteLiquidacao | Liquidação | Arquivo CNAB |
| Passageiro (CPF, nascimento, comprovante) | Cadastro | API GET /v1/passageiros/{id} e evento PassageiroElegivelAtualizado |

## 7. Pontos a Validar

- VAL-DDD-03 Frequência de sincronização do validador offline (a cada 5 min ou por reconexão).
