#!/usr/bin/env bash
# Gate W155 — enforcement mecânico da stack .NET: o que o compilador pode provar sai do prompt.
#
# O harness carregava todo o seu conhecimento .NET em prosa — `backend-engineer-dotnet` (26
# seções), `dotnet-reviewer` (7 grupos de checklist), o pack `backend-dotnet-relational`. Prosa
# em contexto longo degrada: a regra fica milhares de tokens atrás competindo com tudo que foi
# lido depois. O compilador não degrada. Este gate cobre a camada que faltava — a que transforma
# convenção em erro de build — e a camada de detecção auditável para o que nenhum analisador vê.
#
# Os três achados que motivam cada asserção:
#   · `TreatWarningsAsErrors` só existia como flag de runtime do `verify-build` (`strict_mode`).
#     Rigor decidido pelo orquestrador na hora não vale para o `dotnet build` do humano.
#   · Severidade dentro de `dotnet_naming_rule` é respeitada por IDE e IGNORADA em build. Um
#     `.editorconfig` cheio de regras de nomenclatura sem `dotnet_diagnostic.IDE1006.severity`
#     é um enforcement que não existe — e ninguém percebe, porque a IDE mostra o squiggle.
#   · `dotnet format` estava declarado "Bloqueante em CI" em `quality-gates.md` e nenhum script
#     do harness o executava. Norma sem verificação determinística.
#
#   [0] guarda de vacuidade: a fixture tem C# de verdade e configs de verdade para medir
#   [1] assets do pack existem, são XML/INI válidos e carregam as propriedades load-bearing
#   [2] `--check` num repo .NET sem baseline FALHA e nomeia os três arquivos ausentes
#   [3] `--apply` cria os três e o `--check` seguinte passa (controle e recontrole)
#   [4] `--apply` não sobrescreve arquivo existente sem `--force`
#   [5] AnalysisMode por modo: brownfield com código → Recommended; greenfield vazio → All
#   [6] a armadilha IDE1006: naming_rule sem dotnet_diagnostic.IDE1006 é FAIL; com ele, OK
#   [7] CPM ligado + PackageReference com Version= no csproj é FAIL; sem Version, OK
#   [8] o scanner emite UMA LINHA POR REGRA inclusive quando não acha nada (omissão visível)
#   [9] o scanner acha no fixture sujo e NÃO acha no fixture limpo (controle e recontrole)
#   [10] o scanner funciona sem ripgrep no PATH (fallback grep) — portabilidade
#   [11] fiação: reviewer, verify-build, doctor, init e PROFILE citam a maquinaria nova
#   [12] frontmatter válido nos artefatos novos
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$WS/template/.forge"
PACK="$ROOT/capabilities/backend-dotnet-relational"
BASELINE="$ROOT/scripts/dotnet-baseline.sh"
SCAN="$ROOT/skills/dotnet-quality-scan/scripts/scan.sh"

T="$(mktemp -d /tmp/forge-w155.XXXXXX)"
trap 'rm -rf "$T"' EXIT

fail() { echo "FAIL $*"; exit 1; }

# ── fixtures ────────────────────────────────────────────────────────────────────────────────
# `dirty`: brownfield com os defeitos que nenhum analisador Roslyn reporta.
# `clean`: a MESMA forma de código sem os defeitos. Sem o par, um scanner que sempre acha
# passaria no gate — foi assim que uma prova de mutação anterior deste harness ficou fantasma.
mk_dirty() {
  local d="$1"; mkdir -p "$d/src/App"
  cat > "$d/src/App/App.csproj" <<'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup>
</Project>
EOF
  cat > "$d/src/App/PaymentHelper.cs" <<'EOF'
using System.Net.Http;

namespace App;

public sealed class PaymentHelper
{
    private readonly HttpClient _http = new HttpClient();

    #region infra

    public async void FireAndForget()
    {
        await Task.Delay(1);
    }

    #endregion

    public string Load(int id)
    {
        var t = Task.FromResult("x");
        return t.Result;
    }

    public void Process(int orderId, bool isRefund)
    {
    }
}
EOF
}

mk_clean() {
  local d="$1"; mkdir -p "$d/src/App"
  cat > "$d/src/App/App.csproj" <<'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup>
</Project>
EOF
  cat > "$d/src/App/PaymentGateway.cs" <<'EOF'
namespace App;

public sealed class PaymentGateway(IHttpClientFactory factory)
{
    public async Task<string> LoadAsync(int id, CancellationToken ct)
    {
        using var client = factory.CreateClient();
        return await client.GetStringAsync($"/orders/{id}", ct);
    }

    public void Process(int orderId) { }

    public void Refund(int orderId) { }
}
EOF
}

# ── [0] guarda de vacuidade ─────────────────────────────────────────────────────────────────
mk_dirty "$T/dirty"; mk_clean "$T/clean"
[ "$(find "$T/dirty" -name '*.cs' | wc -l | tr -d ' ')" -ge 1 ] || fail "[0]: fixture dirty sem .cs"
grep -q 'async void' "$T/dirty/src/App/PaymentHelper.cs" || fail "[0]: fixture dirty perdeu o defeito"
grep -q 'async void' "$T/clean/src/App/PaymentGateway.cs" && fail "[0]: fixture clean não é limpa"
echo "OK [0] fixtures"

# ── [1] assets do pack ──────────────────────────────────────────────────────────────────────
for f in Directory.Build.props Directory.Packages.props editorconfig; do
  [ -f "$PACK/assets/$f" ] || fail "[1]: asset ausente: $PACK/assets/$f"
done
python3 - "$PACK/assets/Directory.Build.props" "$PACK/assets/Directory.Packages.props" <<'PY' || fail "[1]: asset XML inválido"
import sys, xml.etree.ElementTree as ET
for p in sys.argv[1:]:
    ET.parse(p)
PY
for prop in Nullable ImplicitUsings AnalysisLevel AnalysisMode TreatWarningsAsErrors EnforceCodeStyleInBuild; do
  grep -q "<$prop>" "$PACK/assets/Directory.Build.props" || fail "[1]: Directory.Build.props sem <$prop>"
done
grep -q '<ManagePackageVersionsCentrally>true<' "$PACK/assets/Directory.Packages.props" \
  || fail "[1]: Directory.Packages.props sem CPM ligado"
grep -q 'dotnet_diagnostic.IDE1006.severity' "$PACK/assets/editorconfig" \
  || fail "[1]: editorconfig sem IDE1006 (a regra que faz nomenclatura valer em build)"
grep -q 'IncludeAssets' "$PACK/assets/Directory.Build.props" \
  || fail "[1]: analisadores sem IncludeAssets — vazariam para o pacote publicado"
grep -qE 'Version="[^"]*(\*|latest)' "$PACK/assets/Directory.Packages.props" \
  && fail "[1]: versão flutuante no asset — build reprodutível exige versão fixa"
# Sob CPM, PackageReference sem PackageVersion correspondente é NU1010 no restore: o baseline
# entregaria um repositório que não compila, que é o pior default possível para uma adoção.
missing=""
for pkg in $(grep -oE '<PackageReference Include="[^"]+"' "$PACK/assets/Directory.Build.props" \
             | sed -E 's/.*Include="([^"]+)".*/\1/' | sort -u); do
  grep -q "<PackageVersion Include=\"$pkg\"" "$PACK/assets/Directory.Packages.props" || missing="$missing $pkg"
done
[ -z "$missing" ] || fail "[1]: PackageReference sem PackageVersion sob CPM (NU1010):$missing"
echo "OK [1] assets"

# ── [2] check sem baseline falha e nomeia o que falta ───────────────────────────────────────
[ -x "$BASELINE" ] || fail "[2]: $BASELINE ausente ou não executável"
out="$(bash "$BASELINE" --root "$T/dirty" --check 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || fail "[2]: --check passou num repo sem baseline nenhum (rc=0)"
for f in Directory.Build.props Directory.Packages.props .editorconfig; do
  grep -qF "$f" <<<"$out" || fail "[2]: --check não nomeou $f no relatório"
done
echo "OK [2] check vermelho"

# ── [3] apply cria e o check seguinte passa ─────────────────────────────────────────────────
bash "$BASELINE" --root "$T/dirty" --apply >/dev/null 2>&1 || fail "[3]: --apply retornou erro"
for f in Directory.Build.props Directory.Packages.props .editorconfig; do
  [ -f "$T/dirty/$f" ] || fail "[3]: --apply não criou $f"
done
bash "$BASELINE" --root "$T/dirty" --check >/dev/null 2>&1 || fail "[3]: --check ainda falha depois do --apply"
echo "OK [3] apply verde"

# ── [4] apply não sobrescreve sem --force ───────────────────────────────────────────────────
printf '<Project><!-- meu --></Project>\n' > "$T/dirty/Directory.Build.props"
bash "$BASELINE" --root "$T/dirty" --apply >/dev/null 2>&1
grep -q '<!-- meu -->' "$T/dirty/Directory.Build.props" || fail "[4]: --apply sobrescreveu arquivo do projeto sem --force"
bash "$BASELINE" --root "$T/dirty" --apply --force >/dev/null 2>&1 || fail "[4]: --apply --force retornou erro"
grep -q '<!-- meu -->' "$T/dirty/Directory.Build.props" && fail "[4]: --force não sobrescreveu"
echo "OK [4] não-sobrescrita"

# ── [5] AnalysisMode por modo ───────────────────────────────────────────────────────────────
# Brownfield: `All` produz centenas de erros no primeiro build de uma base existente; a adoção
# realista começa em `Recommended`. Greenfield não tem código para quebrar.
mkdir -p "$T/green" && printf '<Project Sdk="Microsoft.NET.Sdk"></Project>\n' > "$T/green/App.csproj"
mk_dirty "$T/brown"
bash "$BASELINE" --root "$T/green" --apply >/dev/null 2>&1 || fail "[5]: apply falhou em greenfield"
bash "$BASELINE" --root "$T/brown" --apply >/dev/null 2>&1 || fail "[5]: apply falhou em brownfield"
grep -q '<AnalysisMode>All<' "$T/green/Directory.Build.props" \
  || fail "[5]: greenfield não recebeu AnalysisMode All"
grep -q '<AnalysisMode>Recommended<' "$T/brown/Directory.Build.props" \
  || fail "[5]: brownfield não recebeu AnalysisMode Recommended (adoção inviável)"
echo "OK [5] modo de análise"

# ── [6] a armadilha IDE1006 ─────────────────────────────────────────────────────────────────
mk_dirty "$T/trap"
cp "$PACK/assets/Directory.Build.props" "$T/trap/Directory.Build.props"
cp "$PACK/assets/Directory.Packages.props" "$T/trap/Directory.Packages.props"
cat > "$T/trap/.editorconfig" <<'EOF'
root = true
[*.cs]
dotnet_naming_rule.async_methods_end_in_async.severity = error
dotnet_naming_rule.async_methods_end_in_async.symbols = async_methods
dotnet_naming_rule.async_methods_end_in_async.style = end_in_async
EOF
out="$(bash "$BASELINE" --root "$T/trap" --check 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || fail "[6]: naming_rule sem IDE1006 passou — a armadilha do artigo não é detectada"
grep -q 'IDE1006' <<<"$out" || fail "[6]: relatório não menciona IDE1006"
printf 'dotnet_diagnostic.IDE1006.severity = error\n' >> "$T/trap/.editorconfig"
bash "$BASELINE" --root "$T/trap" --check >/dev/null 2>&1 || fail "[6]: com IDE1006 declarado o check continua falhando"
echo "OK [6] armadilha IDE1006"

# ── [7] CPM ligado × Version= no csproj ─────────────────────────────────────────────────────
mk_dirty "$T/cpm"
bash "$BASELINE" --root "$T/cpm" --apply >/dev/null 2>&1
bash "$BASELINE" --root "$T/cpm" --check >/dev/null 2>&1 || fail "[7]: controle — check devia passar antes da violação"
cat > "$T/cpm/src/App/App.csproj" <<'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup>
  <ItemGroup><PackageReference Include="Serilog" Version="4.0.0" /></ItemGroup>
</Project>
EOF
out="$(bash "$BASELINE" --root "$T/cpm" --check 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || fail "[7]: Version= no csproj sob CPM passou no check"
grep -qi 'serilog\|Version=' <<<"$out" || fail "[7]: relatório não aponta a referência versionada"
echo "OK [7] CPM"

# ── [8] uma linha por regra, inclusive sem achado ───────────────────────────────────────────
[ -x "$SCAN" ] || fail "[8]: $SCAN ausente ou não executável"
dirty_out="$(bash "$SCAN" --root "$T/dirty" 2>&1)"
clean_out="$(bash "$SCAN" --root "$T/clean" 2>&1)"
n_dirty="$(grep -cE '^(OK|FOUND) ' <<<"$dirty_out")"
n_clean="$(grep -cE '^(OK|FOUND) ' <<<"$clean_out")"
[ "$n_dirty" -ge 6 ] || fail "[8]: scanner emitiu só $n_dirty linhas de regra (esperado >= 6)"
[ "$n_dirty" = "$n_clean" ] \
  || fail "[8]: regra omitida quando não há achado ($n_dirty no sujo vs $n_clean no limpo) — omissão invisível"
grep -q '^OK ' <<<"$clean_out" || fail "[8]: fixture limpa não produziu nenhuma linha OK"
echo "OK [8] relatório completo ($n_dirty regras)"

# ── [9] acha no sujo, não acha no limpo ─────────────────────────────────────────────────────
for rule in async-void region generic-name blocking-wait new-httpclient bool-param; do
  grep -q "^FOUND $rule" <<<"$dirty_out" || fail "[9]: regra '$rule' não achou o defeito plantado"
  grep -q "^FOUND $rule" <<<"$clean_out" && fail "[9]: regra '$rule' acusou falso positivo na fixture limpa"
done
grep -q 'PaymentHelper.cs' <<<"$dirty_out" || fail "[9]: achado sem arquivo:linha — não é auditável"
bash "$SCAN" --root "$T/dirty" >/dev/null 2>&1 && fail "[9]: scanner devolveu rc=0 com achados"
bash "$SCAN" --root "$T/clean" >/dev/null 2>&1 || fail "[9]: scanner devolveu rc!=0 sem achado nenhum"
echo "OK [9] controle e recontrole"

# ── [10] sem ripgrep no PATH ────────────────────────────────────────────────────────────────
# O scanner do artigo é escrito em `rg`. O harness roda em máquinas sem rg — e um scanner que
# emudece quando a ferramenta falta é pior que nenhum: reporta verde por ausência de motor.
stub="$T/stubbin"; mkdir -p "$stub"
for c in bash grep sed awk find cat printf sort head wc tr; do
  p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$stub/$c"
done
norg_out="$(PATH="$stub" bash "$SCAN" --root "$T/dirty" 2>&1)"
grep -q '^FOUND async-void' <<<"$norg_out" || fail "[10]: sem rg no PATH o scanner deixa de achar (falso verde)"
[ "$(grep -cE '^(OK|FOUND) ' <<<"$norg_out")" = "$n_dirty" ] || fail "[10]: sem rg o scanner perde regras"
echo "OK [10] portabilidade"

# ── [11] fiação no lifecycle ────────────────────────────────────────────────────────────────
grep -q 'dotnet-quality-scan' "$ROOT/agents/code-review/dotnet-reviewer.md" \
  || fail "[11]: dotnet-reviewer não invoca a skill determinista"
# Ancorado na LINHA DE COMANDO, não em qualquer menção: citar `--verify-no-changes` na tabela de
# findings deixaria um grep solto verde mesmo com o comando mutilado. Sem a flag, `dotnet format`
# reescreve os arquivos e sai 0 — o gate vira formatação silenciosa.
grep -qE '^[[:space:]]*dotnet format' "$ROOT/skills/verify-build/SKILL.md" \
  || fail "[11]: verify-build não executa dotnet format"
grep -qE '^[[:space:]]*dotnet format[^|]*--verify-no-changes' "$ROOT/skills/verify-build/SKILL.md" \
  || fail "[11]: o comando dotnet format do verify-build não usa --verify-no-changes"
grep -q 'dotnet-baseline' "$ROOT/scripts/doctor.sh" \
  || fail "[11]: doctor não confere o baseline de build .NET"
grep -q 'dotnet-baseline' "$WS/installer/forge-init.md" \
  || fail "[11]: /forge:init não materializa o baseline em projeto .NET"
grep -q 'IDE1006' "$PACK/PROFILE.md" \
  || fail "[11]: PROFILE.md não documenta a armadilha de severidade"
grep -q 'ManagePackageVersionsCentrally\|Central Package Management' "$PACK/PROFILE.md" \
  || fail "[11]: PROFILE.md não documenta CPM"
echo "OK [11] fiação"

# ── [12] frontmatter ────────────────────────────────────────────────────────────────────────
bash "$ROOT/scripts/validate-frontmatter.sh" \
  "$ROOT/skills/dotnet-quality-scan" \
  "$ROOT/agents/code-review/dotnet-reviewer.md" | tail -1 | grep -q '^OK' \
  || fail "[12]: frontmatter inválido nos artefatos novos"
echo "OK [12] frontmatter"

# ── [13] canal de entrega: harness instalado de verdade, doctor de verdade ───────────────────
# [11] prova que o texto está no arquivo; isto prova que o caminho executa. É a distinção da rule
# `testing/gate-delivery-channel.md` — maquinaria presente e maquinaria acionada são estados
# diferentes, e o harness já pagou por confundir os dois (a rede de suítes que ninguém invocava).
I="$T/install"; mkdir -p "$I/src"
printf '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup></Project>\n' > "$I/src/App.csproj"
printf 'namespace App;\npublic sealed class Order { public int Id { get; init; } }\n' > "$I/src/Order.cs"
"$WS/installer/install.sh" --target "$I" --slug fixture --name Fixture --desc fixture --adapters claude >/dev/null 2>&1 \
  || fail "[13]: instalação do harness falhou no alvo .NET"
[ -x "$I/.forge/scripts/dotnet-baseline.sh" ] || fail "[13]: dotnet-baseline.sh não foi instalado no alvo"
[ -f "$I/.forge/capabilities/backend-dotnet-relational/assets/Directory.Build.props" ] \
  || fail "[13]: assets do pack não foram instalados no alvo"
[ -x "$I/.claude/skills/dotnet-quality-scan/scripts/scan.sh" ] \
  || fail "[13]: scan.sh não chegou executável ao adapter (skill projetada sem o motor não roda)"

out="$(cd "$I" && bash .forge/scripts/doctor.sh --report 2>&1)"; status=$?
grep -q 'baseline de build' <<<"$out" || fail "[13]: doctor instalado não reporta o baseline de build"
[ "$status" -eq 0 ] || fail "[13]: doctor passou a reprovar por causa do baseline (deve informar, não bloquear: rc=$status)"

bash "$I/.forge/scripts/dotnet-baseline.sh" --root "$I" --apply >/dev/null 2>&1 \
  || fail "[13]: apply falhou a partir do harness instalado"
out2="$(cd "$I" && bash .forge/scripts/doctor.sh --report 2>&1)"
grep -qE '(✓|OK).*baseline de build' <<<"$out2" \
  || fail "[13]: depois do apply o doctor continua acusando baseline incompleto"
grep -q 'baseline de build incompleto' <<<"$out2" \
  && fail "[13]: doctor não reflete o estado novo — a linha de incompleto sobreviveu ao apply"
echo "OK [13] canal de entrega"

echo "PASS w155-dotnet-enforcement-gate"
