# tarifacao-lib

Shared Library. Bounded context: **Tarifação** (subdomínio Tarifação, Core Domain). Sem deploy próprio — é embarcada em `validacao-embarque-api`.

## Responsabilidade

Calcula a tarifa aplicável a cada embarque: tarifa inteira, meia estudantil, gratuidade e integração em 60 minutos (FR-04). Mantém a tabela tarifária versionada dentro do próprio pacote.

## Aggregates e linguagem ubíqua

- **TabelaTarifaria** — a tabela de tarifas vigente, versionada.
- Termos: Tarifa Inteira, Meia Estudantil, Integração.

## API

Não expõe API HTTP/gRPC própria — é consumida como biblioteca pelo processo de `validacao-embarque-api` (Shared Kernel, conforme o context map).

## Eventos

| Evento | Direção | Publicado/consumido |
|---|---|---|
| PassageiroElegivelAtualizado | Consome | Publicado por Cadastro |

## Dependências

- **validacao-embarque-api** — é o único consumidor; a relação é Shared Kernel (context map), não chamada de rede.
- **Cadastro** (`cadastro-passageiro-api`) — via evento `PassageiroElegivelAtualizado`, para saber se o passageiro tem direito a gratuidade ou meia-tarifa estudantil.

## Dados

Não possui tabela própria no data model — a `TabelaTarifaria` é versionada dentro do pacote (release do código), não em banco de dados.

## Requisitos não funcionais

- Herda o orçamento de latência de `validacao-embarque-api` (NFR-01, p99 < 300 ms), já que roda no mesmo processo sem chamada de rede adicional.

## Segurança e compliance

Não processa dados de cartão de pagamento nem dados pessoais brutos. Recebe apenas o sinal de elegibilidade agregado (`PassageiroElegivelAtualizado`) — sem CPF, sem data de nascimento, sem comprovante de matrícula. Fora do escopo PCI DSS e fora do escopo direto de LGPD, mas deve garantir que nenhum campo pessoal seja adicionado ao payload desse evento no futuro sem revisão.

## Stack

Go; distribuída como pacote versionado, sem deploy próprio.
