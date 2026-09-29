namespace Pagamentos.Domain;

public interface IReembolsoRepository
{
    int ContarPorCliente(string documentoCliente);
}
