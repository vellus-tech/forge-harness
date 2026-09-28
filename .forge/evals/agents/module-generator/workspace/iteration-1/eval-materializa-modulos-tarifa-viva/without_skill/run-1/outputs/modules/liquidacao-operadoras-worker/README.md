# liquidacao-operadoras-worker

CronJob. Bounded context: **Liquidação** (subdomínio Liquidação com Operadoras, Supporting Subdomain).

## Responsabilidade

Fecha diariamente (às 02:00) o lote de liquidação de tarifas arrecadadas e gera o arquivo de repasse (formato CNAB) por operadora de ônibus — Viação Aurora, TransVale e Expresso Sol —, entregando a liquidação em D+1 (OBJ-03 do PRD).

## Aggregates e linguagem ubíqua

- **LoteLiquidacao** — o lote diário fechado para uma operadora.
- Termos: Lote, Repasse, Operadora.

## Eventos

| Evento | Direção | Publicado/consumido |
|---|---|---|
| EmbarqueValidado | Consome | Publicado por Validação |
| LoteLiquidacaoFechado | Publica | Consumido externamente pelas operadoras, via arquivo |

## Dependências

- **Validação** (`validacao-embarque-api`) — upstream via Published Language (evento `EmbarqueValidado`); é a fonte de verdade para reconstruir cada lote.
- **Operadoras (externo)** — consomem o arquivo CNAB gerado, fora do sistema Tarifa Viva (não há API; a integração é por arquivo em bucket S3).

## Dados

| Tabela | Campos sensíveis |
|---|---|
| lotes_liquidacao | nenhum |

## Requisitos não funcionais

- FR-05 — fechamento do lote diário e geração do arquivo de repasse.
- NFR-04 — auditabilidade: todo lote deve ser reproduzível a partir dos eventos `EmbarqueValidado` recebidos, sem depender de estado mutável fora desse replay.
- NFR-05 — disponibilidade 99,5%.

## Segurança e compliance

Não processa dados de cartão de pagamento nem dados pessoais do passageiro — os eventos `EmbarqueValidado` que consome carregam apenas dados de viagem/tarifa, não CPF nem informações de pagamento. Fora do escopo PCI DSS e fora do escopo direto de LGPD. O ponto de atenção operacional é a integridade do arquivo CNAB gerado no bucket S3 (controle de acesso e trilha de auditoria de quem lê/baixa o arquivo), já que ele materializa valores financeiros a repassar às operadoras.

## Stack

Go; execução como CronJob diário; consome eventos via RabbitMQ (exchange `tarifa-viva.eventos`); PostgreSQL como persistência; gera arquivo CNAB em bucket S3.
