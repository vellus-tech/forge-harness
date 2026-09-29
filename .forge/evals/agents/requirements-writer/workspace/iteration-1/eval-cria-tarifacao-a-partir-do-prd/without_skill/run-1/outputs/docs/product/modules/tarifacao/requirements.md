# Requirements — Módulo Tarifação

- Versão: 1.0.0
- Data: 2026-09-28
- Origem: docs/product/prd-tarifacao.md (v1.0.0, Aprovado) + docs/product/glossary/domain-glossary.md
- Status: Pronto para o time de desenvolvimento

## 1. Objetivo

Definir o comportamento esperado do cálculo do valor cobrado em cada Validação, de acordo com o Perfil Tarifário do Passageiro, a Tarifa Base vigente e a Integração Temporal, atendendo ao Decreto 18.442/2026 (Tarifa Base de R$ 4,85 a partir de 2026-11-01) e às exigências de auditoria da Operadora e da SEMOB.

## 2. Escopo

Este documento cobre o cálculo do valor de cada Validação e o registro auditável desse cálculo. Ficam fora do escopo, conforme o PRD, a tarifa diferenciada por linha ou distância e o bilhete único mensal.

## 3. Termos usados

Passageiro, Cartão Transporte, Validação, Validador, Tarifa Base, Integração Temporal, Janela de Integração, Gratuidade, Perfil Tarifário, Recarga e Operadora seguem as definições de docs/product/glossary/domain-glossary.md. SEMOB (Secretaria Municipal de Mobilidade) é citada no PRD mas não consta do glossário; está usada aqui como o órgão fiscalizador municipal a quem a Operadora presta contas.

## 4. Requisitos funcionais

- FR-01 — Tarifa Base vigente por data: o sistema mantém a Tarifa Base com vigência datada (a partir de 2026-11-01, R$ 4,85), e cada Validação é cobrada pela Tarifa Base cuja vigência estava ativa no instante dessa Validação; alterar ou cadastrar uma nova vigência não recalcula Validações já registradas.
- FR-02 — Integração Temporal: ao registrar uma Validação, o sistema verifica se há uma Validação anterior do mesmo Cartão Transporte dentro da Janela de Integração de 60 minutos contados da primeira Validação da sequência. A segunda Validação da sequência é cobrada em 50% da Tarifa Base vigente; a terceira Validação da mesma sequência é cobrada em 100% da Tarifa Base vigente (tarifa cheia).
- FR-03 — Perfil estudante: uma Validação de Passageiro com Perfil Tarifário estudante é cobrada em 50% da Tarifa Base vigente, até o limite de 60 Validações beneficiadas por mês civil; a partir da 61ª Validação do mês, a cobrança segue a regra que se aplicaria sem o benefício de estudante (Tarifa Base cheia ou desconto de Integração Temporal, conforme o caso).
- FR-04 — Gratuidade: Passageiro com Perfil Tarifário idoso (65 anos ou mais) ou PcD não é cobrado em nenhuma Validação, independentemente de Integração Temporal ou de qualquer outro benefício.
- FR-05 — Não acumulação de benefícios: quando mais de um benefício se aplicaria à mesma Validação (por exemplo, estudante dentro da Janela de Integração), o sistema cobra o menor valor entre os benefícios aplicáveis, sem aplicar um desconto sobre outro já reduzido.
- FR-06 — Registro auditável: cada cálculo de tarifa gera um registro identificando o Cartão Transporte, o Perfil Tarifário considerado, a regra (ou combinação de regras) aplicada e o valor cobrado; esse registro deve ficar disponível para consulta pela Operadora e pela SEMOB por 5 anos.

## 5. Requisitos não funcionais

- NFR-01 — Desempenho: o cálculo de tarifa responde em até 150 ms (p95) no Validador, suportando 3.000 Validações por minuto no horário de pico.
- NFR-02 — Privacidade em log: o número do Cartão Transporte nunca aparece completo em log; deve ser mascarado ou substituído por identificador interno.
- NFR-03 — Retenção do registro de auditoria: os registros descritos em FR-06 ficam retidos por, no mínimo, 5 anos e não podem ser alterados nem removidos depois de gravados.

## 6. Observação sobre a nota técnica do PRD

O PRD (seção 5) traz uma sugestão inicial da equipe — coluna `NUMERIC(10,2)` e biblioteca `decimal.js` — marcada como rascunho, não como decisão. Este documento não fixa a representação de dados nem a stack técnica: cabe à fase de design decidir a representação monetária (por exemplo, valor inteiro em menor unidade, para evitar erro de ponto flutuante em cálculos de porcentagem como os 50% de FR-02 e FR-03) e confirmar se há alguma convenção de arredondamento já adotada pela Operadora para os casos em que a Tarifa Base vigente tiver centavo ímpar.

## 7. Regras de negócio derivadas / pontos a confirmar com o time de produto

- Troca de vigência da Tarifa Base durante uma Janela de Integração em aberto: o PRD não diz se as Validações de uma mesma sequência de integração usam a Tarifa Base vigente no instante de cada Validação ou a vigente na primeira Validação da sequência. Assumido, até confirmação, que cada Validação usa a Tarifa Base vigente no seu próprio instante (consistente com FR-01) — a confirmar antes do design.
- Quarta Validação em diante na mesma Janela de Integração: o PRD só define a regra para a 2ª e a 3ª Validação. Assumido que a 4ª Validação em diante, se ainda dentro da janela contada da primeira, segue a mesma regra da 3ª (tarifa cheia) — não está explícito no PRD, a confirmar.
- Limite de 60 Validações/mês do Perfil estudante: o PRD não especifica o fuso horário nem o critério de virada de mês civil, nem o que ocorre com uma Validação em trânsito na virada do mês. Assumido reinício da contagem no primeiro dia do mês civil, no fuso horário oficial da operação — a confirmar.
- Passageiro com múltiplos Cartões Transporte: o PRD define Integração Temporal e o limite de estudante por Cartão Transporte, não por Passageiro. Mantido por cartão, por ser a leitura literal de RN-02/RN-03 do PRD — vale confirmar se é essa a intenção de produto ou se o controle deveria ser por Passageiro.

## 8. Fora de escopo

Tarifa diferenciada por linha ou por distância; bilhete único mensal (conforme PRD, seção 4).

## 9. Critérios de aceite

- Dado um Cartão Transporte sem Validação anterior dentro da Janela de Integração, quando ocorre uma Validação de Perfil comum, então o valor cobrado é a Tarifa Base vigente cheia.
- Dado um Cartão Transporte com uma Validação anterior há menos de 60 minutos, quando ocorre a segunda Validação da mesma sequência, então o valor cobrado é 50% da Tarifa Base vigente.
- Dado um Cartão Transporte com duas Validações anteriores na mesma sequência de Integração Temporal, quando ocorre a terceira Validação, então o valor cobrado é 100% da Tarifa Base vigente.
- Dado um Passageiro com Perfil idoso ou PcD, quando ocorre qualquer Validação, então o valor cobrado é zero.
- Dado um Passageiro com Perfil estudante, quando ele já realizou 60 Validações beneficiadas no mês civil corrente e realiza uma 61ª Validação, então essa Validação é cobrada como se não houvesse benefício de estudante (aplicando Tarifa Base cheia ou desconto de integração, conforme o caso).
- Dado um Passageiro com Perfil estudante dentro da Janela de Integração, quando o desconto de integração e o desconto de estudante se aplicariam simultaneamente, então é cobrado o menor valor entre os dois, nunca a combinação dos dois.
- Dado qualquer cálculo de tarifa, quando ele é concluído, então um registro é gravado com Cartão Transporte, Perfil Tarifário, regra aplicada e valor cobrado, e permanece consultável por 5 anos.

## 10. Riscos e prazo

O Decreto 18.442/2026 entra em vigor em 2026-11-01 e o time pretende iniciar o design na semana seguinte à entrega deste documento. Como a Tarifa Base é modelada com vigência datada (FR-01), recomenda-se que o design confirme a possibilidade de cadastrar o valor de R$ 4,85 com vigência futura antes de 2026-11-01, para que a mudança entre em vigor automaticamente na data do decreto, sem depender de um deploy no próprio dia.

## 11. Perguntas em aberto para o time de produto

1. A troca de vigência da Tarifa Base durante uma Janela de Integração em aberto deve usar a tarifa do instante de cada Validação ou a tarifa fixada na primeira Validação da sequência?
2. Existe regra definida para a 4ª Validação (ou seguintes) dentro da mesma Janela de Integração, ou ela sempre segue a regra da 3ª Validação (tarifa cheia)?
3. O limite de 60 Validações/mês do Perfil estudante é por Cartão Transporte ou por Passageiro, e qual o critério de fuso horário/virada de mês?
4. O controle de Integração Temporal e do limite de estudante deve ser por Cartão Transporte (leitura literal do PRD) ou por Passageiro, quando um Passageiro tiver mais de um Cartão Transporte?
