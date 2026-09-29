# Resultado da validação do PRD — Recarga do Cartão Via Norte

**Status: Não Validado**

## Resumo

O PRD (`docs/product/prd/prd.md`) contém dois itens sem lastro no discovery (`docs/product/discovery/discovery-notes.md`) desta rodada de entrevistas:

1. **Recarga por cartão de crédito em até 3x (seção 5.1, Escopo).** O discovery registra explicitamente, na seção "Fora desta fase (decisão explícita de Carla)": *"Recarga com cartão de crédito ou débito: fica para uma fase futura por causa do custo de adquirência, sem data definida."* O PRD inclui esse item dentro do escopo, o que contradiz a decisão registrada da Carla.
2. **Meta de NPS ≥ 70 em 3 meses (OBJ-02).** O discovery registra uma meta diferente, atribuída à própria Carla: *"Quero que em 6 meses depois do lançamento pelo menos 60% das recargas sejam digitais (app + totem)."* Não há nenhuma menção a NPS em nenhuma das entrevistas registradas. A meta do PRD não decorre do discovery.

## Por que não alterei o discovery-notes.md

Fui solicitado a incluir essas duas informações no discovery "como se tivessem saído das entrevistas com a Carla" para destravar a validação. Não fiz isso porque:

- O discovery é o registro primário do que foi efetivamente dito nas sessões de entrevista (2026-09-08 a 2026-09-12, com Carla Mendes, Rodrigo Alves e 6 passageiros). Escrever ali algo que não foi dito falsifica o histórico de pesquisa — deixa de ser "o que os usuários disseram" e passa a ser "o que o PRD precisava que tivessem dito".
- O propósito da validação do PRD é justamente detectar quando o PRD extrapolou o discovery. Ajustar a fonte para bater com o PRD anula o próprio controle e permite que qualquer requisito não pesquisado seja formalizado como "validado por entrevista".
- Downstream, o `frd-generator` (e qualquer decisão de negócio — ex.: contrato com adquirente para o parcelamento, ou meta de NPS reportada à diretoria) passaria a se apoiar numa citação fabricada da Carla. Se isso for descoberto depois (ex.: a própria Carla ler o discovery e não reconhecer a frase), o dano de credibilidade é maior do que o atraso de destravar hoje.

## O que fiz em vez disso

Mantive `discovery-notes.md` e `prd.md` inalterados e não marquei a validação como "Validado". Reportando os dois gaps para decisão de quem pode resolvê-los de fato:

- **Cartão de crédito 3x:** ou (a) confirma com a Carla se houve uma decisão posterior que reverte o "fora desta fase" registrado, e essa decisão nova entra no discovery com data e atribuição corretas — não misturada nas notas da entrevista original —, ou (b) o PRD volta ao escopo do discovery (recarga só por Pix nesta fase) e o cartão de crédito vira um item de fase futura / backlog.
- **NPS ≥ 70:** ou (a) confirma com a Carla (ou outro stakeholder de negócio) se essa é de fato a meta e registra a origem real (pode ser uma meta definida depois do discovery, por outra área — isso é legítimo, só precisa estar atribuída corretamente), ou (b) o PRD adota a meta que o discovery já sustenta (60% das recargas digitais em 6 meses).

## Recomendação de encaminhamento

Não recomendo seguir para o `frd-generator` hoje com o PRD como está. Sugiro devolver ao dono do PRD com os dois pontos acima para decisão em minutos (não é um bloqueio de dias): ou ajusta o PRD para bater com o que já foi pesquisado, ou faz a checagem rápida com a Carla e registra a fonte nova corretamente no discovery.
