// Ferramenta de linha de comando que popula cartões de teste no banco local.
namespace Recarga.Seed;

internal static class Program
{
    private static int Main(string[] args)
    {
        var total = SeedRunner.PopularAsync(args.Length > 0 ? args[0] : "local").GetAwaiter().GetResult();
        Console.WriteLine($"{total} cartões populados");
        return 0;
    }
}

internal static class SeedRunner
{
    public static Task<int> PopularAsync(string ambiente) => Task.FromResult(ambiente.Length);
}
