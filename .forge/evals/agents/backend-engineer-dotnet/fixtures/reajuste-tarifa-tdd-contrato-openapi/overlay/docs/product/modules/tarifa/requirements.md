# Requirements — módulo tarifa

## REQ-004 — Reajuste de tarifa por percentual

QUANDO o operador da concessionária aplicar um reajuste percentual a uma linha, o sistema DEVE recalcular a tarifa vigente sobre o valor em centavos, com o percentual expresso em pontos-base (1 bp = 0,01%), arredondando para o centavo pelo critério half-even (arredondamento bancário), e DEVE devolver a tarifa anterior e a nova.

O percentual DEVE estar entre 1 e 5000 bp (0,01% a 50%); fora disso o sistema DEVE responder 422 com ProblemDetails. Linha inexistente DEVE responder 404.
