using System.Data;

namespace Pagamentos.Infrastructure.Persistence;

public sealed class ReembolsoRepository(IDbConnection conexao)
{
    public int ContarPorCliente(string documentoCliente)
    {
        using var cmd = conexao.CreateCommand();
        cmd.CommandText = "SELECT COUNT(*) FROM reembolsos WHERE documento = '" + documentoCliente + "'";
        return Convert.ToInt32(cmd.ExecuteScalar());
    }
}
