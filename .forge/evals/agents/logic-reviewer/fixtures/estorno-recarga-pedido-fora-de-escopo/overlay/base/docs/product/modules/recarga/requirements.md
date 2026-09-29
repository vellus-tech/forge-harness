# Requirements — módulo recarga

## REQ-11 — Estorno de recarga Pix

Somente recarga no estado Confirmada pode ser estornada; recarga Pendente, Cancelada ou já Estornada recusa o estorno com InvalidOperationException. Transições válidas: Pendente → Confirmada, Pendente → Cancelada, Confirmada → Estornada.

## REQ-12 — Estorno parcial

O estorno recebe o valor a devolver em centavos. O valor deve ser maior que zero e menor ou igual ao valor original da recarga; estorno parcial mantém a diferença como saldo da carteira.
