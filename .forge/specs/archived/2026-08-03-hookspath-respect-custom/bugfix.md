# Bugfix — hookspath-respect-custom

## 1. Comportamento atual (incorreto)

`bin/forge.mjs` (nos fluxos `init` e `update`) e `installer/install.sh` sobrescrevem
incondicionalmente `core.hooksPath` para `.forge/hooks/git`, sem checar se o projeto já tem um
valor customizado configurado.

Reprodução real (2 ocorrências no dia 2026-07-09, projeto `axis-go-cloud`, mesmo defeito nas duas
vezes): o repo tinha `core.hooksPath = .githooks` (config intencional pré-existente, não do
Forge). Ao rodar `npx forge-harness update` numa worktree isolada, o comando setou
`core.hooksPath = .forge/hooks/git` — como essa config é global do repo por design do git (fica em
`.git/config`, compartilhado entre worktrees quando `extensions.worktreeConfig` não está
habilitado), o valor customizado do checkout principal foi silenciosamente substituído. Detectado
e revertido manualmente nas duas ocorrências; sem a intervenção, os hooks `.githooks` do projeto
parariam de rodar sem aviso nenhum.

## 2. Comportamento esperado

- `core.hooksPath` **ausente/default** (equivalente a `.git/hooks`) → setar para
  `.forge/hooks/git` (comportamento atual, correto para instalação nova).
- `core.hooksPath` **já `.forge/hooks/git`** → no-op (idempotente).
- `core.hooksPath` **customizado para outro valor** → **preservar**, nunca sobrescrever
  silenciosamente. Emitir uma nota informativa explicando que os hooks do Forge (gate de
  pre-push de docs, guard de pre-commit de worktree) não estão ativos porque um hooksPath
  customizado já existe, com orientação para o usuário decidir (encadear os hooks do Forge no
  script customizado, ou trocar manualmente).

## 3. Comportamento que deve permanecer inalterado

- Instalação nova (`init` em repo sem `core.hooksPath` configurado) continua setando
  `.forge/hooks/git` normalmente — sem regressão no caminho feliz.
- `installer/install.sh` (usado sem Node/npm) segue a mesma regra, para paridade com `bin/forge.mjs`.
- Nenhuma mudança no conteúdo dos hooks em si, só na decisão de *setar ou não* `core.hooksPath`.

## 4. Root cause

`bin/forge.mjs:427-428` (fluxo `init`) e `installer/install.sh:84-85` fazem
`git config core.hooksPath .forge/hooks/git` sem ler o valor atual primeiro — sempre sobrescrevem.
O fluxo `update` (`bin/forge.mjs:281-289`) já lê o valor atual (`cur`), mas usa essa leitura só
para decidir a *mensagem de log* ("era $cur"), não para decidir *se* deve sobrescrever — trata
qualquer valor diferente de `.forge/hooks/git` como "errado a corrigir", presumindo que só existem
dois estados possíveis (`.git/hooks` default, ou `.forge/hooks/git` já correto). Não foi cogitado
um terceiro estado: hooksPath customizado e intencional, alheio ao Forge. Não foi detectado antes
porque os testes existentes (`w13-init-gate`, `w63-forge-update-gate`) só cobrem repos frescos, sem
nenhum tocando um `core.hooksPath` pré-existente não-Forge.

## 5. Testes de regressão

- [ ] Teste que reproduz o bug: repo com `core.hooksPath` customizado (`.githooks`) → rodar
      `init --force`/`update` → hooksPath deve permanecer `.githooks` (falha antes da correção,
      passa depois).
- [ ] Teste do caminho feliz preservado: repo sem `core.hooksPath` (ou já `.forge/hooks/git`) →
      segue setando/mantendo `.forge/hooks/git` normalmente.
- [ ] Nota informativa emitida quando o hooksPath customizado é preservado (mensagem no stdout).

## 6. Rastreabilidade

Achado real durante a propagação de `forge update` (rc9→rc11) aos projetos `axis-go-cloud`,
`axim-crm` e `axis-fare-validator` nesta sessão — 2 ocorrências confirmadas em `axis-go-cloud`
(detectadas e revertidas manualmente pelos agents de propagação em ambas). Sem spec/baseline
anterior relacionado.
