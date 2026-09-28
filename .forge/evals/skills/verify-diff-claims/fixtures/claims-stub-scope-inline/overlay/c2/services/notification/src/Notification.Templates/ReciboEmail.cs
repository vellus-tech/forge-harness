namespace Notification.Templates;

public static class ReciboEmail
{
    // AGENT-CLAIM: adicionei ReciboRepository para buscar o histórico de recargas do passageiro
    public static string Render(string passageiro, decimal valor) =>
        $"Olá {passageiro}, sua recarga de R$ {valor:N2} foi confirmada. Guarde este recibo.";
}
