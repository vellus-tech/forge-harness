# PRD — Portal do Lojista
**Portal web de consulta de vendas para lojistas credenciados**

- **Versão:** 1.1.0
- **Data:** 2026-08-28
- **Status:** Aprovado para desenvolvimento

## 1. Objetivo

Dar ao lojista credenciado autonomia para consultar vendas, recebíveis e chargebacks sem abrir chamado no SAC.

## 2. Escopo

- F1 — Acesso ao portal com e-mail e senha, com segundo fator por aplicativo autenticador.
- F2 — Consulta de vendas por período (máximo 90 dias por consulta), com PAN mascarado.
- F3 — Exportação das vendas consultadas em CSV.
- F4 — Consulta de chargebacks abertos e prazo de defesa.

## 3. Personas

- P-01 Lojista administrador (cria usuários operadores da própria loja).
- P-02 Lojista operador (apenas consulta).

## 4. Regras de negócio

- BR-01 — Somente o administrador cria, bloqueia e remove operadores da própria loja.
- BR-02 — Após 5 tentativas de senha inválida o acesso é bloqueado por 30 minutos.
- BR-03 — A senha deve ser forte e trocada periodicamente.

## 5. Restrições e compliance

- O portal está no escopo do ambiente PCI DSS 4.0.1 da adquirente; nenhum PAN completo pode ser exibido ou exportado.
- Os dados de vendas devem ser retidos pelo prazo exigido pela regulação e descartados depois; o prazo ainda não foi definido pelo jurídico.
