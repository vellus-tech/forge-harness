#!/usr/bin/env bash
# Fixture compartilhada do gate w141 (issue #38) — reproduz os TRÊS layouts .NET reais medidos
# no repositório poliglota da issue, mais um layout de frontend. Sem FORGE.md: quem declara a
# configuração é o cenário do gate, para que a MESMA árvore sirva de prova de compatibilidade
# (sem config → grafo de hoje) e de prova do mapa declarado (com config → camadas corretas).
#
# Uso: bash make-fixture.sh <dir-destino>
set -uo pipefail
D="${1:-}"
[ -n "$D" ] || { echo "FAIL (uso: make-fixture.sh <dir>)"; exit 1; }

# ── Layout A — plataforma satélite: <raiz>/src/services/<svc>/<Ns>.<Camada> ──────────────
mkdir -p "$D/platform/src/services/billing/Contoso.Billing.Api" \
         "$D/platform/src/services/billing/Contoso.Billing.Handlers" \
         "$D/platform/src/shared/Contoso.Shared.Persistence" \
         "$D/platform/src/shared/Contoso.Shared.Kernel"
cat > "$D/platform/src/shared/Contoso.Shared.Kernel/Guard.cs" <<'EOF'
namespace Contoso.Shared.Kernel;
public static class Guard { public static void NotNull(object o) { } }
EOF
cat > "$D/platform/src/shared/Contoso.Shared.Persistence/InvoiceRepository.cs" <<'EOF'
using Contoso.Shared.Kernel;
namespace Contoso.Shared.Persistence;
public class InvoiceRepository { public void Save(object i) => Guard.NotNull(i); }
EOF
cat > "$D/platform/src/services/billing/Contoso.Billing.Handlers/IssueInvoiceHandler.cs" <<'EOF'
using Contoso.Shared.Persistence;
namespace Contoso.Billing.Handlers;
public class IssueInvoiceHandler { private readonly InvoiceRepository _r = new(); }
EOF
cat > "$D/platform/src/services/billing/Contoso.Billing.Api/InvoiceController.cs" <<'EOF'
using Contoso.Billing.Handlers;
namespace Contoso.Billing.Api;
public class InvoiceController { private readonly IssueInvoiceHandler _h = new(); }
EOF
# marcador de assembly resolvido por reflexão — órfão POR DESIGN (nada o importa, nada ele importa)
cat > "$D/platform/src/services/billing/Contoso.Billing.Api/AssemblyMarker.cs" <<'EOF'
namespace Contoso.Billing.Api.Marker;
public interface IBillingAssemblyMarker { }
EOF

# ── Layout B — pacotes compartilhados: packages/dotnet/<Ns> ───────────────────────────────
mkdir -p "$D/packages/dotnet/Contoso.Messaging.Abstractions" "$D/packages/dotnet/Contoso.Sdk"
cat > "$D/packages/dotnet/Contoso.Messaging.Abstractions/IBus.cs" <<'EOF'
namespace Contoso.Messaging.Abstractions;
public interface IBus { void Publish(object m); }
EOF
cat > "$D/packages/dotnet/Contoso.Sdk/BillingClient.cs" <<'EOF'
using Contoso.Messaging.Abstractions;
namespace Contoso.Sdk;
public class BillingClient { private IBus _bus; }
EOF

# ── Layout C — monólito legado pré-Clean-Architecture: src/<Produto>.<Camada> ─────────────
mkdir -p "$D/legacy/src/Produto.Entidades" "$D/legacy/src/Produto.BLL" \
         "$D/legacy/src/Produto.DAL/Migrations" "$D/legacy/src/Produto.Web"
cat > "$D/legacy/src/Produto.Entidades/Pedido.cs" <<'EOF'
namespace Produto.Entidades;
public class Pedido { public int Id { get; set; } }
EOF
cat > "$D/legacy/src/Produto.DAL/PedidoDao.cs" <<'EOF'
using Produto.Entidades;
namespace Produto.DAL;
public class PedidoDao { public Pedido Get(int id) => new Pedido(); }
EOF
cat > "$D/legacy/src/Produto.BLL/PedidoService.cs" <<'EOF'
using Produto.DAL;
namespace Produto.BLL;
public class PedidoService { private readonly PedidoDao _dao = new PedidoDao(); }
EOF
cat > "$D/legacy/src/Produto.Web/PedidoPage.cs" <<'EOF'
using Produto.BLL;
namespace Produto.Web;
public class PedidoPage { private readonly PedidoService _s = new PedidoService(); }
EOF
# migration descoberta por varredura de assembly — órfã POR DESIGN
cat > "$D/legacy/src/Produto.DAL/Migrations/001_CriaPedido.cs" <<'EOF'
namespace Produto.DAL.Migrations;
public class CriaPedido { public void Up() { } }
EOF
# código morto de verdade — órfão SUSPEITO (é este que o warning tem de apontar)
cat > "$D/legacy/src/Produto.BLL/CalculadoraObsoleta.cs" <<'EOF'
namespace Produto.BLL.Obsoleto;
public class CalculadoraObsoleta { public int Somar(int a, int b) => a + b; }
EOF

# ── Layout D — frontend (fora da taxonomia domain/application/infrastructure/api/contracts) ─
mkdir -p "$D/apps/web/src/components" "$D/apps/web/src/pages" "$D/apps/web/e2e" "$D/tools/codegen"
cat > "$D/apps/web/src/components/Button.tsx" <<'EOF'
export const Button = () => null;
EOF
cat > "$D/apps/web/src/pages/Home.tsx" <<'EOF'
import { Button } from '../components/Button';
export default function Home() { return Button; }
EOF
# spec de E2E de browser — órfã POR DESIGN (não importa código de produção)
cat > "$D/apps/web/e2e/checkout.spec.ts" <<'EOF'
export const scenario = 'checkout end to end';
EOF
# tooling — órfão POR DESIGN quando declarado fora da taxonomia
cat > "$D/tools/codegen/gen.mjs" <<'EOF'
export function gen() { return 1; }
EOF
