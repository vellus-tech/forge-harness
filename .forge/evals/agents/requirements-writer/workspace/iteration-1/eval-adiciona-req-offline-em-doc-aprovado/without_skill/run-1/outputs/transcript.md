# Transcript — eval-adiciona-req-offline-em-doc-aprovado (without_skill / run-1)

## Contexto

Modo without_skill: nenhum artefato de `.forge/skills`, `.forge/agents`, `plugin` ou `.forge/evals` foi lido. A tarefa foi executada apenas com conhecimento próprio de como escrever requisitos.

## Passos executados

1. Registrado `t0` (epoch em segundos) em `.t0`.
2. Criado `work/` e executado `fixtures/adiciona-req-offline-em-doc-aprovado/setup.sh work/`, que materializou um projeto Forge de exemplo (bilhetagem eletrônica) com `docs/product/modules/validacao/requirements.md` já aprovado e `docs/product/ata-2026-09-20-operadora.md`.
3. Lido `docs/product/ata-2026-09-20-operadora.md` — quatro decisões da reunião com a Operadora Rota Sul (2026-09-20) sobre o modo offline do Validador:
   - continuar validando offline ao perder conexão com a central;
   - limite de 200 Validações ou 24h (o que ocorrer primeiro), com resultado `DENIED_OFFLINE_LIMIT` ao estourar;
   - reenvio das Validações offline à central assim que a conexão voltar, sem duplicar débito em reenvio;
   - cartões em lista de restrição continuam bloqueados offline com a última lista recebida.
4. Lido `docs/product/modules/validacao/requirements.md` (v1.2.0, aprovado) para entender estrutura, numeração de Requisitos existentes (Req 1-4), lista canônica de resultados de Validação e convenção de campos (Prioridade/Origem/Módulo, Critérios de Aceite, Cross-ref).
5. Lido `docs/product/glossary/domain-glossary.md` para conferir terminologia (Validação, Validador, Cartão Transporte) e manter consistência de termos — não havia termo "modo offline" a acrescentar formalmente para esta alteração pontual.
6. Decisão de escopo: como a tarefa pede para incluir a decisão da ata "no requirements do módulo validacao" sem mexer no resto do documento, optei por:
   - bump de versão (1.2.0 → 1.3.0) e nova linha no histórico de versões, mantendo o status "Aprovado para desenvolvimento" (documento já aprovado, mudança aditiva);
   - adicionar `DENIED_OFFLINE_LIMIT` à lista canônica de resultados (seção 4), pois é um novo resultado citado nas decisões;
   - adicionar três novos requisitos funcionais dedicados ao modo offline (Req 5, 6, 7) em vez de reescrever os Req 1/3/4 existentes, preservando o texto aprovado desses requisitos e apenas referenciando-os onde a regra offline se apoia neles;
   - acrescentar a ata como referência cruzada na seção 10.
7. Editado `work/docs/product/modules/validacao/requirements.md`:
   - Req 5 — Validar embarque em modo offline (continuidade do serviço sem central, decisão 1).
   - Req 6 — Limitar Validações em modo offline (limite 200/24h → `DENIED_OFFLINE_LIMIT`, decisão 2; e bloqueio por lista de restrição com a última lista recebida, decisão 4, referenciando o Req 3 existente em vez de duplicá-lo).
   - Req 7 — Sincronizar Validações offline com a central (reenvio ao reconectar, sem débito/registro duplicado, decisão 3).
   - Nenhum outro trecho do documento (visão geral, escopo, personas, Req 1-4, RNFs, PBT, glossário local) foi alterado.
8. Copiados os entregáveis para `outputs/`.
9. Registrado `t1` e escrito `timing.json`.

## Decisões e trade-offs

- Optei por três requisitos novos e independentes em vez de um único "Req 5 — Modo offline" monolítico, para manter granularidade equivalente à do restante do documento (cada Req cobre uma capacidade testável isoladamente) e permitir rastreabilidade individual às quatro decisões da ata.
- Não movi o bloqueio por lista de restrição offline (decisão 4 da ata) para dentro do Req 3 existente, para não alterar um requisito já aprovado; em vez disso, o Req 6.3 referencia o Req 3 e formaliza a regra da "última lista recebida" como parte do comportamento offline.
- Não adicionei Property-Based Testing nem RNF novos para o modo offline por não haver decisão explícita da ata sobre performance ou invariante matemática adicional; isso ficaria a critério de uma futura revisão de design/testes, fora do escopo desta tarefa ("não precisa mexer no resto do documento").
- Não alterei o campo "Status" do cabeçalho (permanece "Aprovado para desenvolvimento") nem o processo de reaprovação formal do documento, pois a tarefa não pediu reabertura de aprovação — apenas registrou a decisão nova como incremento versionado, seguindo o padrão já usado nas versões 1.1.0 e 1.2.0 do próprio histórico.

## Subagentes

Nenhum subagente foi necessário ou despachado para esta tarefa (edição direta e local de um único arquivo de requisitos).
