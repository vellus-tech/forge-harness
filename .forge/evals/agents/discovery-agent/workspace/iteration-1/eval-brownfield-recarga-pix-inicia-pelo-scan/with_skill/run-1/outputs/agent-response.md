Encontrei alguns artefatos úteis no workspace do recarga-api:

| Caminho | O que pode ajudar |
|---|---|
| README.md | Explica o que o serviço faz hoje: recarga do cartão de transporte da Viação Norte, só presencial (posto de venda/totem), saldo em PostgreSQL sincronizado com os validadores a cada 15 minutos. |
| docs/product/adr/0001-saldo-centralizado-no-postgres.md | ADR já aceito: o saldo oficial vive no Postgres e os validadores (offline) só recebem saldo atualizado a cada sincronização — até 15 minutos de defasagem. |
| openapi.yaml | Contrato atual da API: só tem consulta de saldo e registro de recarga feita em posto/totem. Nada de Pix ou canal remoto ainda. |
| src/Recarga.Api/ | Implementação em .NET 8 (ASP.NET Core minimal API) dos dois endpoints acima. |
| docker-compose.yml | Sobe Postgres + API localmente na porta 8080. |

Vou usar isso como contexto, mas vou validar tudo com você durante o discovery.

Já registrei essa varredura em `docs/discovery/discovery-notes.md`, incluindo dois pontos que quero validar com você mais à frente: (1) se essa iniciativa é mesmo uma "nova feature" dentro do recarga-api existente, e (2) se a janela de até 15 minutos para o saldo chegar ao validador (ADR-0001) é aceitável para uma recarga feita via Pix, ou se isso é algo que a feature precisa resolver.

Vamos começar pelo discovery de verdade. Primeira pergunta:

**Qual problema essa feature resolve? Me explica como se estivesse contando para um amigo.**
