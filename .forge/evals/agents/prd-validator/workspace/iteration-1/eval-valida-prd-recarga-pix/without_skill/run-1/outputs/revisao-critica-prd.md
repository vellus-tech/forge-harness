# Revisão crítica — PRD "Recarga do Cartão Via Norte pelo App" vs. Discovery (sessões 08–12/09, Carla e Rodrigo)

## 1. Inventado (não está no discovery, ou o contradiz)

- **Recarga por cartão de crédito, com parcelamento em até 3x** (PRD §1.1 e §5.1, RF ausente mas citado no escopo). O discovery registra, como decisão explícita da Carla, que "recarga com cartão de crédito ou débito fica para uma fase futura por causa do custo de adquirência, sem data definida". O PRD não só inclui a funcionalidade dentro do escopo desta fase como acrescenta uma condição de parcelamento (3x) que não existe em nenhum lugar do discovery. É uma inversão direta de uma decisão de escopo já tomada pela stakeholder.
- **Meta de NPS ≥ 70 em 3 meses** (PRD OBJ-02). Não há qualquer menção a NPS nas notas de discovery. A única meta citada por Carla é "pelo menos 60% das recargas sejam digitais (app + totem) em 6 meses depois do lançamento" — métrica e prazo diferentes, e essa meta real não aparece em lugar nenhum do PRD.
- **Detalhamento técnico de implementação em RF-02**: nome do tópico Kafka (`recarga.eventos`), 12 partições, retenção de 7 dias, nome do evento (`RecargaConfirmada`), tabela PostgreSQL `recargas` com colunas específicas (`id uuid`, `cartao_id`, `valor_centavos`, `status`, `txid`). Nada disso foi discutido no discovery — é arquitetura de solução inventada e colocada num requisito funcional de PRD, quando deveria (se existisse) estar num TRD/design técnico, não em documento de produto.

## 2. Fora de lugar

- **RF-02 mistura requisito de produto com design de sistema.** Mesmo que os dados de latência (até 30 min) estejam corretos e rastreáveis ao discovery, a camada de implementação (Kafka, schema de banco) não pertence a um PRD — é decisão de FRD/TRD e ainda nem foi validada com engenharia.
- **Persona P-02 "Operador de guichê"** aparece como persona do produto, mas a funcionalidade descrita é 100% self-service pelo app — nenhum requisito do PRD toca o fluxo do guichê ou do operador. Rodrigo, no discovery, é fonte de dado (mediu a fila), não um usuário da funcionalidade sendo especificada. Incluir essa persona sem nenhum RF associado a ela é um elemento desconectado do escopo.
- **OBJ-01 com título não preenchido** ("[Nome do Objetivo]") — indica que a seção destinada à meta principal (que deveria ser exatamente a meta de 60% em 6 meses da Carla) ficou como placeholder e não foi de fato escrita.

## 3. Faltando (presente no discovery, ausente do PRD)

- **Meta de negócio real da Carla** — "60% das recargas digitais (app + totem) em 6 meses" — não consta no PRD; foi substituída por uma meta de NPS sem lastro.
- **PSP do Pix ainda indefinido.** O discovery registra isso como ponto em aberto explícito ("Carla vai trazer na próxima reunião"). O PRD tem uma seção de lacunas (§9.3) mas só cita o valor mínimo/máximo de recarga — a indefinição do PSP, que é um bloqueador maior (afeta RF-01 inteiro), não está listada como lacuna nem como risco.
- **Escopo do totem de autoatendimento.** A meta da Carla é sobre "app + totem", mas o PRD só trata do app — isso pode ser intencional (fase 1 = só app), mas o documento não deixa essa decisão explícita nem a relaciona com a meta agregada, criando ambiguidade sobre como a meta de 60% será medida se o totem não faz parte deste PRD.
- **Escopo "venda de novos cartões pelo app"** está corretamente listado como fora de escopo (§5.2) — este item está OK e não é achado.

## 4. Inconsistência de escopo do histórico

- Discovery pede "histórico das recargas feitas por Pix" (histórico específico de Pix). PRD RF-03 generaliza para "recargas realizadas" sem qualificar o meio de pagamento — como o PRD também inclui (indevidamente) cartão de crédito, o requisito de histórico fica ambíguo sobre se cobre os dois meios ou só Pix.

## 5. Observação estrutural (não é achado de conteúdo, é sinal de possível corte)

- Numeração de seções tem saltos (1.1 → 1.4, 2.2 sozinha, sem 1.2/1.3/2.1, sem seções 6 e 8) sugerindo que partes do template podem ter sido omitidas silenciosamente. Vale confirmar com quem gerou o PRD se essas seções existem em algum lugar e foram cortadas, ou se o template já é esse.

## Resumo para decisão

Antes de seguir para o FRD, os pontos que bloqueiam avanço são: (1) remover ou re-escopar cartão de crédito/parcelamento, que contraria decisão já tomada pela Carla; (2) substituir a meta de NPS inventada pela meta real de 60% digital em 6 meses e preencher OBJ-01; (3) mover o detalhamento de Kafka/Postgres para fora do PRD; (4) registrar a indefinição do PSP como lacuna/risco explícito; (5) decidir e documentar se o totem entra nesta fase, dado que a meta agregada da Carla inclui totem.
