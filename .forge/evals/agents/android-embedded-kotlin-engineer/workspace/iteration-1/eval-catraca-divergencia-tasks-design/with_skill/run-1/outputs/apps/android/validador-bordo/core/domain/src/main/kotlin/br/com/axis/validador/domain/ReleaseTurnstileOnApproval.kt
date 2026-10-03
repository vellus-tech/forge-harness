package br.com.axis.validador.domain

/**
 * TASK-03 (módulo catraca): ao receber uma decisão de validação aprovada, libera um giro da
 * catraca através da [TurnstilePort] homologada para o dispositivo/linha em operação.
 *
 * Uma decisão [ValidationDecision.Rejected] nunca aciona a catraca — retorna `null` sem efeito
 * colateral, deixando explícito que a ausência de outcome é o caminho esperado, não um erro.
 */
class ReleaseTurnstileOnApproval(private val turnstilePort: TurnstilePort) {
    suspend fun handle(decision: ValidationDecision): TurnstileReleaseOutcome? {
        if (decision !is ValidationDecision.Approved) return null

        val request = TurnstileReleaseRequest(eventId = decision.eventId)
        return turnstilePort.releaseSingleTurn(request)
    }
}
