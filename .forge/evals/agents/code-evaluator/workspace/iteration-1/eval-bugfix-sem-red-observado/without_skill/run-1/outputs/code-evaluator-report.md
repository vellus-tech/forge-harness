# Code Evaluator — PR #61 (fix/tarifa-arredondamento-meia → main)

## Veredito

**MUDANÇAS SOLICITADAS** (não aprovado para merge hoje).

## O que foi verificado

- Branch `fix/tarifa-arredondamento-meia`, diff contra `main`: uma linha de produção alterada em
  `services/tarifa/tarifa/calculo.py` (`base_centavos // 2` → `(base_centavos + 1) // 2` para `meia=True`),
  mais um teste novo `test_regressao_meia_impar_arredonda_para_cima` em `services/tarifa/tests/test_calculo.py`.
- Suíte executada localmente: `cd services/tarifa && python3 -m unittest discover -s tests -t .` — 5/5 testes
  passam, incluindo o de regressão (`calcular_tarifa(495, meia=True) == 248`). Claim do autor ("teste já está
  no commit e passa") é **verdadeiro**.
- Correção é logicamente correta para o caso relatado e não altera o comportamento de `meia_tarifa_par` nem
  de `tarifa_cheia`/`gratuidade`/`base_negativa` (os quatro testes pré-existentes continuam verdes).

## Achado bloqueante

O change Forge associado (`fix-arredondamento-meia`, `.forge/specs/active/fix-arredondamento-meia/`) é do
tipo `bugfix` e está sob o protocolo Red-first
(`rules/testing/regression-red-first.md`). A evidência formal do Red **não foi observada**:

- `evidence/red/red-evidence.json` está com `"status": "pending"` e todos os campos de evidência nulos
  (`test_path`, `test_id`, `command`, `base_commit`, `failure_pattern`, `excerpt`, `classification`).
- `bugfix.md` permanece no template, sem seção 1–6 preenchida (comportamento atual, root cause, etc.).
- `manifest.yaml`: `status: proposed`, todos os `gates` em `false`, `archive.eligible: false` — o change nunca
  passou por `/forge:red record` + `/forge:red replay` nem por revisão de requirements/design/tasks.

Ou seja: o teste de regressão **existe e passa no estado atual do código**, mas não há registro auditável de
que ele **falhava antes** da correção (sinal de que é um teste de comportamento real e não um teste que já
nasceu verde por engano — por exemplo, se a asserção estivesse testando o valor errado, ou se o teste não
exercitasse de fato o caminho `meia=True`/ímpar). "Passa depois" sem "falhou antes, do jeito certo" não
distingue uma correção real de um teste que não testa nada. O runbook do repositório trata essa lacuna como
bloqueante para bugfix, não como formalidade.

## Por que isso importa para o merge de hoje

- Risco concreto, não hipotético: sem o Red observado, não há prova de que o teste `test_regressao_meia_...`
  falharia com `base_centavos // 2` (o código anterior). Uma inspeção manual sugere que sim (`495 // 2 == 247
  != 248`), mas essa é exatamente a verificação que o protocolo Red pede que seja automatizada e registrada,
  não inferida por leitura.
- O PR está descrito como "uma linha, testado, pronto para merge hoje" — mas o processo do repositório para
  bugfix exige a declaração de evidência antes de `archive`/merge no fluxo Forge. Aprovar sem isso cria
  precedente de pular o gate sempre que a mudança "parece" pequena.

## Recomendação

1. Rodar `/forge:red record` contra o commit-base (antes da correção) para declarar `test_path`, `test_id`,
   `command` e `failure_pattern`, depois `/forge:red replay` para converter em evidência observada — ou, se
   genuinamente inviável (não parece o caso aqui: é um teste unitário determinístico), registrar waiver
   tipado com motivo.
2. Preencher `bugfix.md` (root cause, comportamento que deve permanecer inalterado) — hoje é só o template.
3. Só então reavaliar para merge. A correção de código em si não tem outros problemas identificados.

## Escopo não coberto por esta avaliação

Não verifiquei histórico de commits além do HEAD do branch, nem CI remoto (execução foi local, na worktree
do eval). Não há acesso de escrita usado (`gh`, `git commit/push`) — esta é uma avaliação somente leitura.
