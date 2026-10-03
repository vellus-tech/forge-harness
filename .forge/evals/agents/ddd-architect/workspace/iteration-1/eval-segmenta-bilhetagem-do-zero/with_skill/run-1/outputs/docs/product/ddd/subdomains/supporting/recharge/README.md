# Recharge

## 1. Classificação
- Tipo: Supporting Subdomain

## 2. Descrição
Captura a intenção de recarga do passageiro pelos dois canais previstos — app (cartão de crédito, com antifraude do adquirente) e ponto de venda credenciado (dinheiro) — e publica o crédito aprovado para o Passenger Wallet.

## 3. Justificativa da Classificação
É necessário para alimentar o saldo, mas a captura de pagamento em si é delegada ao adquirente e ao PSP externos (tokenização, antifraude); a Tarifa Viva não diferencia o produto pela forma como recebe recarga, e sim pelo que faz com o saldo (embarque e integração tarifária). Por isso é Supporting, não Core — mas tem ciclo de vida, integrações e linguagem próprios suficientes para ser um bounded context isolado, e não apenas um módulo do Wallet.

## 4. Capacidades Relacionadas
| Código | Capacidade | Descrição |
|---|---|---|
| CAP-03 | Recharge | Capturar recarga via app (cartão) ou POS (dinheiro) |

## 5. Eventos de Negócio Relacionados
| Evento | Descrição |
|---|---|
| RechargeApproved | Recarga aprovada (após antifraude no app, ou imediata no POS) |
| RechargeRejected | Recarga reprovada pelo antifraude do adquirente |

## 6. Regras de Negócio Relevantes
| Regra | Descrição |
|---|---|
| RULE-04 | Recarga por cartão de crédito só é creditada após aprovação antifraude do adquirente |
| RULE-09 | Dados de cartão de crédito nunca são armazenados nem trafegam pela Tarifa Viva |

## 7. Bounded Contexts Relacionados
| Bounded Context | Relação |
|---|---|
| Recharge | Contexto 1:1 com o subdomínio |

## 8. Pontos a Validar
- VAL-03 — confirmar com produto se a integração com PSP de Pix é real ou inferência a descartar
