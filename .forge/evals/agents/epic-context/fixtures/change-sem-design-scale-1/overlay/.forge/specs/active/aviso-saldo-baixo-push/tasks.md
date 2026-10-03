# Tasks — aviso-saldo-baixo-push

## Wave 1 — Regra de disparo

- [ ] TASK-01 — Avaliar limiar após débito da validação (rastreia: REQ-01; paths: `src/notificacoes/saldo-baixo.ts`; depende: —)

  Assinatura esperada:

  ```ts
  export function deveAvisarSaldoBaixo(saldoCentavos: number, limiarCentavos: number, ultimoAviso?: Date): boolean
  ```

- [ ] TASK-02 — Janela de 24 h por cartão e respeito ao opt-out (rastreia: REQ-02, REQ-03; paths: `src/notificacoes/saldo-baixo.ts`; depende: TASK-01)

## Wave 2 — Envio

- [ ] TASK-03 — Montar e enviar o push com cartão mascarado (rastreia: REQ-04; paths: `src/notificacoes/templates/saldo-baixo.json`; depende: TASK-02)
