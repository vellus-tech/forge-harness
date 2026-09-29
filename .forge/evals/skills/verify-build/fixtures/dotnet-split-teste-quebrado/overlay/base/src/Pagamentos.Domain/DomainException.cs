namespace Pagamentos.Domain;

public sealed class DomainException(string message) : Exception(message);
