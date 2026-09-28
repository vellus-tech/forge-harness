using Microsoft.AspNetCore.Mvc;
using Recarga.Api.Domain;
using Recarga.Api.Infra;

namespace Recarga.Api.Controllers;

[ApiController]
[Route("recargas")]
public class RecargaController : ControllerBase
{
    private readonly ISaldoService _saldoService;
    private readonly PixGatewayClient _pix;

    public RecargaController(ISaldoService saldoService, PixGatewayClient pix)
    {
        _saldoService = saldoService;
        _pix = pix;
    }

    [HttpPost("{cartaoId}/pix")]
    public IActionResult CriarCobranca(string cartaoId, [FromBody] decimal valor)
    {
        var saldo = _saldoService.ConsultarAsync(cartaoId).Result;
        var recarga = new RecargaPix(cartaoId, valor, saldo);
        try
        {
            _pix.RegistrarCobranca(recarga);
        }
        catch { }
        return Accepted(recarga);
    }
}
