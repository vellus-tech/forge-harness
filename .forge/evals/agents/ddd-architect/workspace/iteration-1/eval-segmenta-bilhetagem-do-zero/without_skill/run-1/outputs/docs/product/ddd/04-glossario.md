# Glossário — Linguagem Ubíqua por Contexto

## Controle de Versão
| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-09-26 | Segmentação DDD inicial |

## 1. Alerta de termo colidente: "validação"

O FRD usa a palavra "validação" com dois significados completamente diferentes: em FR-01 ("o validador verifica... a validação aqui é o ato de embarque") ela significa a decisão de embarque no contexto Embarque, e em FR-04 ("a recarga só é creditada após a validação antifraude do adquirente") ela significa a autorização de pagamento no contexto Integração com Meios de Pagamento. Tratar isso como um único conceito é o erro de modelagem mais provável nessa segmentação — os dois termos precisam de nomes distintos na linguagem ubíqua de cada contexto: `DecisaoDeEmbarque` em Embarque e `AutorizacaoDePagamento` em Integração com Meios de Pagamento, nunca um objeto `Validacao` genérico compartilhado entre os dois.

## 2. Embarque

| Termo | Significado |
|---|---|
| Embarque | Ato de um passageiro entrar no ônibus validado por um validador. |
| Decisão de Embarque | Resultado (aprovado/negado) da checagem de bloqueio + saldo + tarifa, em até 300 ms. |
| Tarifa Vigente | Valor a debitar, dado pela linha embarcada (via Cadastro de Linhas e Operadoras). |
| Janela de Integração | Período de 60 minutos em que a segunda viagem em linha diferente custa 50%. |
| Integração Tarifária | Aplicação do desconto de 50% quando a Janela de Integração está ativa. |

## 3. Clearing

| Termo | Significado |
|---|---|
| Apuração | Cálculo diário de quanto cada operadora deve receber. |
| Repasse | Valor efetivamente destinado a uma operadora após a apuração. |
| Arquivo de Repasse | Artefato imutável publicado ao fim do dia com os lançamentos do dia. |
| Arquivo de Ajuste | Artefato separado que corrige um arquivo de repasse já publicado — nunca uma reescrita do original. |

## 4. Carteira

| Termo | Significado |
|---|---|
| Carteira | Agregado que representa saldo e status de um cartão/passageiro. |
| Saldo Disponível | Crédito que pode ser debitado em um embarque. |
| Bloqueio | Marca que impede o cartão de embarcar, feita pelo passageiro (perda) ou pelo gestor. |

## 5. Recarga

| Termo | Significado |
|---|---|
| Pedido de Recarga | Intenção do passageiro de comprar crédito. |
| Recarga via Cartão | Recarga paga por cartão de crédito, sujeita a autorização do adquirente. |
| Recarga em Dinheiro | Recarga registrada por um ponto de venda credenciado. |

## 6. Frota de Validadores

| Termo | Significado |
|---|---|
| Validador | Equipamento embarcado no ônibus que decide o embarque localmente. |
| Lote de Sincronização | Conjunto de até 5.000 embarques offline enviado quando o validador conecta na garagem. |
| Evento ValidaBus Bruto | Registro no formato proprietário do fornecedor, nunca exposto fora de Frota de Validadores. |

## 7. Cadastro de Linhas e Operadoras

| Termo | Significado |
|---|---|
| Linha | Rota de ônibus operada por exatamente uma operadora. |
| Operadora | Uma das três empresas do consórcio (Viação Serrana, Expresso Vale, TransSereno). |

## 8. Identidade do Passageiro

| Termo | Significado |
|---|---|
| Conta do Passageiro | Identidade única do passageiro no app. |
| MFA | Segundo fator de autenticação, opcional. |

## 9. Notificações

| Termo | Significado |
|---|---|
| Saldo Baixo | Evento disparado quando o saldo cai abaixo de 2 tarifas vigentes. |

## 10. Integração com Meios de Pagamento

| Termo | Significado |
|---|---|
| Autorização de Pagamento | Resultado da checagem antifraude/aprovação do adquirente sobre uma transação de cartão. |
| Token de Cartão | Referência opaca emitida pelo adquirente; substitui o dado real do cartão em todo o domínio (NFR-03). |
