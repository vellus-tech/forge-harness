# Análise de Impacto e Navegação por Símbolos (LSP)

## Princípio

Antes de renomear símbolos, alterar assinaturas ou mudar contratos públicos, **entenda o raio de impacto**. Edição às cegas — especialmente find/replace textual — quebra em cascata: renomeia string literal, atinge símbolo homônimo de outro escopo, ou deixa call sites órfãos. O custo de mapear referências antes é baixo; o de uma quebra silenciosa em base multi-stack é alto.

Navegação semântica (LSP/IDE) é a ferramenta ideal para isso. Quando ela não está disponível, `grep` por referências + o compilador/typechecker da stack cobrem a maior parte do valor de correção.

## Quando aplicar

Obrigatório para edições de **impacto**:
- Renomear símbolo (classe, função, tipo, interface, variável/constante exportada).
- Mudar assinatura (parâmetros, tipo de retorno, genéricos, nullability).
- Alterar contrato público (interface, endpoint, evento, schema, `.proto`, DTO).
- Mover ou remover símbolo público.

Não obrigatório para edições locais triviais que não mudam a superfície pública (corpo de função sem mudar assinatura, ajuste de texto, comentário).

## Procedimento (3 passos)

1. **Localizar** — todas as referências e implementações do símbolo:
   - **Preferir LSP/IDE quando disponível**: *find all references*, *go to definition*, *find implementations*, *rename simbólico* (entende escopo, overloads e namespace; não toca strings nem homônimos não relacionados).
   - **Caso contrário**, `grep`/Grep por todas as ocorrências — atento a overloads, homônimos em escopos diferentes e usos parciais (ex.: nome em string de log, atributo, reflexão).
2. **Editar** — com o impacto já mapeado; atualizar todos os call sites na mesma mudança.
3. **Validar** — rodar o diagnóstico da stack (compilador / typechecker / linter) **antes de declarar concluído**. Em projetos com *warnings tratados como erros*, o build já é o diagnóstico autoritativo.

## Por stack

| Stack | Navegação semântica (LSP/IDE) | Diagnóstico — fallback obrigatório |
|-------|-------------------------------|------------------------------------|
| C# / .NET | Roslyn LSP · C# Dev Kit · OmniSharp | `dotnet build` (TreatWarningsAsErrors) + analisadores Roslyn |
| React / TypeScript | `typescript-language-server` (tsserver) · IDE | `tsc --noEmit` + ESLint |
| Python | Pyright / Pylance · `python-lsp-server` | `pyright` (ou `mypy`) + `ruff` |
| Kotlin / JVM | `kotlin-language-server` · IntelliJ | `./gradlew compileKotlin` + detekt / ktlint |

> Regra prática: **prefira LSP/IDE quando disponível; senão, `grep` de referências + o diagnóstico da stack acima.** Não declare "use LSP" como obrigação quando o agente/ambiente não tem a ferramenta — o fallback é o que precisa rodar de fato.

> **Pré-requisito de ambiente:** o passo de validação depende de que o **diagnóstico da stack** (coluna direita) esteja instalado — é ele, não o LSP, que valida a edição. O LSP server é desejável para navegação, mas secundário. Rode `bash .forge/scripts/doctor.sh` para verificar o que falta por stack detectada no repo (e `--install` para instalar os faltantes, opt-in). O `doctor.sh` apenas reporta por padrão e nunca instala sozinho.

## Limites do LSP — não substitui revisão cross-artefato

O LSP entende o grafo de símbolos de **uma** linguagem. Ele **não** enxerga divergências entre artefatos heterogêneos, que costumam ser a fonte dos bugs mais caros:

- Migração SQL ↔ mapeamento ORM ↔ SQL dos testes.
- `.proto` / OpenAPI / AsyncAPI ↔ stubs gerados ↔ DTOs.
- Schema / YAML / JSON ↔ código que consome.
- Strings (queries, nomes de coluna, chaves de config, valores de enum em CHECK) que não são símbolos da linguagem.

Para mudanças que cruzam artefatos, **confronte manualmente as fontes** — idealmente as três: contrato ↔ implementação ↔ teste. O LSP só fica confiável com o projeto compilando; no meio de uma edição que quebrou o build, suas referências/diagnósticos ficam degradados — nesse estado, recaia no `grep` + build.

## Anti-patterns

- Renomear via find/replace textual cego (atinge string literal e homônimos de outro escopo).
- Mudar assinatura ou contrato público sem buscar todos os call sites.
- Declarar uma mudança concluída sem rodar o compilador/typechecker da stack.
- Confiar no LSP para validar consistência entre artefatos que ele não indexa (SQL, proto, YAML).

## Verificação

- PR que renomeia ou altera símbolo público sem atualizar todos os call sites é regressão.
- Build / typecheck verde da stack é pré-requisito de conclusão de qualquer edição de impacto.
