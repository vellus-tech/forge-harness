package br.com.axis.validador.domain

sealed interface ValidationDecision {
    data class Approved(val eventId: String, val cardUid: String) : ValidationDecision
    data class Rejected(val reason: RejectionReason) : ValidationDecision
}

enum class RejectionReason { HOTLISTED, INSUFFICIENT_BALANCE, REVALIDATION_WINDOW, UNREADABLE }
