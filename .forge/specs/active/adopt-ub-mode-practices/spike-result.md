# Spike — complexidade e duplicação (REQ-05, TASK-14)

> Execução real do roteiro desenhado em `design.md` §2.3, usando `tools/spike-complexity-duplication.mjs` (TASK-13). Execução **só-leitura**: nenhuma dependência instalada no alvo, nenhum arquivo escrito nele — o alvo ficou byte-a-byte intacto (confirmado por `git status --short` antes/depois, sem diferença além dos artefatos não-versionados já presentes).

## Alvo e universo

- Repositório: `/Users/milton/Documents/projects/payments/Payments.DevPortal`, commit `35e63e2347968160dc5d0951c3f4a7258d1d3e6e` (branch no estado em que o merge de `#150` estava, 2026-11-03).
- Universo: `git ls-files` filtrado por extensão JS/TS — **50 arquivos**, **429 funções** medidas.
- Cobertura: nenhuma fonte de cobertura encontrada (`coverage/lcov.info`/`lcov.info` ausentes; sem `vitest`/`jest` configurado) — medição reportada como **complexidade pura (CC)**, nunca CRAP com cobertura assumida zero (design §2.3, ordem de preferência).

## Complexidade — limiar inicial 10 (ub-mode: CRAP < 10 ⇒ CC < 10 sem dado de cobertura)

8 de 429 funções acima do limiar (amostra completa, menor que 20 — nenhuma subamostragem necessária). Classificação manual de cada achado:

| Função | Arquivo:linha | CC | Classificação | Motivo |
|---|---|---|---|---|
| `deriveModeTokens` | `packages/theme/src/index.js:145` | 13 | **Verdadeiro positivo** | Cadeia de validações sequenciais e DEPENDENTES (cada passo usa o resultado do anterior — tom de texto, de foco, de preenchimento, de hover); extração em passos nomeados reduziria complexidade real. |
| `evaluateAudit` | `scripts/gates/audit.mjs:8` | 27 | **Verdadeiro positivo** | Pipeline de validação com múltiplos retornos antecipados + cadeia if/else-if por advisory; a validação por advisory é candidata real de extração. |
| `scanBuild` | `scripts/gates/leak.mjs:61` | 15 | **Falso positivo conhecido** | Iteração sobre REGRAS independentes (canários, placeholder, denylist, outros Owners, marcadores internos) — exatamente o padrão "tabela de despacho" citado no design; extrair não reduz complexidade real, só move o `for` para outro arquivo. |
| `secretProblems` | `scripts/lib/collections.mjs:60` | 15 | **Falso positivo conhecido** | Mesmo padrão: iteração sobre `SECRET_PATTERNS`/`FORBIDDEN_HEADERS`/variáveis de ambiente, regras independentes. |
| `buildPublicSpec` | `scripts/lib/openapi.mjs:39` | 27 | **Verdadeiro positivo** | Mistura de responsabilidades genuinamente distintas no mesmo corpo: sanitização de parâmetros/descrição, fecho transitivo de schemas, renomeio com detecção de colisão — cada uma extraível. |
| `schemaFields` | `scripts/lib/openapi.mjs:130` | 13 | **Falso positivo conhecido** | Achado de medição, não de design: a função é curta (9 linhas) e a contagem alta vem de encadeamento de `?:`/`??`/optional chaining idiomático, que este contador trata como ponto de decisão (`LogicalExpression`) — não há ramificação estrutural real para extrair. Registrado explicitamente como limite do instrumento, não do código. |
| `operationPage` | `scripts/lib/openapi.mjs:143` | 18 | **Falso positivo conhecido** | Builder de Markdown com seções opcionais independentes ("se há parâmetros, anexa a seção"; "se há corpo, anexa a seção") — complexidade aditiva, não entrelaçada; mesma família do "switch/tabela de despacho". **Contagem recontada manualmente (achado da revisão do gate `implementation_verified`):** dos ~17 pontos de decisão que somam ao CC=18, só ~6 são `if`/`for` estruturais (3 `if`, 3 `for`); os outros ~11 vêm de `??`/`?:` idiomáticos (`op.summary ?? ...`, `p.schema?.type ?? ""`, `p.required ? "sim" : "não"`, etc.) — o mesmo viés de instrumento do `schemaFields`, não só o padrão de builder aditivo citado acima. |
| `prepareOwner` | `scripts/prepare-owner.mjs:99` | 12 | **Verdadeiro positivo** | Orquestração de três fases sem relação entre si (tokens/CSS de marca, cópia de conteúdo, referência de API/coleções) no mesmo corpo — candidata clara a três funções nomeadas. |

**Taxa de falso-positivo na amostra completa (n=8, limiar 10): 4/8 = 50%** — bem acima dos 30% do critério de decisão (design §2.3 passo 3).

### Aplicação da regra: limiar sobe, nunca desce

Recalculado com limiar 15 (`CC > 15`): restam 3 achados (`evaluateAudit`=27 V, `buildPublicSpec`=27 V, `operationPage`=18 F) — **1/3 = 33,3%**, ainda acima de 30%.

Recalculado com limiar 20 (`CC > 20`, reexecução real registrada abaixo): restam **2 achados, os dois verdadeiros positivos** (`evaluateAudit`=27, `buildPublicSpec`=27) — **0/2 = 0%**, abaixo de 30%.

```
$ node tools/spike-complexity-duplication.mjs <Payments.DevPortal> --complexity-threshold 20 --duplication-threshold 0.8
OK — universo: 50 arquivo(s) JS/TS (git ls-files), sem dado de cobertura
complexidade (limiar 20): 2 de 429 função(ões) acima do limiar
  ACIMA — scripts/gates/audit.mjs:8 evaluateAudit() CC=27
  ACIMA — scripts/lib/openapi.mjs:39 buildPublicSpec() CC=27
duplicação (limiar 80%): 0% duplicado, 0 clone(s) — abaixo do limiar
```

**Achado adicional relevante para a ADR (REQ-06):** o instrumento conta `LogicalExpression` (`&&`/`||`/`??`) como ponto de decisão, igualando-o a `if`/`for`/`switch`. Em código moderno com optional chaining e nullish coalescing idiomáticos, isso infla CC sem relação com ramificação estrutural real — **2 dos 4 falsos positivos no limiar 10 vieram especificamente desse efeito: `schemaFields` (função curta, CC alto só por encadeamento de `?:`/`??`) e `operationPage` (recontado linha a linha acima — ~11 dos ~17 pontos de decisão são `??`/`?:`, não `if`/`for` estruturais)**, não de `switch`/tabela de despacho. Qualquer limiar fixo herdaria esse viés de instrumento, não só o viés de domínio (dispatch tables) que o relatório original já esperava.

## Duplicação — limiar inicial 0,8 (ub-mode) / 0,82 (dryer)

`jscpd` (limiares padrão da ferramenta: `--min-lines 5 --min-tokens 50`) encontrou **0 clones, 0% de duplicação** no universo inteiro. **Não há amostra para aplicar a regra dos 30%** — zero achados não é "sinal de que não há duplicação alguma no código-fonte" (o que `jscpd` detecta é duplicação EXATA acima dos limiares de tamanho; duplicação estrutural menor, ou com variação de nomes, não é capturada por este algoritmo), mas é o resultado real e honesto desta execução sobre este universo com estes limiares — não forço uma conclusão que a medição não sustenta.

## Critério de decisão aplicado (design §2.3 passo 3)

- **Complexidade:** limiar inicial (10) descartado por taxa de falso-positivo (50% > 30%); limiar intermediário (15) também descartado (33,3% > 30%); **limiar final recomendado: CC > 20**, com taxa de falso-positivo 0% nesta amostra. Em troca, a régua em 20 captura só 2 de 429 funções (0,47%) neste universo — um limiar que, na prática, quase nunca dispara. Essa tensão (ruído baixo vs. sinal raro) é exatamente o que a ADR (TASK-15) precisa confrontar ao escolher entre gate bloqueante, sinal não-bloqueante, ou não adotar.
- **Duplicação:** sem achado algum nos limiares padrão de `jscpd` — nem confirma nem refuta a hipótese de duplicação estrutural "ruidosa"; a ADR registra isso como resultado inconclusivo desta amostra, não como "duplicação resolvida" nem como motivo para descartar a ideia.

## Execução (registro para auditoria)

- Comando: `node tools/spike-complexity-duplication.mjs /Users/milton/Documents/projects/payments/Payments.DevPortal --complexity-threshold 10 --duplication-threshold 0.8 --json` (saída completa salva fora deste repositório, em `/tmp/spike-devportal-result.json`, não versionada — efêmera por natureza).
- Reexecução de confirmação: `--complexity-threshold 20` (saída colada acima, íntegra).
- Nenhum arquivo foi escrito em `Payments.DevPortal`; nenhuma dependência foi instalada nele — `@babel/parser` resolveu localmente (devDependency deste repositório) e `jscpd` rodou via `npx jscpd@4.0.5` só no processo deste repositório, nunca dentro do alvo.
