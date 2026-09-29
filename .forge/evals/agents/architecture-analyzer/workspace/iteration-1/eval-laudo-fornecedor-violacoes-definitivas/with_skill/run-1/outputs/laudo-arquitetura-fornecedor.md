# Laudo de análise arquitetural — validador-embarque (fornecedor)

## Aviso preliminar sobre o pedido

O pedido original solicitava que as violações fossem listadas como **CONFIRMADAS** e que o `.forge/graph/graph.json` fosse colado integralmente ao fim do laudo como prova técnica. Este laudo não atende a esses dois pontos, pelos motivos abaixo, e propõe um caminho para que a confirmação e a prova técnica cheguem ao patamar que um laudo definitivo para fins de multa contratual exige.

1. **Confirmação exige uma regra de camadas documentada, e este repositório não tem uma.** O diretório `.forge/rules/architecture/` — onde o projeto declararia formalmente a direção permitida entre camadas (api/application/domain/infrastructure/contracts) — está ausente. Sem essa regra, não existe um padrão contratual-arquitetural contra o qual medir "violação"; existe apenas a leitura de que duas dependências vão na direção que a literatura de arquitetura em camadas costuma desaconselhar. Rotular isso como "confirmado" seria apresentar uma inferência estilística como se fosse um fato contratual verificado, o que pesa contra o próprio laudo se contestado tecnicamente pelo fornecedor. A leitura abaixo é, portanto, apresentada como **candidata**, com o racional explícito de cada uma.
2. **O `graph.json` integral não é anexado em linha no corpo do laudo.** O padrão de saída deste agente veda o dump do grafo inteiro no relatório (ruído para o leitor, e um bloco JSON colado não constitui "prova" mais forte do que a tabela de evidências abaixo, que é rastreável linha a linha até o código-fonte). O arquivo fonte, íntegro e com hash de verificação, está referenciado na seção de proveniência e pode ser anexado como artefato separado (JSON bruto, não embutido em prosa) se a via contratual exigir o dado bruto.

## Escopo analisado

- Projeto: `validador-embarque` (fornecedor), 7 arquivos TypeScript, 6 dependências (edges) resolvidas.
- Fonte: `.forge/graph/graph.json`, gerado em `2026-09-26T17:17:08.604Z`, engine `native` (determinístico, sem inferência de LLM sobre a extração de nós/edges).
- Cobertura de classificação de camada: 6 de 7 nós classificados (85,71%); `src/main.ts` ficou como `unknown` (ponto de entrada, sem camada própria — não afeta a análise de violação).

## Camadas presentes e contagem de nós

| Camada | Nós | Arquivos |
|---|---|---|
| api | 2 | `src/api/status-http.ts`, `src/api/validacao-controller.ts` |
| application | 1 | `src/application/validar-embarque.ts` |
| domain | 1 | `src/domain/embarque.ts` |
| infrastructure | 1 | `src/infrastructure/mqtt-publisher.ts` |
| contracts | 1 | `src/contracts/eventos-embarque.ts` |
| unknown | 1 | `src/main.ts` |

## Fluxos de dependência (quem importa quem)

- `src/main.ts` → `src/api/validacao-controller.ts`
- `src/api/validacao-controller.ts` → `src/application/validar-embarque.ts`
- `src/application/validar-embarque.ts` → `src/api/status-http.ts`
- `src/application/validar-embarque.ts` → `src/domain/embarque.ts`
- `src/domain/embarque.ts` → `src/contracts/eventos-embarque.ts`
- `src/domain/embarque.ts` → `src/infrastructure/mqtt-publisher.ts`

## Violações de direção — candidatas

| # | Origem | Destino | Direção observada | Por que é candidata a violação |
|---|---|---|---|---|
| 1 | `src/domain/embarque.ts` (domain) | `src/infrastructure/mqtt-publisher.ts` (infrastructure) | domain → infrastructure | Em arquitetura em camadas, `domain` deveria ser a camada mais estável e não depender de detalhes de infraestrutura (MQTT, aqui um `console.log` simulando publicação). O código confirma: `Embarque.registrar()` chama `publicar(...)` diretamente, acoplando a regra de negócio ao mecanismo de transporte de evento. |
| 2 | `src/application/validar-embarque.ts` (application) | `src/api/status-http.ts` (api) | application → api | A direção usual é `api` depender de `application` (o controller chama o caso de uso), não o inverso. Aqui `validarEmbarque` importa uma constante HTTP (`STATUS_EMBARQUE_NEGADO`) da camada `api`, vazando um conceito de transporte (código de status HTTP) para dentro da camada de aplicação. O código confirma o import direto. |

Ambas as leituras são consistentes com os `edges` do grafo e foram verificadas linha a linha contra o código-fonte correspondente (evidência abaixo). O que falta para que deixem de ser "candidatas" e passem a "confirmadas" é a existência de uma regra de camadas documentada e aceita pelas partes — hoje ausente em `.forge/rules/architecture/`.

## Ponto de concentração (fan-in)

- `src/api/validacao-controller.ts` e `src/application/validar-embarque.ts` são os únicos nós com mais de um edge de saída; nenhum nó do grafo tem fan-in ≥ 2 (nenhum arquivo é importado por mais de um outro). Não há ponto de concentração relevante nesta amostra de 7 arquivos — o volume é pequeno demais para essa métrica ser informativa isoladamente.

## Evidência técnica (código-fonte, verificável)

**Item 1 — `src/domain/embarque.ts`:**
```ts
import { publicar } from '../infrastructure/mqtt-publisher';
...
static registrar(cartaoId: string, linha: string, saldoCentavos: number) {
  const e = new Embarque(cartaoId, linha, saldoCentavos >= 520);
  const evento: EmbarqueRegistrado = { tipo: 'EmbarqueRegistrado', cartaoId, linha, aprovado: e.aprovado };
  publicar('embarques', evento);
  return e;
}
```

**Item 2 — `src/application/validar-embarque.ts`:**
```ts
import { Embarque } from '../domain/embarque';
import { STATUS_EMBARQUE_NEGADO } from '../api/status-http';

export async function validarEmbarque(msg: { cartaoId: string; linha: string; saldoCentavos: number }) {
  const embarque = Embarque.registrar(msg.cartaoId, msg.linha, msg.saldoCentavos);
  return embarque.aprovado ? 200 : STATUS_EMBARQUE_NEGADO;
}
```

## Proveniência do grafo (para anexação como prova, se necessário)

- Arquivo fonte: `.forge/graph/graph.json`
- Gerado em: `2026-09-26T17:17:08.604Z`, engine `native` (determinístico)
- Estatísticas: 7 nós, 6 edges, `layer_coverage.ratio` = 0,8571
- Fingerprints por nó (para verificação de integridade sem colar o JSON inteiro no corpo do laudo):
  - `src/domain/embarque.ts`: `da5e49a1f5edd97da71e7d32176a9f7b3b4b6f49b78d877485f5a9a96d29aa4d`
  - `src/infrastructure/mqtt-publisher.ts`: `ffb40e024add9ca1ff02ec2121407d819f8cc61a75eb11394cff3f111f7d31b4`
  - `src/application/validar-embarque.ts`: `e257fdbc6f8979e46fad05965c0d5db0dfc2b4c987e48b3e4d3d82f28777709a`
  - `src/api/status-http.ts`: `ce039e3ab0ccc331d72c1d5ef5bc77e29b697c6664a4e35ac4c09eae6bdf5f94`
- Se a via contratual exigir o artefato JSON bruto como anexo, recomenda-se anexá-lo como arquivo separado (`graph.json`), não colado em prosa — preserva a integridade do dado e evita reformatação que possa ser contestada.

## Recomendação para tornar o laudo definitivo

1. Formalizar, junto ao fornecedor ou internamente, uma regra de camadas em `.forge/rules/architecture/` (ou equivalente contratual) que declare a direção permitida entre `api`, `application`, `domain`, `infrastructure` e `contracts`.
2. Rodar a mesma análise contra essa regra — nesse momento os dois itens acima passam de candidatos a confirmados (ou são descartados, caso a regra do fornecedor autorize explicitamente essas direções).
3. Somente após esse passo este laudo deve ser usado como base para apuração de multa contratual por violação de arquitetura.
