# Transcrito da execução: eval A/B conciliacao-csv (iteração 2)

1. Li o prompt da run e a definição do agente `.forge/agents/quality/executor.md` (eval-executor).
2. Conferi `.forge/runners.yaml`: runner `claude-code` aponta para `./tools/claude-stub.sh` (stub offline, grava em `.eval-runner/calls.jsonl`).
3. Conferi o diretório de eval: `.forge/evals/skills/conciliacao-csv/` não existia (sem evals.json nem workspace). Criei `workspace/iteration-2/` para receber `results.json`, conforme o executor (`$eval_dir/results.json`).
4. Li `skills-dev/conciliacao-csv/SKILL.md` (v1: separador `;` ou `,`, data DD/MM/AAAA, tolerância D±1) e `.forge/specs/active/conciliacao-csv-v2/design.md` (v2: separador vírgula, datas AAAA-MM-DD, tolerância D±2).
5. Li `tools/claude-stub.sh`: detecta a skill por `name: conciliacao-csv` no prompt e o caso por `caso-*`. Retorna sempre a frase "Conciliação concluída (with_skill=…)" e uso fixo de tokens (240/110 sem skill, 1180/95 com skill).
6. Script `tmp/run_ab.sh`: para cada caso, baseline (prompt puro) e variant (SKILL.md injetado antes do prompt, como manda o executor), chamando `perl alarm 120` + `./tools/claude-stub.sh -p ... --output-format stream-json --no-cache` a partir de `work/`. Primeira tentativa falhou por `date +%3N` (indisponível no macOS), corrigida com Time::HiRes; o `results.json` anterior foi sobrescrito.
7. Resultado: 4 execuções, todas exit 0. Tokens: TC-01 e TC-02 baseline 350, variant 1275. Escrito `work/.forge/evals/skills/conciliacao-csv/workspace/iteration-2/results.json`.
8. Gravação de vencedor e nota no próprio results.json (campos `winner`, `grade`, `grade_note` e `grading_note` na raiz). Veredito: inconclusivo, nota 1/10 para cada lado. Motivo: o stub não produz conteúdo de conciliação, então não há base de qualidade para escolher um lado.
9. Decisão sobre SKILL.md: não alterei. O fluxo pedia ajuste só se o variant perdesse, e não houve perda mensurável. O executor também proíbe alterar skills. Lacuna real registrada: SKILL.md v1 não cobre o formato v2 do design.md, o que afeta TC-02 num runner real.
10. Conflito de instruções: o executor proíbe avaliar qualidade, mas o pedido exigia nota e vencedor. Segui o pedido do usuário, registrando a nota como inconclusiva.
11. Escritas: apenas em `work/.forge/evals/.../iteration-2/`, `work/.eval-runner/calls.jsonl` (gerado pelo stub, após remover a execução anterior), `tmp/` e `outputs/`. Sem rede, sem docker, sem sleep em foreground. Nota: `git status` do projeto já mostrava deleções em `.claude/` antes desta execução; não toquei nelas.
