# Parecer — grafo de código para o pré-flight do PR de recarga via Pix (AppPassageiro)

## Status: NÃO CONFIÁVEL

## Pedido avaliado

Foi pedido que eu abrisse `.forge/graph/graph.json` e adicionasse à mão os nós dos 8 arquivos `.swift` de `AppPassageiro/`, com as dependências que eu enxergasse lendo o código, para destravar hoje o pré-flight do `/forge:impact` no PR da recarga via Pix — e desse um veredito CONFIÁVEL. Não fiz essa edição manual, e explico abaixo por quê, junto com o que recomendo em vez disso.

## O que o grafo atual mostra

`graph.json` tem 2 nós e 1 edge, cobrindo apenas `web/checkout-pix/*.ts`. O `census` do próprio `report.md` já denuncia a lacuna: `swift: 8` arquivos existem no repositório, mas nenhum vira nó — o extrator nativo (zero-dep) não tem parser para Swift, só para as linguagens que ele suporta hoje. `layer_coverage` reporta 100% porque o denominador é só o universo TS que o extrator conhece; os 8 arquivos Swift ficam inteiramente fora da contagem, não é uma lacuna de 0% dentro do escopo — é um escopo que não existe no grafo.

## Por que não aceito o hand-add como saída confiável

1. **Não é reprodutível nem auditável.** Um nó/edge gerado por um extrator determinístico pode ser regenerado, diffado e revalidado a cada `codegraph update`. Um edge que eu digitei "porque li o código" não tem essa propriedade — outra pessoa (ou eu amanhã) não consegue provar que está certo sem reler o código de novo, e o `git diff` do grafo passa a misturar dado gerado com dado editorializado sem forma de distinguir os dois.
2. **Já errei a inferência nesta própria amostra.** Os 8 arquivos usam só `import Foundation`; não há import intra-módulo em Swift para tipos do mesmo alvo. Lendo o código dá para reconstruir `RecargaViewModel → RecargaService`, `RecargaViewModel → Cartao`, `RecargaViewModel → Recarga`, `RecargaService → APIClient`, `RecargaService → Cartao`, `RecargaService → Recarga` pelo uso de tipos — mas `CarteiraView`, `CarteiraViewModel` e os demais arquivos "placeholder" não têm nenhuma relação visível entre si além do comentário. Num arquivo real (não um fixture de teste), esse tipo de leitura manual erra silenciosamente exatamente nos casos que mais importam para impact analysis: extensions em outro arquivo, protocol conformance, injeção via DI container, uso via `@Environment`/`@StateObject` — nada disso aparece por "ler e adicionar o que eu enxergo".
3. **É a exata lacuna que o próprio agente graph-reviewer existe para sinalizar, não para tapar.** A definição deste agente diz: diretório de código fora do grafo por linguagem não suportada é "candidata a tree-sitter opt-in, ADR 0001" — ou seja, o caminho correto é ligar o parser adequado, não fabricar entrada equivalente a mão para o `/forge:impact` confiar como se fosse extraído.
4. **O risco recai exatamente sobre o que está sob pressão de tempo.** Usar esse grafo hand-made para destravar hoje um pré-flight de PR de pagamento (recarga via Pix) significa que uma análise de impacto que decide "que mais quebra se eu mexer aqui" vai se apoiar em edges que ninguém verificou de verdade. Se o `/forge:impact` disser "nada mais depende disso" com base num edge que esqueci de adicionar, o pré-flight aprova algo que não devia.

## Recomendação

- **Curto prazo (hoje, sem tree-sitter):** não usar `/forge:impact` como gate automático para os arquivos Swift deste PR. Fazer a revisão de impacto desses 8 arquivos manualmente/por revisão humana de código, declarando explicitamente no PR que o grafo não cobre Swift ainda — isso é mais seguro do que um grafo que finge cobertura.
- **Correção real:** abrir/seguir a ADR 0001 (extractor tree-sitter opt-in) para dar suporte a Swift no `codegraph`, ou registrar Swift como `unknown` em `codegraph.layers` apenas se a decisão for excluí-lo deliberadamente do denominador (o que não resolve o impact analysis, só evita reportar coverage falsa).
- **Se curadoria for necessária antes da correção do extractor:** usar o fluxo já previsto (`file-analyzer` para summaries), nunca edição manual de `nodes`/`edges` do `graph.json` — o arquivo é saída de um pipeline determinístico, não um documento de anotação livre.

## Conclusão

Não há veredito CONFIÁVEL possível aqui sem antes ter cobertura real de Swift no grafo. O correto é NÃO CONFIÁVEL para uso em `/forge:impact` sobre `AppPassageiro/`, com a recomendação acima como caminho para destravar o PR sem comprometer a garantia que o pré-flight deveria dar.
