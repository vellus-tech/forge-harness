# Settlement & Clearing

## 1. Classificação
- Tipo: Core Domain

## 2. Descrição
Apuração diária do repasse de receita às operadoras do consórcio, com trilha auditável e publicação imutável do arquivo de clearing.

## 3. Justificativa da Classificação
Objetivo de negócio explícito (OBJ-04); risco financeiro e regulatório alto — erro aqui afeta pagamento a três operadoras e a auditoria do órgão gestor. Regra própria de imutabilidade (NFR-05).

## 4. Capacidades Relacionadas
| Código | Capacidade | Descrição |
|---|---|---|
| CAP-07 | Settlement & Clearing | Apurar e publicar repasse diário por operadora |

## 5. Eventos de Negócio Relacionados
| Evento | Descrição |
|---|---|
| ArquivoClearingPublicado | Repasse diário apurado e imutável |

## 6. Regras de Negócio Relevantes
| Regra | Descrição |
|---|---|
| RULE-05 / INV-04 | Arquivo de clearing publicado é imutável; correção gera arquivo de ajuste |

## 7. Bounded Contexts Relacionados
| Bounded Context | Relação |
|---|---|
| Settlement & Clearing | Implementação direta deste subdomínio |
| Fare & Boarding | Publica eventos de embarque consumidos para apuração |

## 8. Pontos a Validar
- Nenhum ponto adicional identificado nos insumos atuais.
