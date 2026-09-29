# cadastro-passageiro-api

Microservice. Bounded context: **Cadastro** (subdomínio Cadastro de Passageiro, Generic Subdomain).

## Responsabilidade

Dono dos dados pessoais do passageiro. Cadastra o passageiro com CPF, data de nascimento e comprovante de matrícula (FR-06), usados para conceder gratuidade e meia-tarifa estudantil. Publica a elegibilidade agregada do passageiro para os demais módulos, sem expor os dados pessoais brutos fora deste serviço.

## Aggregates e linguagem ubíqua

- **Passageiro** — o cadastro do passageiro.
- Termos: Passageiro, Gratuidade, Comprovante.

## API

| Método | Endpoint | Requisito |
|---|---|---|
| GET | /v1/passageiros/{id} | FR-06 |

## Eventos

| Evento | Direção | Publicado/consumido |
|---|---|---|
| PassageiroElegivelAtualizado | Publica | Consumido por Tarifação e Validação |

## Dependências

- **Tarifação** (`tarifacao-lib`) — downstream via Customer/Supplier (context map), consumindo `PassageiroElegivelAtualizado` para aplicar meia-tarifa/gratuidade.
- **Validação** (`validacao-embarque-api`) — consumidor do mesmo evento, indiretamente (via Tarifação).

## Dados

| Tabela | Campos sensíveis |
|---|---|
| passageiros | cpf, data_nascimento, comprovante_matricula_url |

Este é o único módulo do sistema que armazena dados pessoais do passageiro. Nenhum outro serviço replica CPF, data de nascimento ou comprovante de matrícula — o acesso de terceiros a esses dados é só via `GET /v1/passageiros/{id}`, nunca via evento.

## Requisitos não funcionais

- NFR-03 (LGPD) — retenção de 5 anos após o último uso do cartão; atendimento de direitos do titular (acesso, correção, exclusão) em até 15 dias.
- NFR-05 — disponibilidade 99,5%.

## Segurança e compliance

**Recorte LGPD.** Este é o módulo de maior criticidade de privacidade do sistema, por concentrar CPF, data de nascimento e o comprovante de matrícula do passageiro. Pontos que o time de segurança/privacidade deve validar: controle de acesso ao endpoint `GET /v1/passageiros/{id}`, criptografia em repouso dos campos sensíveis, política de retenção de 5 anos com expurgo automático, processo para atender solicitações de titular em até 15 dias, e garantia de que o evento `PassageiroElegivelAtualizado` carrega apenas o resultado de elegibilidade (booleano/categoria), nunca CPF ou os demais campos pessoais em claro.

## Stack

Go; gRPC para comunicação interna; REST na superfície externa (app); PostgreSQL como persistência.
