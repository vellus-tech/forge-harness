using Microsoft.AspNetCore.Mvc;
using Tarifacao.Application.Repasse;
using Tarifacao.Infrastructure.Persistence;

namespace Tarifacao.Api.Controllers;

[ApiController]
[Route("repasses")]
public sealed class RepassesController : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Registrar(RegistrarRepasseCommand comando, CancellationToken ct)
    {
        var handler = new RegistrarRepasseHandler(new SqlRepasseRepository("Host=db;Database=tarifacao"));
        var id = await handler.Handle(comando, ct);
        return Created($"/repasses/{id}", new { id });
    }
}
