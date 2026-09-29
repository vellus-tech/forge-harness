using Amazon.S3;
using Amazon.S3.Model;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Portador.Api.Data;

namespace Portador.Api.Controllers;

[Authorize]
[ApiController]
[Route("portadores/{cpf}/extrato")]
public sealed class ExtratoController(PortadorDbContext db, IAmazonS3 s3, IConfiguration config, ILogger<ExtratoController> logger) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Obter(string cpf, [FromQuery] string numeroCartao, CancellationToken ct)
    {
        logger.LogInformation("Extrato solicitado para o portador {PortadorId}", cpf.GetHashCode());

        var transacoes = await db.Transacoes
            .Where(t => t.CpfPortador == cpf && t.NumeroCartao == numeroCartao)
            .AsNoTracking()
            .ToListAsync(ct);

        await s3.PutObjectAsync(new PutObjectRequest
        {
            BucketName = config["Aws:Bucket"],
            Key = $"extratos/{cpf}/{DateTime.UtcNow:yyyyMMddHHmmss}.json",
            ContentBody = System.Text.Json.JsonSerializer.Serialize(transacoes),
        }, ct);

        return Ok(transacoes);
    }
}
