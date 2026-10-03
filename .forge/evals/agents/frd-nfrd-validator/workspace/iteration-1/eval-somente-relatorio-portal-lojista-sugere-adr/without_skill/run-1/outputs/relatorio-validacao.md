# Relatório de Validação — FRD/NFRD do Portal do Lojista vs. PRD

**Escopo:** validação apenas (sem correção). Nenhum arquivo em `docs/product/frd-nfrd/` ou `docs/product/prd/` foi alterado, para não conflitar com a branch paralela do Rafael.

**Documentos analisados:**
- PRD — Portal do Lojista, v1.1.0, 2026-08-28, status "Aprovado para desenvolvimento".
- FRD — Portal do Lojista, v0.2.0, 2026-09-15, status "Rascunho para revisão".
- NFRD — Portal do Lojista, v0.2.0, 2026-09-15, status "Rascunho para revisão".

## 1. Rastreabilidade geral (PRD → FRD/NFRD)

| Item do PRD | Coberto por | Observação |
|---|---|---|
| F1 (login + 2FA) | FRD-POR-01 | OK |
| F2 (consulta de vendas, PAN mascarado) | FRD-POR-02 | OK |
| F3 (exportação CSV) | FRD-POR-03 | OK |
| F4 (chargebacks) | FRD-CHB-1 | OK, mas ID foge do padrão `FRD-POR-0X` usado nos demais |
| BR-01 (só admin cria/bloqueia/remove operador) | FRD-POR-05 | Parcial — ver §2 |
| BR-02 (bloqueio após 5 tentativas) | FRD-POR-01 CA-02 | OK |
| BR-03 (senha forte e trocada periodicamente) | FRD-POR-01 | Parcial — ver §2 |
| §5 (PCI DSS, PAN não pode ser exibido/exportado completo) | FRD-POR-02, FRD-POR-03, NFRD-SEC-02 | OK |
| §5 (prazo de retenção de vendas) | NFRD-RET-01 | Incompleto — ver §3 (achado prioritário) |

Numeração: existe uma lacuna entre `FRD-POR-03` e `FRD-POR-05` (não há `FRD-POR-04`), e `FRD-CHB-1` usa um prefixo e formato de número diferentes dos demais (`CHB-1` em vez de `POR-04`, sem zero à esquerda). Não é um erro de conteúdo, mas quebra a convenção de nomenclatura do próprio documento — vale um ajuste editorial, não uma correção de requisito.

## 2. Achado — Senha (prioridade do usuário)

O PRD (BR-03) exige duas coisas: **senha forte** e **troca periódica**. O FRD (FRD-POR-01) só menciona "a senha deve ser forte"; não há critério de aceite nem menção à troca periódica (rotação). Isso é uma lacuna de cobertura funcional em relação à BR-03.

No NFRD, o item correspondente é:

> NFRD-SEC-01 | Segurança | Senhas armazenadas de forma segura. | — | Revisão de código | PRD BR-03

Dois problemas aqui:
- **Coluna "Métrica/Critério" vazia.** "Armazenadas de forma segura" não é verificável sem um critério objetivo (ex.: hashing com algoritmo resistente a força bruta como Argon2id/bcrypt, salt único por senha, sem log em texto claro). Como está, o requisito não é testável.
- **Confusão de escopo:** NFRD-SEC-01 fala de *armazenamento* de senha, mas BR-03 fala de *força* e *troca periódica* da senha — são requisitos diferentes. Falta um NFRD específico para política de senha (comprimento mínimo, complexidade, período de expiração) que rastreie explicitamente BR-03, e o NFRD-SEC-01 (armazenamento) deveria ligar a NFRD-SEC-02/PCI DSS também, já que o portal está no escopo PCI DSS 4.0.1 da adquirente (Req. 8 trata de autenticação e gestão de senha/credencial).

Não corrigi o FRD/NFRD — apenas registrando o achado para o Rafael avaliar na branch dele.

## 3. Achado — Prazo de retenção de vendas (prioridade do usuário, bloqueador conhecido)

O PRD já sinaliza a lacuna explicitamente em §5: *"Os dados de vendas devem ser retidos pelo prazo exigido pela regulação e descartados depois; o prazo ainda não foi definido pelo jurídico."*

O NFRD reflete essa indefinição:

> NFRD-RET-01 | Retenção | Dados de vendas retidos pelo prazo regulatório. | — | — | PRD §5

Aqui as colunas "Métrica/Critério" e "Método de validação" estão em branco — o que é coerente com o PRD (o jurídico não fechou o prazo), não um erro de transcrição do FRD/NFRD. Mas o documento está com status "Rascunho para revisão" e nenhuma marcação explícita de bloqueio ou dependência. Recomendação (sem executar, é decisão do time, não corrigi o documento):

- Marcar NFRD-RET-01 como item aberto/bloqueante (ex.: tag `[PENDENTE-JURÍDICO]`), para não ser aprovado por engano junto com o resto do NFRD v0.2.0.
- Como o portal está no escopo PCI DSS 4.0.1 da adquirente, o prazo de retenção e a rotina de descarte também precisam satisfazer PCI DSS Req. 3.2.1 (reter dados de titular de cartão apenas pelo tempo necessário ao negócio/legal, com processo de descarte seguro) — o requisito final do jurídico não pode ser mais permissivo do que o PCI DSS exige, mesmo que seja menos restritivo que outras normas setoriais.
- Esse é um ponto de decisão de negócio/compliance com impacto de arquitetura (job de expurgo, política de storage) — vale registrar como decisão a documentar formalmente (ADR) quando o prazo for definido pelo jurídico, para não ficar apenas numa linha de tabela do NFRD. Não abri nenhum ADR nesta execução, porque o escopo pedido foi só relatório de validação.

## 4. Outros achados (severidade menor)

- **RBAC do operador (P-02) sem critério de aceite explícito.** BR-01 diz que só o administrador cria/bloqueia/remove operadores; FRD-POR-05 descreve a ação do administrador, mas não tem um critério de aceite negativo do tipo "operador não pode criar/bloquear/remover outro operador". Recomenda-se acrescentar CA quando o Rafael revisar.
- **NFRD-PERF-01** está bem formado (métrica e método de validação claros: p95 ≤ 3s, teste de carga) — sem achados.
- **NFRD-SEC-02** está bem formado e cobre corretamente o mascaramento de PAN (BIN + últimos 4 dígitos é o máximo permitido pela PCI DSS Req. 3.4 para exibição; FRD-POR-02/03 estão consistentes com isso).
- Nenhum requisito do FRD/NFRD contradiz o PRD; as lacunas encontradas são de **detalhamento insuficiente**, não de conflito direto.

## 5. Resumo executivo

| # | Achado | Severidade | Documento | Ação sugerida (não executada) |
|---|---|---|---|---|
| 1 | NFRD-RET-01 sem métrica/critério — depende de prazo jurídico ainda não fechado | Alta (bloqueador de compliance) | NFRD | Marcar como pendência explícita; abrir ADR quando o jurídico decidir |
| 2 | FRD-POR-01 não cobre troca periódica de senha (BR-03) | Média | FRD | Adicionar critério de aceite de rotação de senha |
| 3 | NFRD-SEC-01 sem métrica/critério de armazenamento seguro de senha | Média | NFRD | Definir algoritmo de hash e política verificável |
| 4 | RBAC do operador sem CA negativo | Baixa | FRD | Adicionar CA explícito |
| 5 | Inconsistência de nomenclatura (FRD-CHB-1, lacuna POR-04) | Baixa (cosmético) | FRD | Padronizar numeração |

Nenhuma alteração foi feita em `frd.md` ou `nfrd.md` — este relatório é somente leitura, conforme solicitado, para não conflitar com a edição em andamento do Rafael.
