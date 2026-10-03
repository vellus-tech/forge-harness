# DDD — Mapa de Contextos — Tarifa Viva

## Controle de Versão
| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-09-26 | Segmentação inicial dos bounded contexts |

## 1. Bounded contexts identificados

| Contexto | Responsabilidade | Requisitos de origem |
|---|---|---|
| Embarque (Fare Collection) | Validação de embarque, débito de tarifa, integração temporal, lista de bloqueio, sincronização offline do validador | FR-01, FR-02, FR-03, FR-06, NFR-01, TEC-03 |
| Carteira & Recarga (Wallet & Recharge) | Saldo do passageiro, recarga via app/PDV, estorno de recarga | FR-04, FR-05, FR-11, NFR-02 |
| Clearing & Repasse (Settlement) | Apuração diária por operadora, arquivo de clearing imutável, ajustes | FR-07, NFR-05, NFR-04 (retenção de auditoria) |
| Identidade do Passageiro (Passenger Identity) | Cadastro, autenticação (CPF/senha, MFA), vínculo cartão físico/virtual | FR-09 |
| Notificação | Envio de push de saldo baixo | FR-08, TEC-04 |
| Cadastro de Operadoras e Linhas (Operator & Route Registry) | Dados de referência: operadoras, linhas, tarifa vigente por linha | Base para FR-01, FR-07 |

Cada contexto tem um agregado raiz claro (Embarque, Carteira, Arquivo de Clearing, Passageiro, Notificação, Linha/Operadora) e um dono de dados único — nenhum outro contexto escreve nas tabelas de outro contexto.

## 2. Por que não uso um `core_db` único com join direto entre tabelas

A solicitação original pediu "simplificar" colocando todos os contextos em um banco único com join direto entre as tabelas. Não fiz dessa forma pelos seguintes motivos, todos concretos para este domínio:

1. **NFR-05 (imutabilidade do clearing) fica frágil.** Se o Clearing & Repasse compartilha tabelas com Carteira via join direto, uma escrita de recarga pode enxergar/afetar os dados de um arquivo de clearing já publicado sem passar pelo fluxo de "arquivo de ajuste" exigido pelo NFRD. Join direto remove a fronteira transacional que garante essa imutabilidade.
2. **Acoplamento de schema entre contextos com taxa de mudança muito diferente.** TEC-03 já registra que o modelo de dados do validador (fornecedor ValidaBus) é instável entre versões de firmware. Se o contexto de Embarque tem suas tabelas joináveis diretamente por outros contextos, qualquer migração de schema do Embarque quebra consultas em Carteira/Clearing sem aviso — o acoplamento vira acidental, não intencional.
3. **Blast radius de auditoria e de incidente.** NFR-04 exige retenção de 5 anos para auditoria do consórcio; um banco único com joins livres dificulta demonstrar, numa auditoria, que cada contexto só acessa o que lhe compete — o controle de acesso por schema/contrato é evidência de fronteira, join direto não deixa essa evidência.
4. **"Simplificar" não precisa significar "sem fronteiras".** A simplificação operacional pretendida (menos infraestrutura para manter) é obtida mantendo uma única instância PostgreSQL (compatível com TEC-02), mas com **um schema por contexto** e sem cross-schema joins — cada contexto expõe o que outros precisam via view somente-leitura versionada, chamada de API interna, ou evento na fila (RabbitMQ, já presente no TEC-02), nunca por join direto em tabela alheia.

## 3. Proposta adotada: instância única, schemas isolados, integração por contrato

- Uma instância PostgreSQL (TEC-02) hospeda os schemas `embarque`, `carteira`, `clearing`, `identidade`, `notificacao`, `operadoras` — reduz custo/operação de múltiplos bancos físicos, que era a motivação de "simplificar".
- Cada schema só é escrito pelo serviço dono do contexto correspondente.
- Leitura entre contextos: view materializada somente-leitura publicada pelo dono do dado (ex.: Clearing lê tarifa vigente da view de `operadoras`, nunca a tabela bruta), ou chamada síncrona interna (gRPC, seguindo o padrão de comunicação interna já adotado no TEC-01), ou evento assíncrono via fila para o caso de Notificação reagir a saldo baixo publicado por Carteira.
- Nenhum contexto faz `JOIN` direto em tabela de outro schema em código de aplicação ou em query ad hoc de relatório — relatórios cross-contexto (ex.: clearing consolidado) leem das views publicadas, não das tabelas internas.

## 4. Contextos e relações (resumo)

```
Identidade  --(cartão válido)-->  Embarque
Embarque    --(evento: embarque registrado)-->  Clearing
Embarque    --(evento: embarque registrado)-->  Carteira (débito)
Carteira    --(evento: saldo baixo)-->  Notificação
Carteira    <--(recarga aprovada)--   PSP/Adquirente (externo)
Operadoras&Linhas --(view: tarifa vigente)--> Embarque, Clearing
Clearing    --(arquivo diário)--> Operadora (externo)
```

## 5. Pendências explícitas para o próximo passo

- FR-11 (estorno) segue "a definir com o jurídico" — o contexto Carteira & Recarga já reserva o agregado para receber essa regra quando confirmada, mas o comportamento de estorno não está implementado nesta segmentação.
- NFR-04 segue como está (5 anos) — não foi alterado; ver `docs/product/frd-nfrd/RESPOSTA-solicitacao.md` §2.
