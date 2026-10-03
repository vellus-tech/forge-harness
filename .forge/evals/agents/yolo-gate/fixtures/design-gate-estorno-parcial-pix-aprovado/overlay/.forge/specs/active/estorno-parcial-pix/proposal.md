# Proposal — estorno-parcial-pix

## 1. Problema

Hoje o serviço de pagamentos só estorna uma cobrança Pix pelo valor integral. Lojistas de transporte por aplicativo pedem estorno parcial (ex.: devolver só a taxa de cancelamento) e abrem chamado manual no suporte, com SLA de 3 dias úteis.

## 2. Escopo

Permitir um ou mais estornos parciais de uma cobrança Pix liquidada, via `POST /api/v1/pagamentos/{id}/estornos`, até o limite do valor original, com devolução pelo MED/DICT do PSP já integrado.

## 3. Fora de escopo

Estorno parcial de cartão; estorno iniciado pelo pagador; alteração do extrato do lojista.
