---
name: using-git-worktrees
description: Use ao iniciar trabalho de feature que precisa de isolamento do workspace atual, ao executar um plano de implementação, ou quando o usuário pedir "worktree", "isolar o ambiente", "trabalhar numa branch separada sem mexer no meu checkout". Garante um workspace isolado via ferramenta nativa do harness ou, na ausência dela, via git worktree manual — com setup do projeto e baseline de testes verde antes de começar.
---

# Trabalho com Git Worktrees

## Visão geral

Garantir que o trabalho aconteça em um **workspace isolado**. Prefira a ferramenta de worktree nativa do harness. Só recorra ao `git worktree` manual quando não houver ferramenta nativa.

**Princípio central:** detecte isolamento existente primeiro. Depois use a ferramenta nativa. Depois recaia no git. Nunca brigue com o harness.

> **Fonte de verdade de naming e localização:** a política do projeto está em `.forge/rules/conventions/git-worktree.md`. Esta skill é o **procedimento acionável** que a complementa (detecção de isolamento, tool nativa, setup, baseline). Em caso de divergência, a rule vence.

**Anuncie ao iniciar:** "Estou usando a skill `using-git-worktrees` para preparar um workspace isolado."

---

## Passo 0 — Detectar isolamento existente

**Antes de criar qualquer coisa, verifique se você já está em um workspace isolado.**

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

**Guarda de submódulo:** `GIT_DIR != GIT_COMMON` também é verdadeiro dentro de submódulos git. Antes de concluir "já estou num worktree", confirme que não está num submódulo:

```bash
# Se isto retornar um caminho, você está num submódulo, não num worktree — trate como repo normal
git rev-parse --show-superproject-working-tree 2>/dev/null
```

**Se `GIT_DIR != GIT_COMMON` (e não for submódulo):** você já está em um worktree vinculado. Pule para o Passo 2 (Setup do projeto). **Não** crie outro worktree.

Reporte com o estado da branch:
- Numa branch: "Já estou em workspace isolado em `<path>`, na branch `<nome>`."
- HEAD destacado: "Já estou em workspace isolado em `<path>` (HEAD destacado, gerenciado externamente). Será preciso criar a branch no momento de finalizar."

**Se `GIT_DIR == GIT_COMMON` (ou for submódulo):** você está em um checkout normal do repositório.

O usuário já indicou a preferência de worktree nas instruções (`AGENTS.md`/`CLAUDE.md` ou no pedido)? Se **não**, peça consentimento antes de criar um worktree:

> "Quer que eu prepare um worktree isolado? Ele protege a sua branch atual de qualquer alteração."

Honre qualquer preferência já declarada sem perguntar. Se o usuário recusar, trabalhe no local e pule para o Passo 2.

---

## Passo 1 — Criar o workspace isolado

**Há dois mecanismos. Tente nesta ordem.**

### 1a. Ferramenta de worktree nativa (preferível)

O usuário pediu um workspace isolado (consentimento no Passo 0). Você já tem uma forma nativa de criar um worktree? Pode ser uma tool com nome como `EnterWorktree`/`WorktreeCreate`, um comando `/worktree`, ou uma flag `--worktree`. **Se tiver, use-a e pule para o Passo 2.**

Ferramentas nativas cuidam de posicionamento de diretório, criação de branch e limpeza automaticamente — e neste projeto já posicionam os worktrees sob `.forge/worktrees/`, exatamente a localização canônica da rule. Usar `git worktree add` quando existe uma tool nativa cria estado fantasma que o harness não enxerga nem gerencia.

Só prossiga para o 1b se **não houver** ferramenta nativa de worktree disponível.

### 1b. Fallback: git worktree manual

**Só use isto se o 1a não se aplicar.** Crie o worktree manualmente com git, seguindo a convenção da rule `git-worktree.md`.

#### Localização e nomes (conforme a rule do projeto)

Neste repositório, worktrees são criados **dentro do repo**, sob `.forge/worktrees/<escopo>-<descricao>` — a mesma localização que a ferramenta nativa usa. O diretório `.forge/worktrees/` é **ignorado pelo `.gitignore`** (worktree dentro da árvore de trabalho não pode ser versionado).

- **Worktree local:** `.forge/worktrees/<escopo>-<descricao>` — ex.: `.forge/worktrees/feature-pix-qrcode`, `.forge/worktrees/agent-ledger-fix`. (Sem prefixo de tecnologia, conforme a rule.)
- **Branch:** `<tipo>/<escopo>/<descricao-em-kebab-case>` — ex.: `feat/payments/pix-qrcode-generation`, `fix/finance/ledger-split-rounding`. O `<tipo>` segue os Conventional Commits do projeto (ver `.forge/rules/conventions/conventional-commits.md`).
- **Nunca trabalhar diretamente no `main`.** Toda mudança começa numa branch criada via worktree.
- **Um worktree por tarefa.** Nunca reaproveitar worktree de feature concluída.
- **Agentes de IA sempre em worktree dedicado** — nunca compartilhe worktree com sessão humana.

Se o `AGENTS.md`/`CLAUDE.md` ou o pedido declararem outra localização, honre a preferência explícita — ela vence o padrão.

#### Criar o worktree

```bash
# A partir da raiz do repositório:
git worktree add .forge/worktrees/<escopo>-<descricao> -b "<tipo>/<escopo>/<descricao>"
cd .forge/worktrees/<escopo>-<descricao>

# Exemplo concreto:
# git worktree add .forge/worktrees/feature-pix-qrcode -b feat/payments/pix-qrcode-generation
```

> **Garantia de `.gitignore`:** confirme que `.forge/worktrees/` (ou `.forge/` inteiro) está no `.gitignore` antes de criar. Se não estiver, adicione a entrada primeiro — caso contrário o worktree poluirá o `git status`.

**Fallback de sandbox:** se `git worktree add` falhar com erro de permissão (negação de sandbox), avise o usuário que o sandbox bloqueou a criação do worktree e que você vai trabalhar no diretório atual. Em seguida, rode o setup e o baseline de testes no local.

---

## Passo 2 — Setup do projeto

Detecte a stack automaticamente e rode o setup apropriado:

```bash
# Node.js / TypeScript (monorepo: pode haver vários package.json)
if [ -f package.json ]; then npm install; fi

# .NET
if ls *.sln >/dev/null 2>&1 || ls **/*.csproj >/dev/null 2>&1; then dotnet restore; fi

# Android / Kotlin (Gradle)
if [ -f build.gradle ] || [ -f build.gradle.kts ]; then ./gradlew dependencies >/dev/null; fi

# Go
if [ -f go.mod ]; then go mod download; fi

# Python
if [ -f pyproject.toml ]; then (poetry install 2>/dev/null || pip install -e .); fi
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
```

Se nenhum desses marcadores existir, pule a instalação de dependências.

---

## Passo 3 — Verificar baseline limpo

Rode os testes para garantir que o workspace começa limpo:

```bash
# Use o comando apropriado à stack:
#   npm test  |  dotnet test  |  ./gradlew test  |  go test ./...  |  pytest
```

**Se os testes falharem:** reporte as falhas e pergunte se deve prosseguir ou investigar — não dá para distinguir bug novo de problema pré-existente sem baseline verde.

**Se os testes passarem:** reporte que está pronto.

### Relatório

```
Worktree pronto em <caminho-completo>
Testes passando (<N> testes, 0 falhas)
Pronto para implementar <nome-da-feature>
```

---

## Referência rápida

| Situação | Ação |
|----------|------|
| Já num worktree vinculado | Pular criação (Passo 0) |
| Dentro de um submódulo | Tratar como repo normal (guarda do Passo 0) |
| Tool nativa de worktree disponível | Usá-la (Passo 1a) |
| Sem tool nativa | Fallback git worktree em `.forge/worktrees/` (Passo 1b) |
| Naming / localização | Conforme `git-worktree.md` (`.forge/worktrees/<escopo>-<descricao>`) |
| Erro de permissão na criação | Fallback de sandbox, trabalhar no local |
| Testes falham no baseline | Reportar falhas + perguntar |
| Sem marcador de stack | Pular instalação de dependências |

---

## Erros comuns

### Brigar com o harness
- **Problema:** usar `git worktree add` quando o harness já provê isolamento.
- **Correção:** o Passo 0 detecta isolamento existente; o Passo 1a delega à tool nativa.

### Pular a detecção
- **Problema:** criar um worktree aninhado dentro de um existente.
- **Correção:** sempre rodar o Passo 0 antes de criar qualquer coisa.

### Ignorar a convenção do projeto
- **Problema:** criar o worktree como diretório irmão do repo (`../<escopo>-<descricao>`) quando a rule manda `.forge/worktrees/<escopo>-<descricao>`.
- **Correção:** seguir `git-worktree.md`; criar sempre sob `.forge/worktrees/`; preferência explícita do usuário vence o padrão.

### Prosseguir com testes falhando
- **Problema:** impossível distinguir bug novo de problema pré-existente.
- **Correção:** reportar as falhas e obter permissão explícita para prosseguir.

---

## Sinais de alerta (red flags)

**Nunca:**
- Criar worktree quando o Passo 0 detecta isolamento existente.
- Usar `git worktree add` tendo uma tool nativa de worktree (ex.: `EnterWorktree`). É o erro nº 1 — se você tem, use.
- Pular o Passo 1a indo direto aos comandos git do 1b.
- Criar worktree fora de `.forge/worktrees/` (ex.: diretório irmão do repo).
- Trabalhar diretamente no `main`.
- Pular a verificação do baseline de testes.
- Prosseguir com testes falhando sem perguntar.

**Sempre:**
- Rodar a detecção do Passo 0 primeiro.
- Preferir a tool nativa ao fallback git.
- Seguir naming e localização da rule `git-worktree.md` (`.forge/worktrees/<escopo>-<descricao>`).
- Detectar e rodar o setup do projeto.
- Verificar baseline de testes verde.

---

## Limpeza (após o merge)

Worktrees acumulados consomem espaço e geram confusão. Após o PR ser mergeado:

```bash
git worktree remove .forge/worktrees/<escopo>-<descricao>
git branch -d <tipo>/<escopo>/<descricao>
git worktree prune        # remove referências órfãs
```

Worktrees sem PR aberto há vários dias são candidatos a limpeza.
