# Epic context — add-liaison-native-bridge

Objetivo: a mensageria nativa entre sessões do Claude Code (`SendMessage`/`ListAgents`) vira campainha e o liaison continua sendo o registro durável. O change entrega o ponteiro canônico (`notify`), o registro do que chega (`send --via cross-session`, origem extraída do transcript pela tag e conferida pelo registro de sessões), o gancho `PreToolUse` `guard-cross-session-send.sh` (segredo, destino declarado e contenção por workspace), o diagnóstico de cobertura (`native check`/`native dispose`, fiado em `SessionEnd`/`SessionStart`), e o cadastro humano de workspaces (`native allow|revoke|pin`) com um detector único de mudanças de contenção (`native containment`) chamado por pre-push, doctor, `/forge:prepare-pr` e `/forge:ship` (merge com mudança de contenção é sempre humano, inclusive em yolo).

Decisões-chave do design aprovado: classificação de destino pelo registro `~/.claude/sessions/<pid>.json` (fail-closed para o que não resolve, `nome [ref]` sempre bloqueado); a tag `cross-session-message` é a fonte dos campos e do fingerprint, o objeto `origin` só confere; cadastro efetivo é o commitado no `HEAD` do tronco, em `.forge/liaison/allowed-workspaces.json` com schema próprio; `hook-unwired` pela derivação de `derivePreToolUseHooks`; a contenção é proteção contra liberação induzida, não fronteira de segurança (a configuração gerenciada do Claude Code é a única fronteira, recomendada para PCI).

Contratos: envelope `liaison-message.schema.json` ganha `via: cross-session` e o objeto `cross_session` (aditivo, compatível com peer v0.18.0); linha nova em `hooks.manifest.default`; subcomandos novos do `liaison-ops.sh`.

Rules aplicáveis: `liaison-protocol.md`, `liaison-untrusted-input.md`, `autonomy-yolo.md`, `testing/regression-red-first.md`. Nenhuma ADR vigente é afetada; ADR sugerida no design §10 fica como item de ledger (TASK-23).

Restrições: NFR-01 (gancho ≤ 300 ms p95), NFR-02 (zero dependência nova), NFR-03 (gate vermelho antes da implementação). Nenhum script ou gancho invoca o CLI do Claude Code nem conecta no socket de sessão.
