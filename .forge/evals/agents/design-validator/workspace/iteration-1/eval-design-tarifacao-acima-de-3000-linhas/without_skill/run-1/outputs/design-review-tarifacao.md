# Revisão de design — TRF Tarifação (docs/product/modules/tarifacao/design.md v1.0.0)

Revisão completa do documento (3.262 linhas), incluindo o Apêndice A linha a linha (400 blocos, um por linha de ônibus). Lista pronta para o comitê de arquitetura.

## Observação estrutural preliminar

O Apêndice A repete o mesmo bloco de cinco campos 400 vezes, variando apenas o número da linha e a operadora (Expresso Sul: 133, TransNorte: 133, Viação Leste: 134 — distribuição cíclica de fixture/seed, não uma regra de negócio). Tarifa base (4.40), tarifa noturna (4.90), regra de pico e janela de integração (90 min) são idênticas nas 400 entradas; o único elemento que muda por bloco é literalmente derivável do número da linha (`GET /v1/tarifas/linhas/{linha}`). Isto não é conteúdo de design — é dado de referência (a própria tabela de tarifas) colado dentro do documento técnico. Consequência prática: o apêndice não acrescenta nenhuma informação de arquitetura além da primeira entrada, infla o documento em ~15x e esconde, no meio do ruído, as lacunas reais listadas abaixo. Recomendação: substituir o apêndice por uma referência à fonte de dados (seed/migration/planilha) e manter no design apenas o contrato do endpoint e o esquema da tabela.

## Problemas de correção e conformidade (bloqueantes para aprovação)

1. **Dinheiro como `float`, contra o requisito explícito.** `TabelaTarifa.ValorTarifa` é `float` (linha 36) e a coluna `valor_tarifa` no schema é `FLOAT` (bloco "Schema / Modelo de Persistência"). REQ-01 dos requirements exige que o sistema "retorna o valor da tarifa **em centavos**". `float` introduz erro de arredondamento binário em valores monetários e contradiz diretamente o requisito aprovado. Deve ser inteiro (centavos) de ponta a ponta — modelo, schema e contrato de API (o próprio JSON de exemplo já devolve `4.4`, não centavos).

2. **Camada de Domínio referenciando infraestrutura.** `TRF.Domain` importa `Npgsql` e expõe `NpgsqlConnection Conexao` como propriedade da entidade `TabelaTarifa` (linhas 29-38). Isso viola a separação de camadas que a própria "Estrutura da Solução" declara (Domain/Application/Infrastructure/Api/Contracts) e que o projeto tem um `TRF.Architecture.Tests` dedicado para impor. Domínio não deve conhecer driver de banco.

3. **Ausência do campo de tenant no modelo de domínio, contra RNF-02 e contra o próprio apêndice.** RNF-02 exige "Tabela de tarifas segregada por operadora (`tenant_id`)", e as 400 entradas do apêndice atribuem uma operadora a cada linha — mas a entidade `TabelaTarifa` só tem `LinhaId` e `ValorTarifa`. Não há `TenantId`/`OperadoraId` no modelo nem na tabela SQL. O design contradiz seu próprio apêndice e não implementa um requisito não funcional aprovado.

4. **Integração temporal (REQ-02) sem desenho algum.** O requisito define uma regra com estado (segundo embarque em até 90 minutos é grátis, terceiro é cobrado integralmente), mas o design não modela nenhuma entidade de "embarque"/histórico, não descreve onde/como esse estado é persistido ou cacheado, nem como a janela é contabilizada por passageiro. As 400 linhas do apêndice apenas repetem "Integração temporal: sim, janela de 90 minutos" sem acrescentar mecanismo. Isso é a regra de negócio central do módulo e está ausente do design.

5. **Vigência/versionamento (REQ-03) incompleto.** O schema tem `vigencia_inicio` mas não `vigencia_fim` nem histórico de versões da tarifa; não há descrição de como uma tarifa com vigência futura convive com a vigente sem quebrar consultas em andamento, nem de controle de concorrência para o cadastro pelo gestor da operadora.

6. **RNF-01 (p95 < 20ms com cache em memória) não endereçado.** Nenhuma seção descreve estratégia de cache, chave de cache, invalidação quando a tarifa muda, ou onde o cache reside (processo/Redis/etc.). O requisito cita "cache em memória" explicitamente e o design é silencioso sobre isso.

7. **Propriedades PBT-01/PBT-02 sem testes correspondentes.** A seção "Testes" tem uma linha ("Testes unitários do cálculo") e não menciona testes de propriedade, apesar de `requirements.md` definir PBT-01 (tarifa nunca negativa) e PBT-02 (no máximo um embarque integrado grátis na janela) e do repositório ter uma regra dedicada de testing (`property-based-testing`). Sem isso, as duas invariantes de negócio mais sensíveis do módulo (valor negativo, dupla gratuidade) não têm cobertura planejada.

## Lacunas adicionais (não bloqueantes isoladamente, mas a reportar)

8. **Sem contrato de erro.** O único exemplo de resposta do endpoint é `200`; não há especificação para linha inexistente, faixa horária inválida ou tenant sem tarifa cadastrada.

9. **Sem seção de autenticação/autorização.** O endpoint expõe tarifas por tenant e o repositório tem regras específicas de JWT/PDP-PEP para APIs internas; o design não diz se o endpoint é público, autenticado, ou como o tenant é resolvido na requisição (path, claim do token, header).

10. **`TRF.Contracts` e `TRF.Architecture.Tests` citados só de nome.** A "Estrutura da Solução" lista os projetos mas não descreve o que cada um contém — relevante porque é justamente o `Architecture.Tests` que deveria estar pegando o problema #2.

11. **Sem observabilidade.** Nenhuma métrica, log estruturado ou trace é mencionado para um endpoint com SLA de latência explícito (RNF-01) — sem instrumentação não há como medir o p95 exigido.

12. **Regra de arredondamento monetário ausente.** O repositório tem uma regra de domínio própria para arredondamento (NBR 5891) e o cálculo de tarifa por faixa/integração é exatamente o tipo de operação que precisa dela; o design não a referencia.

## Itens verificados e sem problema

- A convenção de nomenclatura dos endpoints (`GET /v1/tarifas/linhas/{linha}?faixa={faixa}`) é consistente nas 400 entradas do apêndice — não há divergência de rota entre linhas.
- Não há incompatibilidade entre "faixa pico" e requisitos (nenhum requisito pede desconto/sobretaxa de pico, então "mesma tarifa base" não contradiz nada aprovado).

## Recomendação

Não aprovar nesta versão. Os itens 1-7 são conflitos diretos com requirements.md já aprovado (não são preferência de estilo) e o item estrutural do apêndice deve ser resolvido antes mesmo de facilitar a leitura dos demais pontos pelo comitê — hoje o documento de 3.262 linhas tem menos de 60 linhas de conteúdo de design real; o resto é dado de tabela.

## Adendo (retomada da revisão)

Itens adicionais identificados ao cruzar o design com as rules do repositório (`.forge/rules/`), complementando a lista acima sem substituí-la:

13. **Nomenclatura de coluna monetária fora do padrão do projeto.** `.forge/rules/conventions/database-naming.md` exige sufixo `_cents` para toda coluna monetária e proíbe `tenant_id` ausente em tabela de negócio; `valor_tarifa FLOAT` deveria ser `valor_tarifa_cents BIGINT NOT NULL`, e falta a coluna `tenant_id` (reforça o item 3).

14. **Vazamento de infraestrutura no domínio tem regra própria e explícita.** `.forge/rules/architecture/clean-architecture.md` proíbe literalmente `Domain` referenciar pacote de infraestrutura (Npgsql incluso); o item 2 acima não é só uma preferência de organização, é a violação nomeada na rule do projeto.

15. **Cabeçalho do documento incompleto frente a `document-versioning.md`.** Falta o campo padronizado "Referência pai" (o documento cita "Base:" fora do formato do template) — não bloqueia arquitetura, mas é uma não conformidade formal a corrigir antes da aprovação.

16. **Packs opt-in verificados: `authz`/`pii-pci` não estão ativos** (`forge.yaml` → `packs: []`), então a ausência de PDP/PEP explícito no design não é, neste projeto, um conflito bloqueante — só seria se o projeto tivesse adotado esse pack.
