using Dapper;
using Npgsql;

namespace Payment.Infrastructure;

public sealed class PaymentRepository
{
    private readonly NpgsqlDataSource _db;

    public PaymentRepository(NpgsqlDataSource db) => _db = db;

    public async Task InsertAsync(Guid id, string merchantId, string cardNumber, decimal total, CancellationToken ct)
    {
        await using var conn = await _db.OpenConnectionAsync(ct);
        await conn.ExecuteAsync(
            "INSERT INTO payments (id, merchant_id, card_number, total) VALUES (@id, @merchantId, @cardNumber, @total)",
            new { id, merchantId, cardNumber, total });
    }

    public async Task<IEnumerable<dynamic>> ListByMerchantAsync(string merchantId, CancellationToken ct)
    {
        await using var conn = await _db.OpenConnectionAsync(ct);
        var sql = "SELECT id, total FROM payments WHERE merchant_id = '" + merchantId + "'";
        return await conn.QueryAsync(sql);
    }
}
