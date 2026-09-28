namespace Payment.Api.Handlers;

public sealed record CreatePaymentCommand(string HolderName, string HolderCpf, long AmountCents, string CardToken);

public sealed class CreatePaymentHandler(IPaymentRepository repository, ILogger<CreatePaymentHandler> logger)
{
    public async Task<Guid> HandleAsync(CreatePaymentCommand command, CancellationToken cancellationToken)
    {
        logger.LogInformation("Criando pagamento para {HolderName} CPF {HolderCpf} valor {AmountCents}",
            command.HolderName, command.HolderCpf, command.AmountCents);

        var paymentId = Guid.NewGuid();
        await repository.InsertAsync(paymentId, command.AmountCents, command.CardToken);
        return paymentId;
    }
}

public interface IPaymentRepository
{
    Task InsertAsync(Guid paymentId, long amountCents, string cardToken, CancellationToken cancellationToken = default);
}
