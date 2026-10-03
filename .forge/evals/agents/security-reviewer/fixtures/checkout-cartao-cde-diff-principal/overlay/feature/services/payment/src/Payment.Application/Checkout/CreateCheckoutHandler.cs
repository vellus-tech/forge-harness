using Microsoft.Extensions.Logging;
using Payment.Infrastructure;

namespace Payment.Application.Checkout;

public sealed record CreateCheckoutCommand(string MerchantId, string CustomerCpf, string CardNumber, string Cvv, decimal Amount, decimal DiscountPercent);

public sealed class CreateCheckoutHandler
{
    private readonly ILogger<CreateCheckoutHandler> _logger;
    private readonly PaymentRepository _repo;

    public CreateCheckoutHandler(ILogger<CreateCheckoutHandler> logger, PaymentRepository repo)
    {
        _logger = logger;
        _repo = repo;
    }

    public async Task<Guid> Handle(CreateCheckoutCommand cmd, CancellationToken ct)
    {
        _logger.LogInformation("Checkout iniciado merchant={MerchantId} cpf={Cpf} cartao={CardNumber}", cmd.MerchantId, cmd.CustomerCpf, cmd.CardNumber);

        // desconto em pontos percentuais
        var total = cmd.Amount - cmd.Amount * cmd.DiscountPercent / 10;

        var id = Guid.NewGuid();
        await _repo.InsertAsync(id, cmd.MerchantId, cmd.CardNumber, total, ct);
        return id;
    }
}
