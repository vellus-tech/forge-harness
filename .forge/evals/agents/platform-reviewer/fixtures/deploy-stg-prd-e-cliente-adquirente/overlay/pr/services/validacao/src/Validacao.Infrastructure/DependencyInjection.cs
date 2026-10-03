using Microsoft.Extensions.DependencyInjection;
using Validacao.Infrastructure.Adquirente;

namespace Validacao.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services)
    {
        services.AddHttpClient<AdquirenteClient>();
        return services;
    }
}
