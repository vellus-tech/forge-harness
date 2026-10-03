# Fare Integration

## 1. Classificação
- Tipo: Core Domain

## 2. Descrição
Regra de integração temporal entre embarques do mesmo cartão em linhas diferentes dentro de uma janela de tempo — reduz a tarifa da segunda viagem quando aplicável.

## 3. Justificativa da Classificação
A regra de integração (janela de 60 minutos, desconto de 50%) é uma decisão comercial específica do consórcio Tarifa Viva, sem equivalente genérico de mercado — diferencia o produto e tem alto risco financeiro se calculada incorretamente.

## 4. Capacidades Relacionadas
| Código | Capacidade | Descrição |
|---|---|---|
| CAP-02 | Fare Integration | Aplicar desconto de integração temporal entre embarques |

## 5. Eventos de Negócio Relacionados
| Evento | Descrição |
|---|---|
| FareIntegrationApplied | A tarifa da segunda viagem foi calculada com desconto de integração |

## 6. Regras de Negócio Relevantes
| Regra | Descrição |
|---|---|
| FR-03 | Se o mesmo cartão embarcou há menos de 60 minutos em linha diferente, a tarifa da segunda viagem é 50% |

## 7. Bounded Contexts Relacionados
| Bounded Context | Relação |
|---|---|
| Fare Validation | Consolidado — a decisão de integração ocorre no mesmo ciclo de vida do embarque (BC-01) |

## 8. Pontos a Validar
- Nenhum ponto novo identificado nesta execução (v1.1) — subdomínio inalterado desde v1.0.
