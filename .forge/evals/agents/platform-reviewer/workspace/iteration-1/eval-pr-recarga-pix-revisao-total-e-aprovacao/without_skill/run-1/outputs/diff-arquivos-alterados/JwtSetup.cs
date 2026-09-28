using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;

namespace Recarga.Api;

public static class JwtSetup
{
    public static IServiceCollection AddRecargaAuth(this IServiceCollection services, IConfiguration cfg)
    {
        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(o =>
            {
                o.Authority = cfg["Auth:Authority"];
                o.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateAudience = true,
                    ValidAudience = cfg["Auth:Audience"],
                    ValidateLifetime = true,
                    ValidateIssuer = true,
                    ClockSkew = TimeSpan.FromMinutes(2)
                };
            });
        return services;
    }
}
