using System.Globalization;
using Conciliacao.Dominio;
using Conciliacao.Infra;
using Npgsql;

namespace Conciliacao.Cli;

// Ferramenta de console disparada pelo cron noturno: um processo, uma execução, código de saída para o agendador.
public static class Program
{
    public static int Main(string[] args)
    {
        if (args.Length != 2)
        {
            Console.Error.WriteLine("uso: conciliacao <lotes.csv> <extrato.csv>");
            return 2;
        }

        var conexao = Environment.GetEnvironmentVariable("CONCILIACAO_DB")
            ?? throw new InvalidOperationException("CONCILIACAO_DB não definida");
        using var fonte = NpgsqlDataSource.Create(conexao);
        var conciliador = new Conciliador(new RelogioSistema(), new LoteRepositorioSql(fonte));

        var lotes = File.ReadLines(args[0]).Skip(1).Select(LerLote).ToList();
        var extrato = File.ReadLines(args[1]).Skip(1).Select(LerLancamento).ToList();

        var divergentes = 0;
        foreach (var lote in lotes)
        {
            var confere = conciliador.ValidarLoteAsync(lote, extrato, CancellationToken.None).GetAwaiter().GetResult();
            if (!confere)
            {
                divergentes++;
            }
        }

        Console.WriteLine($"{lotes.Count} lotes processados, {divergentes} divergentes");
        return divergentes == 0 ? 0 : 1;
    }

    private static Lote LerLote(string linha)
    {
        var campos = linha.Split(';');
        return new Lote { Id = campos[0], ValorTotal = decimal.Parse(campos[1], CultureInfo.InvariantCulture) };
    }

    private static LancamentoAdquirente LerLancamento(string linha)
    {
        var campos = linha.Split(';');
        return new LancamentoAdquirente(campos[0], decimal.Parse(campos[1], CultureInfo.InvariantCulture));
    }
}
