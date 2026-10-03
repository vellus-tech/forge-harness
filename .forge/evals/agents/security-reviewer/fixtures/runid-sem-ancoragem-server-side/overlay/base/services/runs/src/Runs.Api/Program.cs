using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer").AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new RsaSecurityKey(JwtKeys.LoadPublicKey(builder.Configuration, builder.Environment)),
        ValidateIssuer = true,
        ValidIssuer = "example.com",
        ValidateAudience = true,
        ValidAudience = "api",
        ValidateLifetime = true,
        ClockSkew = TimeSpan.Zero
    };
});

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.Run();
