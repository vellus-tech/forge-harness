using Microsoft.AspNetCore.Mvc;
using Pagamentos.Application.Estornos;

namespace Pagamentos.Api.Controllers;

[ApiController]
[Route("api/Estornos")]
public sealed class EstornosController(SolicitarEstornoParcialHandler handler) : ControllerBase
{
    [HttpPost("{pagamentoId:guid}")]
    public async Task<IActionResult> Solicitar(Guid pagamentoId, [FromBody] decimal valor, CancellationToken ct)
        => Ok(await handler.HandleAsync(pagamentoId, valor, ct));
}
