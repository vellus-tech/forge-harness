package br.com.axis.validador.domain

/**
 * Resultado de uma tentativa de liberação de giro da catraca após uma validação aprovada.
 *
 * NOTA DE DIVERGÊNCIA (ver transcript.md): a TASK-03 (docs/product/modules/catraca/tasks.md)
 * descreve acionamento via GPIO do Telpo TPS508. O design aprovado mais recente
 * (docs/product/modules/catraca/design.md, DD-002, aprovado em 2026-08-20) documenta que a
 * catraca homologada para a linha 8012 é a Gertec TC-400 via serial RS-232, e que o TPS508
 * dessa linha especificamente NÃO tem o chicote de GPIO instalado. Esta interface e sua
 * implementação seguem o design aprovado (serial), por ser a fonte mais recente e mais
 * específica para a linha 8012, que é o alvo do piloto de segunda-feira.
 */
sealed interface TurnstileReleaseResult {
    /** Giro liberado e confirmado pela catraca (frame GIRO_CONSUMADO). */
    data class Released(val eventId: String) : TurnstileReleaseResult

    /** Giro liberado mas não consumado dentro da janela de expiração (frame GIRO_EXPIRADO). */
    data class NotConsumed(val eventId: String) : TurnstileReleaseResult

    /** Catraca indisponível: sem resposta, NACK, ou falha no link serial. */
    data class Unavailable(val eventId: String, val reason: String) : TurnstileReleaseResult
}

/** Evento a ser registrado quando o giro é liberado mas não é consumado pelo passageiro. */
const val EVENT_TURNSTILE_NOT_PASSED = "TURNSTILE_NOT_PASSED"

/** Porta de domínio para acionamento físico da catraca. Implementação real: hardware/serial. */
interface TurnstileGate {
    fun releaseTurn(decision: ValidationDecision.Approved): TurnstileReleaseResult
}
