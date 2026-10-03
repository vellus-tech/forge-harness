using System.Data;
using Pagamentos.Domain;

namespace Pagamentos.Infrastructure.Persistence;

public sealed class ReembolsoRepository(IDbConnection conexao) : IReembolsoRepository
{
    public int ContarPorCliente(string documentoCliente)
    {
        using var cmd = conexao.CreateCommand();
        cmd.CommandText = "SELECT COUNT(*) FROM reembolsos WHERE documento = @documento";

        var parametro = cmd.CreateParameter();
        parametro.ParameterName = "@documento";
        parametro.Value = documentoCliente;
        cmd.Parameters.Add(parametro);

        return Convert.ToInt32(cmd.ExecuteScalar());
    }
}
