---
title: Estilo de Código
applies_to:
  - all
priority: high
last_reviewed: 2026-07-10
based_on: []
---

# Estilo de Código

## Princípio

Uma TASK bem escrita diz **o quê** construir e como decompor/verificar (`tasks-writer` — bite-sized, TDD-first, rastreabilidade). Ela é silenciosa sobre a **forma interna** do código que nasce do teste verde. Dois engenheiros com a mesma TASK perfeita produzem código de qualidade radicalmente diferente porque estilo — control-flow, aninhamento, tamanho de função, tratamento de erro, comentários — não está no envelope da task.

Esta rule governa essa forma. É o par natural do bite-sized: **bite-sized é a granularidade da TASK; estilo de código é a granularidade da função.** O objetivo é código que *lê bem e envelhece bem*, não apenas *funciona e é pequeno*.

Escopo é estilo/legibilidade. Regras de **domínio** (imutabilidade de objeto de valor, `DomainException` em invariante) vivem em [`architecture/ddd.md`](../architecture/ddd.md); regras de **camada** (validação de input antes do handler) em [`architecture/clean-architecture.md`](../architecture/clean-architecture.md). Esta rule remete a elas, não as re-deriva. Nomenclatura de artefatos/identificadores é [`conventions/naming.md`](./naming.md); ciclo de teste é [`testing/tdd.md`](../testing/tdd.md).

---

## Diretrizes

### 1. Early return / guard clauses

Trate pré-condições e casos de falha **no topo** da função e retorne cedo. O caminho feliz fica sem indentação, no final. Não use `else` depois de um `return`/`throw`. Guard clauses tornam as pré-condições explícitas e eliminam o *arrow anti-pattern* (blocos `if` profundamente aninhados) — o principal assassino de legibilidade.

```csharp
// ✓ guard clauses no topo; happy path sem indentação
public Receipt Settle(Transaction tx)
{
    if (tx is null) throw new ArgumentNullException(nameof(tx));
    if (!tx.IsAuthorized) return Receipt.Rejected(tx, "not authorized");
    if (tx.IsSettled) return Receipt.AlreadySettled(tx);

    return Receipt.For(tx.Capture());
}
```

```csharp
// ✗ arrow anti-pattern — a lógica real some sob 3 níveis de if/else
public Receipt Settle(Transaction tx)
{
    if (tx != null) {
        if (tx.IsAuthorized) {
            if (!tx.IsSettled) {
                return Receipt.For(tx.Capture());
            } else { return Receipt.AlreadySettled(tx); }
        } else { return Receipt.Rejected(tx, "not authorized"); }
    } else { throw new ArgumentNullException(nameof(tx)); }
}
```

### 2. Aninhamento e complexidade

- Profundidade de aninhamento **≤ 3**. Além disso, extraia um método com nome de intenção ou inverta a condição com guard clause.
- Uma função deve **caber na tela** (~40 linhas é *smell*, não limite rígido). Função que não cabe geralmente faz mais de uma coisa (§3).
- Complexidade ciclomática alta é **gatilho de extração**, não um portão: um `switch`/cadeia de `if` grande vira tabela de despacho, estratégia ou polimorfismo.

É o bite-sized aplicado à função — complexidade correlaciona com densidade de defeito, e uma unidade menor é revisável de uma leitura só.

### 3. Uma função, uma responsabilidade, um nível de abstração

Uma função faz **uma** coisa e mistura **um só** nível de abstração. Não intercale orquestração de alto nível (chamar serviços, decidir fluxo) com detalhe de baixo nível (aritmética de bytes, formatação de string) na mesma função. Isso habilita nomear por intenção e testar em isolamento — e alimenta diretamente o TDD (função pequena e pura é trivial de cobrir).

### 4. Sem literais mágicos; locais revelam intenção

- Todo número/string com significado vira **constante nomeada**: `const int MaxRetries = 3;`, não `if (attempts > 3)`. Um literal solto é um contrato silencioso.
- Prefira uma **variável intermediária com nome** a uma expressão booleana/aritmética densa embutida: `bool isEligible = ...; if (isEligible)`.

Complementa `naming.md` (nível-artefato) descendo ao nível de statement.

### 5. Assinaturas enxutas

- **≤ 3–4 parâmetros.** Acima disso, agrupe em um *parameter object* / value object coeso.
- **Sem flag booleana de "modo"** (`process(order, isRefund: true)`): ela indica que a função faz duas coisas — divida em `process` e `processRefund`. No call site, um `true`/`false` posicional é ilegível.
- Prefira parâmetros que não permitam estado inválido a validar a combinação por dentro.

### 6. Tratamento de erro

- **Fail-fast na fronteira:** valide entrada na borda do sistema (API, IO, deserialização) e rejeite cedo (§1). Ver a validação por camada em `clean-architecture.md`.
- **Nunca engula erro:** proibido `catch` vazio ou que só loga e segue como se nada fosse. Capturou e não pode tratar → relance (preservando a causa) ou propague. Estende o veto de `quality-gates.md` a `@ts-ignore`/`#pragma warning disable` sem justificativa.
- **Exceção × resultado:** invariante de domínio violada lança exceção de domínio (`DomainException` — ver `ddd.md`); falha **esperada** de fluxo (validação de entrada, "não encontrado", regra de negócio recusada) é melhor modelada como retorno explícito (`Result`/discriminated union/`sealed` result) do que como exceção. Não use exceção como control-flow de caso esperado.

Erro engolido é o bug silencioso mais caro que existe — some do log e reaparece como corrupção de dado.

### 7. Imutabilidade e ausência de efeito colateral oculto

- Prefira dados **imutáveis** e funções **puras** onde for prático — são trivialmente testáveis (alimentam PBT/TDD) e eliminam uma classe inteira de bugs de aliasing.
- **Nunca mute um argumento** silenciosamente (ex.: reordenar/limpar a coleção que o chamador passou). Se precisa transformar, retorne um novo valor.
- Para imutabilidade de **objeto de valor de domínio** (campos `readonly`, igualdade por valor), siga `ddd.md` — esta rule só firma o hábito geral.

### 8. Comentários, código morto e TODO

- Comente o **porquê**, não o **o quê**: o racional, o trade-off, a referência à decisão — nunca parafraseie o que o código já diz. Comentário que repete o código apodrece na primeira mudança.
- **Sem código comentado.** Git é o histórico; código morto comentado é ruído (mesma filosofia de `no-summary-files.md` aplicada ao source). Deletou → deletou.
- `TODO`/`FIXME` exige **dono e endereço** (ticket/issue) ou é resolvido antes do merge. TODO órfão é dívida sem cobrança — e os gates baratos do `implement` já grepam por `TODO`/`FIXME` residual.

### 9. DRY com a regra de três

Extraia uma abstração na **terceira** repetição, não na primeira. Duas ocorrências parecidas podem divergir por razões diferentes; unificá-las cedo acopla código não-relacionado e é mais caro de desfazer do que a duplicação. Duplicação é mais barata que a abstração errada — prefira esperar o padrão se firmar (evite o WET/abstração prematura).

### 10. Fronteira defensiva, núcleo confiável

Valide e normalize dado na **borda** (entrada de API, IO, mensageria, deserialização) — uma vez, no ponto de entrada. **Dentro** do domínio, confie nas invariantes já garantidas: não espalhe null-check paranoico em toda função interna. A garantia vem de o dado inválido não conseguir entrar, não de revalidar em todo lugar. A versão arquitetural (anti-corruption, validação antes do handler) está em `clean-architecture.md`.

---

## Verificação

Estilo é majoritariamente **julgamento**, não mecanizável por completo — por isso o enforcement é primariamente humano/agente:

- **Checklist de revisão:** o `quality-reviewer` (e o code-review em geral) confere estas diretrizes; os engineering agents leem esta rule **antes de codificar**; o `task-coder` a inclui no contexto passado aos specialists.
- **Braço mecânico (quando o linter da stack estiver configurado no projeto):** parte é automatizável como *smell* — ESLint `max-depth`/`complexity`/`no-magic-numbers` (TS/React), analisadores Roslyn / `dotnet format` (.NET), `detekt`/`ktlint` (Kotlin). **Não** é um novo gate bloqueante de CI: o template não presume esses limites ligados, então trate-os como sinal, não como portão — o gate de qualidade permanece o de `quality-gates.md`.

## Anti-Patterns

| Errado | Correto | Motivo |
|---|---|---|
| `if` aninhado em 4+ níveis | guard clauses + retorno cedo | Arrow anti-pattern (§1) |
| `else` após `return`/`throw` | remover o `else`; happy path no fim | Indentação inútil (§1) |
| `if (x > 86400)` | `const int SecondsPerDay = 86400;` | Literal mágico (§4) |
| `render(user, true, false)` | funções separadas ou parameter object | Flag booleana posicional (§5) |
| `catch (Exception) { }` | tratar, relançar com causa, ou propagar | Erro engolido (§6) |
| mutar a lista recebida por parâmetro | retornar nova coleção | Efeito colateral oculto (§7) |
| bloco de código comentado "por via das dúvidas" | deletar (git guarda) | Código morto (§8) |
| abstrair na 1ª duplicação | esperar a 3ª ocorrência | Abstração prematura (§9) |

## Referências

- [Nomenclatura](./naming.md)
- [Política de Idioma](./language-policy.md)
- [Proibição de Arquivos de Resumo](./no-summary-files.md)
- [TDD](../testing/tdd.md) · [Quality Gates](../testing/quality-gates.md)
- [DDD](../architecture/ddd.md) · [Clean Architecture](../architecture/clean-architecture.md)
