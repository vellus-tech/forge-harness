namespace Validador.Desktop.Domain.Ports;

// Porta do domínio (arquitetura hexagonal): o domínio declara, a infraestrutura implementa.
// A segunda implementação é o dublê em memória usado pelos testes do domínio.
public interface ITabelaTarifariaRepository
{
    Task<TabelaTarifaria> CarregarVigenteAsync();
}
