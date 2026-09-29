# validacao-embarque-api

Microservice. Bounded context: **Validação** (subdomínio Validação de Embarque, Core Domain).

## Responsabilidade

Recebe a validação de embarque enviada pelos validadores instalados nos ônibus (leitura do cartão transporte ou do QR do app), debita a tarifa vigente do saldo e mantém o cache local da lista de bloqueio para operar offline. Embarca a `tarifacao-lib` como Shared Kernel para calcular a tarifa (inteira, meia estudantil, gratuidade, integração em 60 min) sem chamada de rede adicional.

## Aggregates e linguagem ubíqua

- **Viagem** — um embarque validado.
- **CartaoTransporte** — o cartão lógico do passageiro (não é cartão de pagamento; não tem PAN).
- Termos: Embarque, Validador, Lista de Bloqueio.

## API

| Método | Endpoint | Requisito |
|---|---|---|
| POST | /v1/validacoes | FR-01 |

## Eventos

| Evento | Direção | Publicado/consumido |
|---|---|---|
| EmbarqueValidado | Publica | Consumido por Liquidação |
| RecargaConfirmada | Consome | Publicado por Recarga |
| RecargaEstornada | Consome | Publicado por Recarga |
| PassageiroElegivelAtualizado | Consome | Publicado por Cadastro (via Tarifação) |

## Dependências

- **tarifacao-lib** — Shared Kernel embarcado no processo, sem deploy próprio; fornece o cálculo de tarifa.
- **Cadastro** (`cadastro-passageiro-api`) — indiretamente, via evento `PassageiroElegivelAtualizado`, para saber elegibilidade de gratuidade/meia-tarifa.
- **Recarga** (`recarga-api`) — via eventos `RecargaConfirmada`/`RecargaEstornada`, para manter o saldo do cartão transporte atualizado.

## Dados

| Tabela | Campos sensíveis |
|---|---|
| viagens | nenhum |
| cartoes_transporte | nenhum (número lógico, não é cartão de pagamento) |

Redis é usado como cache local da lista de bloqueio para permitir a validação offline.

## Requisitos não funcionais

- NFR-01 — p99 < 300 ms; opera offline até 4 h e sincroniza depois. Ponto em aberto: VAL-DDD-03 (frequência de sincronização — a cada 5 min ou por reconexão — ainda não decidida).
- NFR-05 — disponibilidade 99,95% (a mais alta do sistema, por ser o único componente com o qual o passageiro interage fisicamente no embarque).
- NFR-04 — auditabilidade: todo lote de liquidação em `liquidacao-operadoras-worker` deve ser reproduzível a partir dos eventos `EmbarqueValidado` publicados aqui.

## Segurança e compliance

Não processa dados de cartão de pagamento nem dados pessoais diretamente. Recebe apenas o resultado agregado de elegibilidade (`PassageiroElegivelAtualizado`), não CPF nem os demais campos pessoais — o time de segurança não precisa tratar este módulo como CDE nem como armazenamento de dados pessoais, mas o cache de lista de bloqueio e os logs devem ser revisados para confirmar que nenhum identificador pessoal vaza para eles.

## Stack

Go; gRPC para comunicação interna; REST na superfície externa (validadores); PostgreSQL como persistência; Redis como cache de lista de bloqueio.
