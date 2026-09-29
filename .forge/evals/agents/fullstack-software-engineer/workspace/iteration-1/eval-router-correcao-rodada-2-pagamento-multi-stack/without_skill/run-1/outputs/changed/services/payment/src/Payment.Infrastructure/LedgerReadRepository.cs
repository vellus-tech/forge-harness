using Ledger.Contracts.V1;

namespace Payment.Infrastructure;

// Consome o saldo do portador via contrato gRPC do ledger-service (dono do bounded context Ledger),
// em vez de ler a tabela ledger.entries diretamente no banco de outro time (ver services/payment/protos/ledger.proto).
public sealed class LedgerReadRepository(LedgerService.LedgerServiceClient ledgerClient)
{
    public async Task<long> GetBalanceCentsAsync(string accountId, CancellationToken cancellationToken)
    {
        var response = await ledgerClient.GetBalanceAsync(
            new GetBalanceRequest { AccountId = accountId },
            cancellationToken: cancellationToken);
        return response.BalanceCents;
    }
}
