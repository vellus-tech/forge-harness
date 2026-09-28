# Módulo: cadastro-passageiro

- **Bounded Context (DDD):** Cadastro
- **Subdomínio:** Cadastro de Passageiro (Generic Subdomain)
- **Tipo:** Microservice
- **Agregados:** Passageiro
- **Linguagem ubíqua:** Passageiro, Gratuidade, Comprovante

## Responsabilidade

Dono dos dados pessoais do passageiro (CPF, nascimento, comprovante de gratuidade). Expõe leitura
via API e publica atualização de elegibilidade para os consumidores internos.

## Eventos

| Evento | Direção |
|---|---|
| PassageiroElegivelAtualizado | Publica → consumido por Tarifação e Validação |

## Dados de que é dono

Passageiro (CPF, nascimento, comprovante) — exposto via `GET /v1/passageiros/{id}` e pelo evento
PassageiroElegivelAtualizado.
