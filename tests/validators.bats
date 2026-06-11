#!/usr/bin/env bats
# W3.1 — deterministic validators suite (§19.1–§19.4): at least one PASS and one
# FAIL case per rule family. Heavier E2E lives in the w3x gate scripts.

setup_file() {
  export WS="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export T="$(mktemp -d /tmp/forge-w31.XXXXXX)"
  cp -R "$WS/template/.forge" "$T/.forge"
  export SN="$T/.forge/scripts/spec-new.sh" TR="$T/.forge/scripts/spec-transition.sh"
  export AL="$T/.forge/scripts/approval-log.sh" VS="$T/.forge/scripts/validate-spec.sh"
  export VF="$T/.forge/scripts/spec-verify.sh" VA="$T/.forge/scripts/validate-archive.sh"

  # base change at tasks-ready (scale 2) for spec rules
  (cd "$T" && bash "$SN" base-ok --type feature --scale 2 >/dev/null \
    && bash "$TR" base-ok requirements-ready >/dev/null \
    && bash "$TR" base-ok design-ready >/dev/null \
    && bash "$TR" base-ok tasks-ready >/dev/null)

  # archive-ready change (scale 0): verified + delta payload + approval gate
  (cd "$T" && bash "$SN" arch-ok --type feature --scale 0 >/dev/null \
    && bash "$TR" arch-ok tasks-ready >/dev/null \
    && bash "$TR" arch-ok implementing >/dev/null)
  perl -pi -e 's/^(\s*)- \[ \] /$1- [X] /' "$T/.forge/specs/active/arch-ok/tasks.md"
  (cd "$T" && bash "$TR" arch-ok implemented >/dev/null && bash "$VF" arch-ok >/dev/null \
    && bash "$AL" arch-ok --gate implementation_verified --decision approve >/dev/null \
    && bash "$TR" arch-ok verified >/dev/null \
    && bash "$AL" arch-ok --gate human_archive_approval --decision approve >/dev/null)
  cat > "$T/.forge/specs/active/arch-ok/spec-delta.yaml" <<'EOF'
operations:
  - op: add_requirement
    capability: sampling
    requirement_id: REQ-SMP-001
    content_ref: proposal.md#2
    requirement:
      id: REQ-SMP-001
      title: Sample requirement
      normative: SHALL
      scenarios:
        - id: SCN-SMP-001-A
          given: "a precondition"
          when: "an action happens"
          then: "an outcome is observable"
EOF
}

teardown_file() { rm -rf "$T"; }

clone_change() { # clone_change <src> <dst>
  cp -R "$T/.forge/specs/active/$1" "$T/.forge/specs/active/$2"
  perl -pi -e "s/^id: $1\$/id: $2/" "$T/.forge/specs/active/$2/manifest.yaml"
}

# ── §19.2 validate-spec ───────────────────────────────────────────────────────

@test "19.2 PASS: change template completo em tasks-ready" {
  run bash "$VS" --path "$T/.forge/specs/active/base-ok"
  [ "$status" -eq 0 ]
}

@test "19.2 FAIL: placeholder <CHANGE_*> órfão" {
  clone_change base-ok spec-orphan
  echo 'restos de template: <CHANGE_ID>' >> "$T/.forge/specs/active/spec-orphan/proposal.md"
  run bash "$VS" --path "$T/.forge/specs/active/spec-orphan"
  [ "$status" -eq 1 ]; [[ "$output" == *"orphan template placeholder"* ]]
}

@test "19.2 FAIL: NEEDS CLARIFICATION bare em requirements-ready+ (backticks são instrucionais)" {
  clone_change base-ok spec-clarify
  echo 'Limite de retentativas: NEEDS CLARIFICATION' >> "$T/.forge/specs/active/spec-clarify/requirements.md"
  run bash "$VS" --path "$T/.forge/specs/active/spec-clarify"
  [ "$status" -eq 1 ]; [[ "$output" == *"unresolved NEEDS CLARIFICATION"* ]]
}

@test "19.2 FAIL: proposal sem a seção '## 2.'" {
  clone_change base-ok spec-noheading
  perl -pi -e 's/^## 2\..*$/## Outra coisa/' "$T/.forge/specs/active/spec-noheading/proposal.md"
  run bash "$VS" --path "$T/.forge/specs/active/spec-noheading"
  [ "$status" -eq 1 ]; [[ "$output" == *'missing section "## 2."'* ]]
}

@test "19.2 FAIL: requirements sem critérios de aceite (testabilidade)" {
  clone_change base-ok spec-notest
  perl -pi -e 's/Critérios de aceite//gi' "$T/.forge/specs/active/spec-notest/requirements.md"
  run bash "$VS" --path "$T/.forge/specs/active/spec-notest"
  [ "$status" -eq 1 ]; [[ "$output" == *"acceptance criteria"* ]]
}

@test "19.2 traceability: PASS coerente; FAIL task inexistente" {
  clone_change base-ok spec-trace
  cat > "$T/.forge/specs/active/spec-trace/traceability.yaml" <<'EOF'
traceability:
  - requirement_id: REQ-01
    tasks:
      - TASK-01
EOF
  run bash "$VS" --path "$T/.forge/specs/active/spec-trace"
  [ "$status" -eq 0 ]
  cat > "$T/.forge/specs/active/spec-trace/traceability.yaml" <<'EOF'
traceability:
  - requirement_id: REQ-01
    tasks:
      - TASK-99
EOF
  run bash "$VS" --path "$T/.forge/specs/active/spec-trace"
  [ "$status" -eq 1 ]; [[ "$output" == *"TASK-99 not found"* ]]
}

@test "19.2 FAIL: spec-delta com op inválida" {
  clone_change base-ok spec-badop
  printf 'operations:\n  - op: rename_requirement\n' > "$T/.forge/specs/active/spec-badop/spec-delta.yaml"
  run bash "$VS" --path "$T/.forge/specs/active/spec-badop"
  [ "$status" -eq 1 ]; [[ "$output" == *"op invalid"* ]]
}

# ── §19.1 validate-harness ────────────────────────────────────────────────────

@test "19.1 PASS em instalação fresca; FAIL com leak .claude plantado" {
  H="$(mktemp -d /tmp/forge-w31h.XXXXXX)"
  "$WS/installer/install.sh" --target "$H" --slug fix-harness --name "Fix" --desc "w31" >/dev/null
  run bash "$H/.forge/scripts/validate-harness.sh"
  [ "$status" -eq 0 ]
  echo 'referencia suja: .claude/agents/x.md' >> "$H/.forge/rules/README.md"
  run bash "$H/.forge/scripts/validate-harness.sh"
  [ "$status" -eq 1 ]
  rm -rf "$H"
}

# ── §19.3 validate-archive ────────────────────────────────────────────────────

@test "19.3 FAIL: status != verified" {
  run bash "$VA" --path "$T/.forge/specs/active/base-ok"
  [ "$status" -eq 1 ]; [[ "$output" == *"status must be verified"* ]]
}

@test "19.3 FAIL: delta sem payload estruturado" {
  clone_change arch-ok arch-nopayload
  cat > "$T/.forge/specs/active/arch-nopayload/spec-delta.yaml" <<'EOF'
operations:
  - op: add_requirement
    capability: sampling
    requirement_id: REQ-SMP-001
    content_ref: proposal.md#2
EOF
  run bash "$VA" --path "$T/.forge/specs/active/arch-nopayload"
  [ "$status" -eq 1 ]; [[ "$output" == *"requirement' payload missing"* ]]
}

@test "19.3 FAIL: human_archive_approval false" {
  clone_change arch-ok arch-nogate
  perl -pi -e 's/^(  human_archive_approval): true$/$1: false/' "$T/.forge/specs/active/arch-nogate/manifest.yaml"
  run bash "$VA" --path "$T/.forge/specs/active/arch-nogate"
  [ "$status" -eq 1 ]; [[ "$output" == *"human_archive_approval"* ]]
}

@test "19.3 PASS: change archive-ready completo" {
  run bash "$VA" --path "$T/.forge/specs/active/arch-ok"
  [ "$status" -eq 0 ]
}

@test "19.3 FAIL: docs/product editado à mão vs publish.lock" {
  mkdir -p "$T/.forge/cache" "$T/docs/product"
  echo "conteudo publicado" > "$T/docs/product/sample.md"
  H="$(shasum -a 256 "$T/docs/product/sample.md" | cut -d' ' -f1)"
  printf '%s  %s\n' "$H" "docs/product/sample.md" > "$T/.forge/cache/publish.lock"
  run bash "$VA" --path "$T/.forge/specs/active/arch-ok"
  [ "$status" -eq 0 ]
  echo "edicao manual" >> "$T/docs/product/sample.md"
  run bash "$VA" --path "$T/.forge/specs/active/arch-ok"
  [ "$status" -eq 1 ]; [[ "$output" == *"without baseline origin"* ]]
  rm -f "$T/.forge/cache/publish.lock"
}

# ── §19.4 validate-frontmatter ────────────────────────────────────────────────

@test "19.4 FAIL: agent sem description; WARN-only: corpo > 500 linhas" {
  F="$(mktemp -d /tmp/forge-w31f.XXXXXX)"
  mkdir -p "$F/agents"
  printf -- '---\nname: broken\n---\n# x\n' > "$F/agents/broken.md"
  run bash "$T/.forge/scripts/validate-frontmatter.sh" "$F/agents"
  [ "$status" -eq 1 ]
  printf -- '---\nname: long\ndescription: agente valido com corpo longo\n---\n' > "$F/agents/long.md"
  rm "$F/agents/broken.md"
  for i in $(seq 1 510); do echo "linha $i"; done >> "$F/agents/long.md"
  run bash "$T/.forge/scripts/validate-frontmatter.sh" "$F/agents"
  [ "$status" -eq 0 ]; [[ "$output" == *"WARN"*"500"* ]]
  rm -rf "$F"
}
