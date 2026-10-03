using Dapper;
using Npgsql;

namespace BillingApi.Endpoints;

public static class InvoiceEndpoints
{
    // Envelope de erro legado exigido pela ADR-0004 (apps mobile fazem parse dele).
    public static IResult Error(int status, string code, string message) =>
        Results.Json(new { error = new { code, message } }, statusCode: status);

    public static void Map(WebApplication app)
    {
        app.MapGet("/invoices/{id:guid}", async (Guid id, HttpContext ctx, NpgsqlDataSource db, CancellationToken ct) =>
        {
            var tenantId = ctx.Request.Headers["X-Tenant-Id"].ToString();
            await using var conn = await db.OpenConnectionAsync(ct);
            var invoice = await conn.QuerySingleOrDefaultAsync(
                new CommandDefinition(
                    "SELECT id, tenant_id, amount_cents, status FROM invoices WHERE id = @id AND tenant_id = @tenantId",
                    new { id, tenantId }, cancellationToken: ct));
            return invoice is null ? Error(404, "invoice_not_found", "Fatura não encontrada") : Results.Ok(invoice);
        });

        app.MapGet("/invoices/{id:guid}/pdf-status", async (Guid id, HttpContext ctx, NpgsqlDataSource db, CancellationToken ct) =>
        {
            var tenantId = ctx.Request.Headers["X-Tenant-Id"].ToString();
            await using var conn = await db.OpenConnectionAsync(ct);
            // Um único SELECT: distinguir "fatura inexistente para o tenant" (linha ausente) de
            // "fatura existe, PDF ainda não gerado" (pdf_generated_at NULL) exige ler a linha
            // inteira, não só a coluna — uma coluna nula sozinha não permite essa distinção.
            var row = await conn.QuerySingleOrDefaultAsync<InvoicePdfStatusRow>(
                new CommandDefinition(
                    "SELECT pdf_generated_at AS PdfGeneratedAt FROM invoices WHERE id = @id AND tenant_id = @tenantId",
                    new { id, tenantId }, cancellationToken: ct));

            return row is null
                ? Error(404, "invoice_not_found", "Fatura não encontrada")
                : Results.Ok(new { pdfGeneratedAt = row.PdfGeneratedAt });
        });
    }

    private sealed class InvoicePdfStatusRow
    {
        public DateTimeOffset? PdfGeneratedAt { get; set; }
    }
}
