namespace Notification.Templates;

public static class ReciboEmail
{
    public static string Render(string passageiro, decimal valor) =>
        $"Olá {passageiro}, sua recarga de R$ {valor} foi confirmada.";
}
