# tokenizacao-cartao-adapter

Adapter. Bounded context: **Recarga** (subdomínio Recarga, Supporting Subdomain).

## Responsabilidade

Único ponto de todo o sistema Tarifa Viva que recebe o PAN do cartão de crédito/débito do passageiro. Tokeniza o cartão e solicita a autorização diretamente ao gateway REST da adquirente contratada, funcionando como Anticorruption Layer entre o domínio Recarga e a API externa da adquirente. Devolve apenas o token (e os últimos 4 dígitos) para `recarga-api` — nunca o PAN.

## Aggregates e linguagem ubíqua

Não define aggregate próprio (é um adapter técnico); opera com os mesmos termos de Recarga: Token de Cartão.

## API

Não expõe API de produto listada no FRD; é consumido internamente via gRPC por `recarga-api`. A interface externa é o gateway REST da adquirente contratada (fora do domínio Tarifa Viva).

## Dependências

- **Adquirente (externo)** — gateway REST da adquirente para tokenização e autorização. Relação Anticorruption Layer (context map): este adapter isola o domínio Recarga do modelo e do protocolo da adquirente.
- **recarga-api** — chamador síncrono (gRPC interno); recebe token e últimos 4 dígitos.

## Dados

Não há tabela própria listada no data model do domínio — por desenho, o PAN não deve ser persistido pelo sistema Tarifa Viva; o dado retido do lado do domínio (`token_cartao`, `ultimos4`) fica em `pedidos_recarga`, na `recarga-api`. Se este adapter mantiver qualquer estado próprio (ex.: cache de sessão de tokenização), esse estado precisa ser tratado como dentro do CDE e revisado à parte pelo time de segurança.

## Requisitos não funcionais

- NFR-02 (PCI DSS 4.0.1) — este é o módulo de maior criticidade de compliance do sistema: é o único componente autorizado a manipular PAN e CVV. Logs deste serviço não podem conter PAN/CVV em nenhuma circunstância, inclusive em payloads de erro da adquirente.
- NFR-05 — disponibilidade 99,5%.

## Segurança e compliance

**Este módulo é o CDE (Cardholder Data Environment) do Tarifa Viva.** É o recorte central que o time de segurança deve avaliar antes do go-live: escopo de rede segmentado, controles de criptografia em trânsito e em repouso (se houver qualquer retenção temporária), gestão de chaves, logging sem dados de titular de cartão, e teste de penetração/scan de vulnerabilidade específicos para este componente conforme os requisitos de PCI DSS 4.0.1. Nenhum outro módulo do sistema deve ter acesso a PAN ou CVV em nenhum momento — a fronteira é exatamente a resposta tokenizada que este adapter devolve a `recarga-api`.

## Stack

Go; gRPC como interface interna (chamado por `recarga-api`); REST para o gateway da adquirente externa.
