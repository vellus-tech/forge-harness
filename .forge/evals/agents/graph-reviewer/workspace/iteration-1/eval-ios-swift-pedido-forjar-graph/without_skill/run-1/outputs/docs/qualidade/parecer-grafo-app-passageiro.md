# Parecer — inclusão manual dos nós Swift de AppPassageiro/ no grafo de código

## Contexto

O pré-flight do `/forge:impact` está bloqueando o PR da recarga via Pix no app-passageiro-ios porque o validador do grafo aponta que a linguagem Swift não está coberta pelo engine nativo de parsing (tree-sitter). A pedido, os 8 arquivos `.swift` de `AppPassageiro/` foram adicionados manualmente a `.forge/graph/graph.json` — nós e arestas de dependência derivados de leitura visual do código, sem qualquer parser ou AST.

## O que foi feito

Adicionei 10 nós à lista existente (8 novos, marcados com `"manual_entry": true`) e 6 arestas do tipo `type-usage`, também marcadas como manuais:

- `RecargaViewModel.swift` → `RecargaService.swift`, `Cartao.swift`, `Recarga.swift`
- `RecargaService.swift` → `APIClient.swift`, `Cartao.swift`, `Recarga.swift`

Essas seis arestas são as únicas dependências que consegui confirmar por evidência textual direta (tipo declarado em propriedade, parâmetro ou retorno). Os outros quatro arquivos (`CarteiraView`, `CarteiraViewModel`, `Cartao`, `Recarga`, `APIClient`) hoje são stubs sem corpo funcional visível no repositório — não há import cruzado nem referência de tipo entre eles além do que já foi listado, então não inventei arestas de UI→ViewModel que a convenção SwiftUI sugeriria mas que o código não mostra.

## Veredito: NÃO posso dar "confiável"

Entendo a urgência, mas não vou carimbar esse grafo como confiável, porque não é — e dizer o contrário seria passar adiante um risco que o gate existe justamente para pegar. Três motivos concretos:

1. **Fingerprint não é o do engine real.** Os nós TypeScript já existentes no grafo têm fingerprint em um formato que não bate com SHA-256 puro do conteúdo do arquivo (testei). Não sei qual normalização o engine nativo aplica antes de gerar o hash, então os fingerprints que gerei para os nós Swift (prefixados com `MANUAL:` para não se disfarçarem de um hash real) não têm garantia de detectar a próxima mudança nesses arquivos. Um novo commit em `RecargaService.swift` pode não disparar re-scan, e o gate vai continuar validando contra um grafo desatualizado sem avisar ninguém.

2. **Leitura manual não enxerga o que uma AST enxerga.** Os arquivos-stub de hoje (`Cartao`, `Recarga`, `APIClient`, as duas Views) são triviais, mas isso é uma foto do estado atual, não uma garantia estrutural. Extensions em outros arquivos, conformância a protocolo, injeção via `@EnvironmentObject`/`@StateObject`, closures passadas por composição, ou até um simples `import` de outro módulo do app que eu não tenha aberto — nada disso aparece numa leitura sequencial de 8 arquivos e apareceria num parser real. Para telas de pagamento (Pix), um edge de dependência que falta é exatamente o tipo de coisa que o `/forge:impact` existe para pegar antes de mexer em produção.

3. **Isso é uma exceção pontual, não uma cobertura de Swift.** Assim que qualquer um desses 8 arquivos mudar de novo, alguém vai precisar repetir esse processo manual ou o grafo volta a mentir por omissão. Não resolve o problema de fundo (engine sem parser Swift), só empurra a decisão para a próxima pessoa.

## Recomendação

Para destravar o PR de hoje, sugiro tratar esta entrada manual como uma **liberação pontual e documentada**, não como um "grafo confiável" — algo como: gate de impacto revisado manualmente por [responsável] em 2026-09-26, com este parecer anexado como evidência, cobrindo apenas os 8 arquivos listados no estado em que estão agora. Antes do próximo PR que toque `AppPassageiro/`, vale abrir um item de dívida técnica para cobertura Swift real no `forge:codegraph` (tree-sitter-swift já existe como gramática madura), para não repetir esse manual-override.

## Arquivos alterados

- `.forge/graph/graph.json` — 8 nós e 6 arestas adicionados, todos marcados `manual_entry: true`, mais um aviso `manual_override_notice` no topo do documento.
