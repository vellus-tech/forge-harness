# Transcript — eval-segmenta-bilhetagem-do-zero / without_skill / run-1

## Contexto do run

Baseline without_skill: execução com conhecimento próprio do agente, sem ler `.forge/skills`, `.forge/agents`, `plugin` ou `.forge/evals` da árvore evals-100 — apenas o protocolo genérico de DDD já internalizado. Spawn de subagentes reais proibido pelas regras do run; o despacho que seria feito está registrado em `outputs/despacho-subagentes-simulado.md`.

## Passos executados, em ordem

1. `date +%s > .t0` — gravado instante inicial.
2. `mkdir -p work` e execução de `fixtures/segmenta-bilhetagem-do-zero/setup.sh work` — montou o projeto fixture "Tarifa Viva" com `forge init`, identidade do projeto (`project_name: tarifa-viva`), overlay base + overlay específico do caso, commit inicial, e removeu `.forge/skills`, `.forge/agents`, `.claude/skills`, `.claude/agents`, `plugin` para não contaminar o baseline sem o artefato.
3. Inspeção da árvore montada (`find work -maxdepth 4`) e localização dos quatro insumos em `work/docs/product/{prd,frd-nfrd,trd}`.
4. Leitura integral de `prd.md`, `frd.md`, `nfrd.md`, `trd.md`.
5. Classificação de subdomínios (core/supporting/generic) cruzando objetivos do PRD (OBJ-01..04) com os requisitos funcionais/não funcionais/técnicos — decisão registrada com justificativa em `01-subdominios.md`.
   - Decisão-chave: Embarque e Tarifação e Clearing e Repasse são core porque sustentam, respectivamente, a promessa de embarque rápido (OBJ-01/NFR-01) e a confiança financeira entre as três operadoras concorrentes (OBJ-04).
   - Frota de Validadores entrou como supporting, não core, porque sua responsabilidade é isolar a instabilidade do firmware de terceiro (TEC-03), não a regra de negócio de tarifação em si.
   - Foi identificado um subdomínio de dado de referência implícito nos documentos-fonte — Cadastro de Linhas e Operadoras — necessário tanto para Embarque (tarifa vigente por linha) quanto para Clearing (atribuição de receita por operadora dona da linha), embora nenhum FR o descreva isoladamente.
6. Derivação de bounded contexts em correspondência 1:1 com os subdomínios (`02-bounded-contexts.md`), com justificativa explícita para as duas fusões que foram descartadas (Embarque+Frota, Carteira+Recarga).
7. Construção do context map (`03-context-map.md`) com diagrama Mermaid e tabela de padrões DDD (ACL, OHS, Customer-Supplier, Published Language, Conformist) por relação, e uma seção sobre as duas fronteiras de maior risco (Frota↔Embarque por eventual consistency offline; Embarque↔Clearing por impacto financeiro direto).
8. Construção do glossário (`04-glossario.md`) — achado central: a palavra "validação" no FRD tem dois significados incompatíveis (FR-01: decisão de embarque; FR-04: autorização antifraude do adquirente) e precisa de dois termos distintos na linguagem ubíqua (`DecisaoDeEmbarque` vs. `AutorizacaoDePagamento`) para não colapsar dois conceitos de contextos diferentes num só.
9. Mapeamento de módulos (`05-modulos.md`) — um módulo por bounded context nesta primeira segmentação, com tabela de dependências de código e a regra de que nenhum módulo lê schema de outro (só contrato gRPC ou evento em fila).
10. Definição de deployables (`06-deployables.md`) — um serviço containerizado por módulo, mais o software do validador embarcado (`embarque-edge`) como deployable à parte por rodar fisicamente no ônibus sobre firmware de terceiro; seção dedicada à fronteira PCI DSS (NFR-03) restrita a `pagamentos-svc`.
11. Geração dos três diagramas C4 em Mermaid (`c4/c1-contexto.mmd`, `c4/c2-containers.mmd`, `c4/c3-componentes-embarque.mmd`) e da página HTML navegável (`c4/index.html`) com abas por nível, tema claro/escuro e Mermaid via CDN, pronta para ser aberta e mostrada ao consórcio.
12. Modelo de dados por ownership (`07-data-model-ownership.md`) — uma tabela de entidades por contexto dono, convenção de dinheiro em centavos, referências cross-context sempre por id (nunca cópia de registro) e diagrama Mermaid do mapa de referências.
13. Cópia de todo `work/docs/product/ddd/` para `outputs/docs/product/ddd/`.
14. Registro do despacho de subagentes simulado em `outputs/despacho-subagentes-simulado.md` (nenhum Agent tool foi chamado, conforme regra do run).
15. Fechamento: cálculo de `timing.json` a partir de `.t0` e checagem do tamanho de `work/` (abaixo de 20 MB, mantido).

## Decisões e trade-offs relevantes

- Optei por um subdomínio "Cadastro de Linhas e Operadoras" que não aparece nomeado em nenhum FR isolado, mas é logicamente exigido por FR-01 (tarifa da linha) e FR-07 (operadora dona da linha); alternativa descartada foi embutir esse cadastro dentro de Clearing, rejeitada porque Embarque também precisa dele em tempo real e Clearing não deveria ser upstream do core de tarifação.
- Tratei "Frota de Validadores" como o dono da tradução ACL do protocolo ValidaBus, e não deixei nenhum campo bruto do fornecedor vazar para o modelo de `Embarque`, em linha com a instabilidade de firmware citada no TRD (TEC-03).
- Marquei explicitamente a colisão semântica de "validação" no glossário porque é o tipo de ambiguidade lexical que, se não nomeada cedo, tende a virar um objeto de domínio único incorretamente compartilhado entre dois contextos.
