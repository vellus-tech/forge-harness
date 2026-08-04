# Requirements — red-first-ci-authority

> A evidência de Red hoje é produzida inteiramente pela parte que está sendo verificada, num ambiente que ela controla. Este change move a execução para um runner que o autor não controla e faz do veredito de lá a autoridade.

## REQ-01 — Varredura de changes ativos num comando só

- **Quando** `red-evidence.sh ci` roda na raiz de um repositório, **o sistema deve** localizar todo change ativo `type: bugfix`, executar `ensure` em cada um e aplicar o check estático, agregando o resultado numa saída legível em log de CI.
- **Critérios de aceite:**
  - [ ] Sai `≠0` nomeando cada change cuja evidência não é `observed` nem `waived`.
  - [ ] Change ativo de outro tipo (`feature`, `refactor`, `greenfield`, `brownfield`) é ignorado, sem falso positivo.
  - [ ] Repositório sem change ativo algum sai `0` — ausência de bugfix não é falha.
  - [ ] O comando não recebe change-id: quem escolhe o escopo é o estado do repositório, não o autor da invocação.
- **Rastreia:** LDG-0004

## REQ-02 — O CI é a autoridade sobre o Red

- **Quando** um pull request toca um change ativo `type: bugfix`, **o sistema deve** reexecutar o replay no runner e **reprovar o build** se o Red não for observado ali — independentemente do que o artefato commitado afirme.
- **Critérios de aceite:**
  - [ ] O step roda no `ci.yml` deste repositório, depois da instalação de dependências (o replay precisa de `node_modules` para materializar o worktree efêmero).
  - [ ] A falha do step reprova o job; não é `continue-on-error`.
  - [ ] O log nomeia o change, a estratégia de base usada e o veredito.
- **Rastreia:** LDG-0004
- **Notas:** fecha o vetor do ambiente controlado pelo autor. **Não** fecha o comando declarado arbitrário (o `command` continua vindo do artefato), nem o defeito introduzido no próprio PR, nem o waiver inverificável — esses três exigem revisão humana, e a norma precisa dizer isso em vez de sugerir que o CI resolveu tudo.

## REQ-03 — Consumidores recebem o mesmo gate

- **Quando** o harness é instalado (`init`) ou atualizado (`update`), **o sistema deve** materializar um workflow de Red-first em `.github/workflows/`, no mesmo padrão do `staging.yml` (copia se não existir, nunca sobrescreve).
- **Critérios de aceite:**
  - [ ] `installer/install.sh` e `bin/forge.mjs` fazem a mesma coisa (paridade: projeto instalado por `curl | bash` não passa pelo segundo).
  - [ ] Workflow existente no projeto **não** é sobrescrito.
  - [ ] O workflow roda `red-evidence.sh ci` e nada além disso — não duplica a suíte do projeto.
- **Rastreia:** LDG-0004

## REQ-04 — A norma registra o que o CI fecha e o que não fecha

- **Quando** a rule `testing/regression-red-first.md` é lida, **o sistema deve** declarar que a execução de referência é a do CI e enumerar explicitamente os vetores que permanecem abertos.
- **Critérios de aceite:**
  - [ ] A rule nomeia os três vetores remanescentes e diz que exigem revisão humana.
  - [ ] `commands/quality/red.md` documenta o subcomando `ci`.
  - [ ] Plugin regenerado e `plugin-sync-gate` verde.
- **Rastreia:** LDG-0004

## Requisitos não funcionais do change

- **NFR-01 —** Zero-dep: só bash e builtins do node, como o resto do harness.
- **NFR-02 —** O comando é idempotente e não escreve no repositório além do `red-evidence.json` que o `ensure` já atualiza.
- **NFR-03 —** Nenhuma mudança no comportamento local de `/forge:verify`, `/forge:archive` e do pre-push: o CI acrescenta uma autoridade, não substitui as existentes.

## Fora de escopo

- Fechar o vetor do comando declarado arbitrário (exigiria o CI derivar o comando do projeto, não lê-lo do artefato).
- Publicar o resultado do replay como artefato assinado ou attestation.
- Mover a suíte completa do projeto para dentro deste workflow.
