# 0005. Camada opt-in com dependência de execução instalada sob demanda

- **Status:** accepted
- **Data:** 2026-10-30
- **Decisores:** Milton (gates `requirements_reviewed` e `design_reviewed` do change `add-unified-knowledge-search`, delegados a revisor adversarial)
- **Emenda:** [ADR 0001](0001-graph-engine.md), no ponto "sem dependência no alvo"

## Contexto e Problema

O Forge é zero-dependency nos projetos-alvo: scripts são bash + Node >= 20 `.mjs`, sem build step e sem `node_modules` no alvo (ADR 0001, spike W40). O spike W40 descreveu uma "Opção C" — caminho nativo por padrão e uma camada WASM opcional —, mas a decisão final foi a Opção B pura, e até este change nenhum script do harness carregava pacote npm em tempo de execução.

O change `add-unified-knowledge-search` trouxe uma decisão do dono que não cabe em zero-dependency puro: a busca sobre o conhecimento acumulado precisa de memória semântica com re-rank (embeddings densos e cross-encoder), implementada e não apenas prevista. Executar esses modelos com qualidade aceitável num corpus pt-BR exige um runtime de inferência (medido: BERT em JS puro custaria minutos por consulta; embeddings estáticos em JS puro pioram a fusão — `add-unified-knowledge-search/evidence/semantic-feasibility.md`).

## Drivers da Decisão

- O default não pode mudar: quem não pede nada continua sem dependência alguma.
- Dado do consumidor não sai da máquina por padrão (repositórios em escopo regulado, PCI DSS).
- Nada de binário nativo nem `node-gyp`: o que o consumidor instala tem de ser auditável e portátil.
- O que entra no projeto tem de ser fixado e conferível, não "a versão mais recente".

## Opções Consideradas

1. **Manter zero-dependency puro e não implementar a camada semântica** — viola a decisão do dono.
2. **Dependência no `package.json` do projeto-alvo** — viola o default zero-dep e põe ~400 MB em todo projeto.
3. **Provedor cloud de embeddings** — sem download, mas texto integral sai da máquina.
4. **Camada opt-in instalada sob demanda, fora do `package.json` do consumidor, com pins na maquinaria.**

## Decisão

**Opção 4.** Uma dependência de execução só entra no projeto-alvo por um comando explícito do consumidor (no caso, `kb.sh semantic install`), e então:

- é instalada num diretório derivado e ignorado pelo git (`.forge/kb/semantic/`), nunca no `package.json` do projeto;
- versões e `integrity` (sha512) vêm de um lockfile versionado na maquinaria do harness (`scripts/lib/kb-pins/`), aplicado com `npm ci --ignore-scripts`; pesos de modelo vêm de URL fixada por revisão (commit) e são conferidos por sha256 e tamanho no download e a cada carga;
- nenhum binário nativo é aceito: a instalação e cada carga varrem o diretório por extensão (`.node`, `.dylib`, `.so`, `.dll`) e por assinatura de executável (Mach-O, ELF, PE), e recusam;
- o código só é carregado de dentro desse diretório, com o caminho resolvido conferido (um pacote homônimo no `node_modules` do projeto nunca é importado);
- a ausência, a falha ou a adulteração da camada degradam para o caminho zero-dep, com o motivo dito, nunca para erro;
- o único passo com rede é o comando de instalação; o uso não acessa a rede, e isso é provado por gate com o modelo de permissões do Node (quando disponível) e com interceptador pré-carregado inclusive em Workers, com canário de controle positivo;
- provedor cloud não existe por padrão; se um dia existir, é opt-in explícito, decisão do dono.

Esta ADR emenda a ADR 0001 apenas nisto: "zero dependência no alvo" passa a valer para o **default** e para todo caminho que o consumidor não ativou explicitamente; uma camada ativada pelo consumidor nos termos acima é permitida.

## Consequências

- **Positivas:** a busca semântica com re-rank existe de fato (código do harness, testado com inferência real na suíte), sem custo para quem não a usa; o padrão fica disponível para a camada AST (tree-sitter WASM) prevista na ADR 0001 como evolução.
- **Negativas/débitos:** ~420 MB por máquina para quem ativa (runtime + modelos), e um build inicial de vetores medido em ~9 min no corpus do harness; integridade do runtime após a instalação é conferida por versão de pacote, não por hash de arquivo (o `integrity` sha512 é conferido pelo `npm ci` na instalação); as licenças declaradas dos pesos são MIT (multilingual-e5-small) e Apache-2.0 (mmarco-mMiniLMv2), mas os dois foram treinados com dados derivados do MS MARCO, cujos termos são de uso não comercial — ponto não verificado juridicamente e registrado como decisão do dono para uso comercial; o CI do harness passa a instalar `onnxruntime-web` e `@huggingface/tokenizers` como devDependencies para exercitar a inferência real.
