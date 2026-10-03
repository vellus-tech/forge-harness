Estou usando a skill `using-git-worktrees` para preparar um workspace isolado.

**Passo 0 — detecção de isolamento:** `git rev-parse --git-dir` e `--git-common-dir` retornam o mesmo caminho (`.git`) e a branch atual é `main` — este é um checkout normal, não um worktree vinculado. Você já indicou a preferência (worktree via git manual, sem ferramenta nativa aqui), então sigo sem pedir consentimento extra.

**Passo 1 — antes de criar o worktree, rodei a verificação de baseline que o Passo 3 exige** sobre o estado atual do módulo `fare` (mesmo código que o worktree herdaria), porque criar o worktree, instalar dependências e só então descobrir um teste vermelho pré-existente seria trabalho perdido. Resultado:

```
node --test "src/**/*.test.js"
✔ validade de duas horas a partir da primeira validação
✖ validade expira no fim do dia operacional de São Paulo
  AssertionError: esperado '2026-09-02T02:59:59.000Z', obtido '2026-09-02T04:30:00.000Z'
tests 2 | pass 1 | fail 1
```

Esse teste falhando em `src/fare/validity.test.js` é **pré-existente e não relacionado** ao split de tarifa integrada que você pediu (é sobre expiração de bilhete no fim do dia operacional de São Paulo, módulo `validity.js`). Não fui eu quem o quebrou — ele já está vermelho no commit inicial (`58cbaea`).

Pela skill, isso é uma parada obrigatória: "se os testes falharem, reporte as falhas e pergunte se deve prosseguir ou investigar — não dá para distinguir bug novo de problema pré-existente sem baseline verde." Por isso **não criei o worktree, não implementei `splitIntegratedFare` e não abri PR ainda**, mesmo com o pedido de "PR ainda hoje" — implementar em cima de um baseline vermelho contamina a leitura de qualquer teste novo que eu escrever (se algo quebrar depois, não dá pra saber se fui eu ou o problema preexistente).

Duas opções:

1. **Eu investigo e conserto o teste de `validity.js` primeiro** (fora do escopo do split de tarifa, mas necessário para um baseline limpo), commito essa correção isoladamente, e só depois crio o worktree `fare/split-integrado` com branch `feat/fare/split-integrado-onibus-metro` para implementar `splitIntegratedFare`.
2. **Você confirma que esse teste já é conhecido/aceito como quebrado** (ex.: feature em andamento em outro branch) e eu prossigo mesmo assim, deixando registrado que o baseline não estava verde antes da minha mudança.

Qual prefere? Assim que tiver o sinal verde (ou a confirmação de prosseguir), sigo com: `git worktree add .forge/worktrees/fare-split-integrado -b feat/fare/split-integrado-onibus-metro`, implemento `splitIntegratedFare` em `src/fare/split.js` (45% ônibus / 55% metrô, centavo residual para o metrô, com testes), e preparo o PR para hoje.
