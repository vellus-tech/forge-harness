# Política de sync: workspace → template global (v0.1.0)

Como propagar atualizações do harness para projetos e para o `/init-project` global.

## Fontes

- **Fonte de verdade do harness:** `forge-harness/template/.forge/` (este repo).
- **Release congelado:** tag `v0.1.0` — o que o `/init-project` global instala.
- **Snapshot de contrato:** `snapshot/project-bootstrap/` — referência imutável do adapter Claude
  (gate `tests/snapshot/verify-manifest.sh` + `claude-contract.bats` source mode).

## Quando propagar

1. Mudança no `template/.forge/**` entra por wave + gate verde (`tests/run-all.sh` 100%).
2. Merge em `develop` → `main`.
3. **Cortar/mover o tag** de release (`v0.x.y`) no `main` quando a mudança for liberada.
4. O `/init-project` global aponta para o tag — novos projetos recebem a versão liberada.

## Como atualizar um projeto já onboarded

Não há `forge update` ainda (achado **W2-A** dos pilotos). Procedimento manual até existir:

1. Branch + snapshot do estado atual (`git commit -am "wip: pre-update"`).
2. Preservar estado do projeto: `FORGE.md`, `forge.yaml`, `.forge/product/`, `.forge/specs/`,
   `.forge/custom/`, `constitution.md`, `context.md` e rules editadas.
3. Remover a maquinaria (`.forge` machinery, `.claude`, `AGENTS.md`, `CLAUDE.md`, `QWEN.md`).
4. Reinstalar do tag: `installer/install.sh --target <proj> --slug … --name … --desc …`.
5. Re-aplicar os hand-edits de estado e re-`sync-adapters --set <lista>`.
6. `doctor` limpo + `validate-spec` no baseline.

Validado no piloto W8.2 (azim-crm). Um `forge update` que automatize isto é change candidato pós-v0.1.0.

## Versionamento

O harness segue **SemVer 2.0.0**. A regra abaixo existe porque a prática divergiu dela: entre
2026-06-12 e 2026-07-29 saíram **24 tags `v0.1.0-rc*`** e nenhum `0.1.0`. Formalmente
`0.1.0-rc24` é SemVer válido — o hífen introduz um identificador de pré-lançamento e a precedência
está bem definida. O problema é semântico: um *release candidate* é, por definição, candidato a
virar o release, e vinte e quatro candidatos significam que cada `rc` virou release de
desenvolvimento com nome de candidato.

O custo disso é concreto. O número da versão deveria responder **o que mudou e o que pode
quebrar**, e `rc23 → rc24` não responde: aquele incremento carregou o Red-first, o subsistema
liaison inteiro e a proibição de assinatura de IA — três features — sob a mesma forma que uma
correção de typo teria. Quem lê o carimbo `template_version` num projeto adotante não consegue
inferir se a atualização é segura.

**A partir de `v0.2.0`:**

| Mudança | Incremento | Exemplo |
|---|---|---|
| Feature nova, subsistema novo, capability nova | `MINOR` (`0.x`) | liaison, Red-first, harness de PBT |
| Correção, ajuste de gate, doc | `PATCH` | sincronizar a versão do marketplace |
| Quebra da superfície de `.forge/` que exige ação do adotante | `MINOR` em `0.x` — **com nota explícita** no CHANGELOG | remoção de comando, mudança de formato do `forge.yaml` |
| Validação antes de um release que se quer estável | `-rc<N>`, **um ou dois**, nunca uma série | `0.3.0-rc1` |

`0.x.y` declara, por SemVer, que a superfície pública é instável e pode quebrar — o que é honesto
enquanto `MACHINERY_DIRS`, o formato do `forge.yaml` e os schemas ainda mudam de forma. **`1.0.0`
sai quando a superfície de `.forge/` for algo que o projeto se compromete a não quebrar sem aviso**,
não quando "parecer maduro".

Ganho prático imediato: com faixas `MINOR` distintas, uma instrução de migração passa a ter
endereço. `LDG-0009` (repos com o managed-block do `.gitignore` congelado) vira "reconcilie ao
subir de `0.1.x` para `0.2.x`", em vez de "reconcilie em algum ponto entre `rc17` e `rc24`".

## Guarda

- `tests/snapshot/verify-manifest.sh` → snapshot íntegro.
- `tests/run-all.sh` → suíte 100% antes de mover qualquer tag.
- O `package.json`, o `plugin/forge/.claude-plugin/plugin.json` e o `.claude-plugin/marketplace.json`
  precisam declarar a **mesma** versão — conferido por `tests/plugin-sync-gate.sh`, e sincronizado
  automaticamente por `npm run build:plugin` (o marketplace já saiu uma versão atrás por ser passo
  manual atrelado a bump).
