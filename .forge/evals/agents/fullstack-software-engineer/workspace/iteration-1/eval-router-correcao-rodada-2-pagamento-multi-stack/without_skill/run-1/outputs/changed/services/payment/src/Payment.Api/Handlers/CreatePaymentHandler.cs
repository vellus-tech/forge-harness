namespace Payment.Api.Handlers;

public sealed record CreatePaymentCommand(string HolderName, string HolderCpf, long AmountCents, string CardToken);

public sealed class CreatePaymentHandler(IPaymentRepository repository, ILogger<CreatePaymentHandler> logger)
{
    public async Task<Guid> HandleAsync(CreatePaymentCommand command, CancellationToken cancellationToken)
    {
        var paymentId = Guid.NewGuid();

        logger.LogInformation("Criando pagamento {PaymentId} valor {AmountCents}", paymentId, command.AmountCents);

        await repository.InsertAsync(paymentId, command.AmountCents, command.CardToken, cancellationToken);
        return paymentId;
    }
}

public interface IPaymentRepository
{
    Task InsertAsync(Guid paymentId, long amountCents, string cardToken, CancellationToken cancellationToken = default);
}
