using System.Security.Cryptography;

namespace Notificacoes.Api;

public static class JwtKeys
{
    public static RSA LoadPublicKey(IConfiguration config, IWebHostEnvironment env)
    {
        var keyEnv = Environment.GetEnvironmentVariable("JWT_PUBLIC_KEY");
        if (!string.IsNullOrEmpty(keyEnv))
        {
            var rsa = RSA.Create();
            rsa.ImportFromPem(keyEnv);
            return rsa;
        }

        var keyPath = config["Jwt:PublicKeyPath"];
        if (!string.IsNullOrEmpty(keyPath) && File.Exists(keyPath))
        {
            var rsa = RSA.Create();
            rsa.ImportFromPem(File.ReadAllText(keyPath));
            return rsa;
        }

        if (env.EnvironmentName is "Test" or "Testing")
            return RSA.Create(2048);

        throw new InvalidOperationException("JWT public key not configured. Set JWT_PUBLIC_KEY env var or Jwt:PublicKeyPath.");
    }
}
