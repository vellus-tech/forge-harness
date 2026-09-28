# Parecer de validação — Recarga (RCG) requirements.md v1.1.0

**Validado por:** agente de validação (execução sem skill dedicada, conhecimento geral)
**Data:** 2026-09-26
**Documento avaliado:** `docs/product/modules/recarga/requirements.md` (v1.1.0, "Aprovado para desenvolvimento")
**Documentos cruzados:** `docs/product/prd/prd.md`, `docs/product/modules/recarga/README.md`, `docs/product/glossary/domain-glossary.md`, `docs/product/adr/ADR-0001-clean-architecture.md`, `docs/product/adr/ADR-0002-dinheiro-em-centavos.md`, `docs/product/adr/ADR-0003-mensageria-outbox.md`

## Veredito

**Não está pronto para o design-writer.** O documento tem pelo menos dois problemas que não são "detalhes" — contradizem decisões arquiteturais já registradas (ADRs) e mudam comportamento observável do sistema — além de requisitos não testáveis e uma inconsistência de escopo. Corrigi-los sozinho, sem confirmação do requirements-writer/PO, arriscaria travar a intenção real por trás do requisito (por exemplo, decidir sozinho se a stack de mensageria do Req 1.3 deveria ser RabbitMQ ou se o time realmente migrou para Kafka). Por isso **não alterei o arquivo `requirements.md`** e **não mudei o status do documento** — decisão explicada abaixo. Documento não foi tocado; nenhum arquivo em `work/` foi alterado nesta validação.

## Achados bloqueantes (violam ADR ou mudam comportamento — exigem decisão do requirements-writer/PO, não são "detalhe")

1. **Stack de mensageria incompatível com ADR-0003 (Req 1.3).** O requisito manda publicar o evento no tópico Kafka `recarga.criada` usando a biblioteca `spring-kafka`. O ADR-0003 (aceito, 2026-06-01) define mensageria via **RabbitMQ** com outbox transacional e envelope padrão (`event_version`, `correlation_id`, `causation_id`, `tenant_id`, `idempotency_key`). `spring-kafka` também é uma biblioteca Java/Spring, incompatível com o ADR-0001, que fixa **.NET 8** para todos os módulos. Isso não é um erro de digitação corrigível — é um requisito funcional inteiro escrito para uma stack que não é a do projeto. Requisito também fere a norma de não vazar detalhe de implementação (biblioteca, nome de tópico) para dentro do requisito funcional; mesmo corrigindo a tecnologia, a referência à lib deveria sair do requisito e virar tarefa de design.
2. **Tipo de dado monetário incompatível com ADR-0002 (Req 1.3) e contraditório com o próprio documento (Req 2.2).** Req 1.3 manda gravar `vl_recarga NUMERIC(10,2)` (decimal). O ADR-0002 (aceito) proíbe `float`/`double`/`decimal` em cálculo de tarifa e saldo e exige `Money` com `long` em centavos, persistido como `BIGINT`. O próprio Req 2.2, três linhas abaixo, diz corretamente "o crédito usa o VO Money em centavos" — ou seja, o documento se contradiz sobre como representar o mesmo valor monetário dentro do mesmo fluxo (cobrança → crédito). Corrigir isso unilateralmente decide um detalhe de schema que é responsabilidade de design/arquitetura confirmar, não da validação de requisitos.

## Achados de qualidade do requisito (não bloqueiam sozinhos, mas não são simples "typo" — recomendo devolver ao requirements-writer)

3. **Critério de aceite não testável (Req 2.3).** "A tela de recarga deve ser intuitiva e o crédito deve aparecer rápido" não tem critério objetivo (o que é "intuitiva"? quanto é "rápido"?). Um critério de aceite precisa ser verificável por teste ou QA; nenhum dos dois termos é.
4. **RNF-02 sem métrica.** "O sistema deve ser performático e escalável" é o mesmo problema em nível de não-funcional: sem número (latência, throughput, TPS) não dá para o design-writer nem para QA decidir o que satisfaz o requisito. O PRD dá o exemplo de como isso deveria ser escrito (OBJ-01: "menos de 300 ms ponta a ponta").
5. **PBT-02 não é uma propriedade verificável.** "O sistema deve funcionar bem com valores de recarga" não é uma propriedade de PBT (não há invariante, não há "para todo X, vale Y"). Ela alega mapear para o Req 1.1 (faixa 500–50.000 centavos), mas não expressa a invariante de faixa — algo como "para qualquer valor fora de [500, 50000] centavos, a geração da cobrança deve ser rejeitada" seria uma propriedade real.
6. **Ator não definido usado em critério de aceite (Req 4.2).** "O Fiscal de catraca pode solicitar o estorno em nome do Passageiro" introduz um ator ("Fiscal de catraca") que não consta na tabela de Personas/Atores deste documento (Passageiro, Operador de SAC, PSP) nem no PRD. Não dá para saber se é sinônimo de "Operador de SAC", um ator do módulo Validação (VAL) vazando para Recarga, ou um ator novo esquecido na tabela de personas.
7. **Escopo não cobre o Req 5.** A seção "Escopo" lista três itens (geração de cobrança, confirmação/crédito, estorno) mas não menciona "recarga agendada recorrente", que é exatamente o Req 5 acrescentado nesta versão a pedido do comercial (2026-09-15). Ou o Req 5 é do MVP e o Escopo está desatualizado, ou o Req 5 não deveria estar nesta versão (é "Could", pode ser fase 2) — decisão de PO, não uma correção editorial minha.

## Inconsistências documentais (histórico/status desatualizados)

8. **Histórico de Versões incompleto.** A tabela pula de 1.0.0 direto para a versão atual (1.1.0) sem uma linha descrevendo o que mudou nesta versão (a entrada do Req 5). Quem lê o histórico não descobre, pela própria tabela, que esta versão adicionou a recarga agendada.
9. **README do módulo desatualizado.** `docs/product/modules/recarga/README.md` ainda mostra `requirements.md` como "Rascunho para revisão", versão 0.1.0, enquanto o documento real já está em 1.1.0 "Aprovado para desenvolvimento". Isso é sincronizável sem risco (é só reportar o status real), mas não fiz a edição porque o README não fazia parte do artefato pedido para validação e alterar dois documentos sem pedido explícito amplia o escopo da tarefa.
10. **Numeração de requisitos com lacuna.** Os requisitos funcionais pulam de Req 2 para Req 4 (não há Req 3 no documento). Pode ser um requisito removido/deferido sem nota — vale confirmar com o requirements-writer se não é um requisito "sumido" por engano.

## Cross-referência não verificável neste workspace

- O Req 1 cita "Cross-ref: Req 2 do módulo Carteira (CRT)", mas este workspace só contém o módulo `recarga` sob `docs/product/modules/` — não há `docs/product/modules/carteira/requirements.md` para confirmar se o Req 2 da Carteira realmente existe e é compatível. Não registrei isso como defeito do documento (pode ser apenas escopo do fixture), só como verificação pendente.

## Por que não corrigi e marquei "pronto para design"

O pedido original era: "se forem só detalhes, já corrige direto no arquivo e marca como pronto para design". Avaliando os 10 achados acima, pelo menos os itens 1, 2 e 7 alteram comportamento/arquitetura ou escopo do MVP — não são detalhes de redação. Escrever "Kafka" → "RabbitMQ" ou "NUMERIC(10,2)" → "BIGINT (centavos)" sozinho, sem confirmar com quem escreveu o requisito, corre o risco de eu estar "adivinhando" a intenção original (por exemplo: talvez o Req 1.3 tenha sido copiado de outro projeto por engano e a linha inteira devesse ser removida, não só a tecnologia trocada). Por isso optei por **não editar `requirements.md`** e **não avançar o status do documento** — a recomendação é devolver ao requirements-writer com esta lista antes de acionar o design-writer.

## Recomendação de próximos passos

1. Requirements-writer corrige Req 1.3 (mensageria RabbitMQ conforme ADR-0003, tipo de dado BIGINT/centavos conforme ADR-0002, remove nome de biblioteca do requisito funcional).
2. PO confirma se "Fiscal de catraca" é o mesmo que "Operador de SAC" ou se é um ator novo a incluir na tabela de Personas.
3. PO decide se Req 5 (recarga agendada) entra no escopo desta versão (e atualiza a seção Escopo) ou se sai para uma versão futura.
4. Requirements-writer reescreve Req 2.3, RNF-02 e PBT-02 com critérios mensuráveis.
5. Só então acionar o design-writer.
