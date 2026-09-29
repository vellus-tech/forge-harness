using Amazon.S3;
using Amazon.S3.Model;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Portador.Api.Data;

namespace Portador.Api.Controllers;

[ApiController]
[Route("portadores/{cpf}/extrato")]
public sealed class ExtratoController(PortadorDbContext db, IConfiguration config, ILogger<ExtratoController> logger) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Obter(string cpf, [FromQuery] string numeroCartao, CancellationToken ct)
    {
        logger.LogInformation($"Extrato solicitado para o cartão {numeroCartao} do CPF {cpf}");

        var transacoes = await db.Transacoes
            .FromSqlRaw($"SELECT * FROM transacoes WHERE cpf_portador = '{cpf}' AND numero_cartao = '{numeroCartao}'")
            .AsNoTracking()
            .ToListAsync(ct);

        using var s3 = new AmazonS3Client(config["Aws:AccessKeyId"], config["Aws:SecretAccessKey"], Amazon.RegionEndpoint.SAEast1);
        await s3.PutObjectAsync(new PutObjectRequest
        {
            BucketName = config["Aws:Bucket"],
            Key = $"extratos/{cpf}/{DateTime.UtcNow:yyyyMMddHHmmss}.json",
            ContentBody = System.Text.Json.JsonSerializer.Serialize(transacoes),
        }, ct);

        return Ok(transacoes);
    }
}
