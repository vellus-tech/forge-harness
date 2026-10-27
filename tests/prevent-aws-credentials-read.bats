#!/usr/bin/env bats
# ORQ-20261027-105: gancho PreToolUse (Bash e Read) que bloqueia leitura de
# ~/.aws/credentials, ~/.aws/config, ~/.aws/sso/cache/* e ~/.aws/cli/cache/*. Medido três vezes
# em dois dias em sessões peer diferentes, sempre ao depurar Terraform sem credencial - a regra
# em memória não é mecânica, então vira gancho. Casos que precisam bloquear (com e sem aspas,
# por $HOME, por ~ e por caminho absoluto) e casos legítimos que não podem bloquear
# (aws configure list/list-profiles, aws sts get-caller-identity, menção do caminho em texto de
# commit/PR/heredoc de documentação).

setup_file() {
  export HOOK="$BATS_TEST_DIRNAME/../template/.forge/hooks/pre-tool-use/prevent-aws-credentials-read.sh"
  [ -x "$HOOK" ] || chmod +x "$HOOK"
}

rodar() {
  # $1 = JSON do payload do PreToolUse.
  run bash -c 'printf "%s" "$1" | bash "$HOOK"' -- "$1"
}

json_bash() {
  # $1 = comando. Escapa para JSON via python3 (evita escaping manual de aspas no .bats).
  python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1"
}

json_read() {
  python3 -c 'import json,sys; print(json.dumps({"tool_name":"Read","tool_input":{"file_path":sys.argv[1]}}))' "$1"
}

# --- casos que PRECISAM bloquear --------------------------------------------------------------

@test "bloqueia: cat com HOME entre aspas duplas" {
  rodar "$(json_bash 'cat "$HOME/.aws/credentials"')"
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOQUEADO"* ]]
  [[ "$output" == *"aws configure list"* ]]
  [[ "$output" == *"aws sts get-caller-identity"* ]]
}

@test "bloqueia: cat com caminho absoluto entre aspas simples" {
  rodar "$(json_bash "cat '/Users/milton/.aws/credentials'")"
  [ "$status" -eq 2 ]
}

@test "bloqueia: cat com til, sem aspas nenhuma" {
  rodar "$(json_bash 'cat ~/.aws/credentials')"
  [ "$status" -eq 2 ]
}

@test "bloqueia: grep no config" {
  rodar "$(json_bash 'grep -A2 profile ~/.aws/config')"
  [ "$status" -eq 2 ]
}

@test "bloqueia: head no sso/cache" {
  rodar "$(json_bash 'head -c 200 ~/.aws/sso/cache/abc123.json')"
  [ "$status" -eq 2 ]
}

@test "bloqueia: cp do cli/cache para /tmp" {
  rodar "$(json_bash 'cp ~/.aws/cli/cache/x.json /tmp/x.json')"
  [ "$status" -eq 2 ]
}

@test "bloqueia: base64 do credentials" {
  rodar "$(json_bash 'base64 "${HOME}/.aws/credentials"')"
  [ "$status" -eq 2 ]
}

@test "bloqueia: python lendo o credentials" {
  rodar "$(json_bash "python3 -c \"print(open('/Users/x/.aws/credentials').read())\"")"
  [ "$status" -eq 2 ]
}

@test "bloqueia: yq no config" {
  rodar "$(json_bash 'yq eval ".default" ~/.aws/config')"
  [ "$status" -eq 2 ]
}

@test "bloqueia: Read direto em ~/.aws/credentials (caminho absoluto resolvido)" {
  rodar "$(json_read "/Users/milton/.aws/credentials")"
  [ "$status" -eq 2 ]
}

@test "bloqueia: Read direto em ~/.aws/config" {
  rodar "$(json_read "/home/ci/.aws/config")"
  [ "$status" -eq 2 ]
}

@test "bloqueia: Read em arquivo dentro de sso/cache" {
  rodar "$(json_read "/Users/milton/.aws/sso/cache/token.json")"
  [ "$status" -eq 2 ]
}

# --- casos legítimos que NÃO PODEM bloquear ---------------------------------------------------

@test "libera: aws configure list" {
  rodar "$(json_bash 'aws configure list')"
  [ "$status" -eq 0 ]
}

@test "libera: aws configure list-profiles" {
  rodar "$(json_bash 'aws configure list-profiles')"
  [ "$status" -eq 0 ]
}

@test "libera: aws sts get-caller-identity" {
  rodar "$(json_bash 'aws sts get-caller-identity')"
  [ "$status" -eq 0 ]
}

@test "libera: git commit mencionando o caminho em texto" {
  rodar "$(json_bash 'git commit -m "corrigi leitura indevida de ~/.aws/credentials no script"')"
  [ "$status" -eq 0 ]
}

@test "libera: heredoc de documentacao mencionando o caminho (cat so monta o corpo, nao le arquivo)" {
  comando=$'ghx pr-sim --title demo --body "$(cat <<\'BODYEOF\'\n## Resumo\nCorrigi um caso onde a sessao lia ~/.aws/credentials direto.\nBODYEOF\n)"'
  rodar "$(json_bash "$comando")"
  [ "$status" -eq 0 ]
}

@test "libera: ls no diretorio .aws (ls nao esta na lista de leitores)" {
  rodar "$(json_bash 'ls -la ~/.aws/')"
  [ "$status" -eq 0 ]
}

@test "libera: Read em arquivo comum, fora de .aws" {
  rodar "$(json_read "/Users/milton/Documents/notas.md")"
  [ "$status" -eq 0 ]
}

@test "libera: cat em arquivo .aws que nao e credentials/config/sso-cache/cli-cache" {
  rodar "$(json_bash 'cat ~/.aws/outro-arquivo.txt')"
  [ "$status" -eq 0 ]
}

# --- fail-closed -------------------------------------------------------------------------------

@test "fail-closed: payload vazio no stdin bloqueia" {
  run bash "$HOOK" < /dev/null
  [ "$status" -eq 2 ]
  [[ "$output" == *"fail-closed"* ]]
}

@test "fail-closed: JSON malformado bloqueia" {
  run bash -c 'printf "%s" "{nao e json" | bash "$HOOK"'
  [ "$status" -eq 2 ]
}
