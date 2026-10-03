# Verify-build — feat/parcela-minima vs main (strict_mode=false)

**Veredito: REJECTED — a branch NÃO pode seguir para os reviewers LLM ainda.**

A verificação determinística (compilador + test runner) reprovou por teste, mesmo com o modo estrito desligado — que só afeta se warnings de compilação contam como erro, não a passagem dos testes.

- Build: passou (1 warning, irrelevante — feed privado da CodeArtifact inacessível neste ambiente, nada a ver com o diff).
- `dotnet format --verify-no-changes`: reprovou — indentação fora do padrão em `src/Pagamentos.Domain/Pagamento.cs:23`.
- Testes: 2 de 3 falharam em `Pagamentos.Domain.Tests`.
  - `Split_ParcelasZero_LancaDomainException` — o código agora lança `InvalidOperationException`, o teste espera `DomainException`.
  - `Split_DistribuiRestoNasPrimeirasParcelas` — a mesma guard nova (parcela mínima de R$ 5,00) derruba um caminho de split que antes era válido.
- Coverage de `Pagamentos.Domain`: line-rate 0.59 / branch-rate 0.50 — abaixo dos gates (0.95/0.90), mas isso é secundário: os testes já falharam.
- Baseline de enforcement .NET ausente (sem `Directory.Build.props`/`.editorconfig`/`Directory.Packages.props`) — finding HIGH à parte, não é o motivo da reprovação.

Nada foi corrigido no código, conforme pedido — só o veredito. Detalhe estruturado em `outputs/verify-build-output.json`.
