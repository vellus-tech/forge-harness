# PRD — Portal VT Corporativo

- Status: rascunho para revisão
- Owner do produto: Patrícia Lemos
- Data: 2026-09-26
- Fontes: três entrevistas de discovery com clientes (setembro/2026), jornadas mapeadas no workshop de 15/09/2026, notas de discovery do Portal VT Corporativo
- Este documento é a base para o FRD, o NFRD e o TRD que o time inicia na próxima semana

## 1. Resumo executivo

O Portal VT Corporativo é um produto web B2B que permite que empresas clientes comprem e distribuam recargas de vale-transporte diretamente nos cartões de bilhetagem de seus colaboradores, substituindo o processo manual atual baseado em planilha e upload de CSV no portal da operadora. A operadora parceira do piloto é o Consórcio Metropolitano de Transportes (CMT); não há ainda acordo comercial ou técnico com outras operadoras, o que limita o escopo inicial a clientes cujos colaboradores usam cartões CMT. O discovery revelou três dores centrais nos clientes atuais: o processo de pedido mensal é manual e sujeito a erro silencioso (rejeições de CSV que só aparecem na catraca), o pagamento e o crédito não são rastreáveis nem conciliáveis financeiramente, e não existe correção pontual de erros sem refazer o pedido inteiro. A meta comercial declarada é sair de 14 empresas no processo por CSV para 40 empresas no portal até março de 2027, o que torna a redução de esforço operacional e de erro por cliente um requisito de escala, não apenas de conveniência.

## 2. Problema e contexto

Hoje, cada empresa cliente do CMT gera manualmente uma planilha de colaboradores elegíveis a vale-transporte, confere direitos e quantidades de passagem, exporta um CSV e faz upload no portal da operadora. Esse processo consome em média dois dias úteis por mês por analista de RH/DP e não dá visibilidade sobre erros de formatação (por exemplo, CPF com máscara) até que a rejeição já tenha impedido a recarga — o caso relatado de 37 colaboradores sem recarga em agosto por um CSV rejeitado só foi percebido quando os motoristas recusaram o embarque na catraca. No lado financeiro, empresas com múltiplos CNPJs pagam um boleto por CNPJ, o repasse à operadora leva até dois dias (D+2) e um atraso de um dia no boleto atrasa a recarga do mês inteiro para todos os colaboradores daquele CNPJ; além disso, não há hoje forma de conciliar o valor pago com o valor efetivamente creditado por colaborador, o que já gerou uma diferença de R$ 4.180 que levou três semanas para ser explicada em um cliente. Colaboradores individuais, por sua vez, não têm nenhuma visibilidade de quando a recarga foi creditada no próprio cartão.

## 3. Objetivos do produto

- Eliminar o upload manual de CSV como caminho principal do pedido mensal de recarga, substituindo-o por um fluxo guiado dentro do portal que valida os dados antes do envio à operadora.
- Dar visibilidade no mesmo dia sobre qualquer rejeição de linha do pedido, com o motivo do erro, para que o analista de DP corrija sem esperar reclamação na catraca.
- Permitir a correção pontual de linhas rejeitadas (CPF inválido, cartão bloqueado, colaborador desligado) sem necessidade de recriar o pedido inteiro.
- Consolidar o pagamento de empresas com múltiplos CNPJs em um único pedido e um único acompanhamento de status, do pagamento até o crédito confirmado no cartão.
- Tornar a conciliação financeira (valor pago x valor creditado, por colaborador e por centro de custo) uma função nativa do portal, com relatório exportável.
- Sustentar o crescimento comercial de 14 para 40 empresas clientes até março de 2027 sem aumento proporcional de esforço operacional do time de suporte.

## 4. Personas e usuários

**Analista de DP/RH da empresa cliente** (ex.: Clara Mendes, Transportadora Rio Doce, 820 colaboradores). Responsável pelo pedido mensal de recarga: importar a lista de colaboradores, revisar direitos e quantidades, confirmar o pedido, acompanhar rejeições e gerar relatório por centro de custo para o financeiro interno. Prioriza rapidez, clareza de erros e confiabilidade — é quem hoje absorve o retrabalho quando algo falha.

**Gerente financeiro da empresa cliente** (ex.: Rogério Alves, Grupo Serra Verde, 2.300 colaboradores, 4 CNPJs). Responsável por pagar o pedido consolidado, acompanhar o status até o crédito e conciliar valor pago com valor creditado. Prioriza consolidação entre CNPJs, rastreabilidade do pagamento e meios de pagamento mais rápidos que boleto (perguntou explicitamente sobre Pix).

**Colaborador final** (ex.: Denise Couto, operadora de caixa). Usa o cartão de bilitagem no dia a dia e hoje só descobre que a recarga não caiu na catraca. Quer ser avisada quando o crédito acontecer. É usuária indireta do portal B2B (provavelmente via notificação, não via login no portal corporativo) — o formato exato do canal de aviso é uma decisão de design em aberto.

**Time interno de suporte/operações** (ator implícito, não entrevistado diretamente): hoje absorve o volume de erros e reclamações gerados pelo processo manual; é beneficiário indireto de qualquer redução de erro no fluxo.

## 5. Jornadas e requisitos funcionais

### J1 — Pedido mensal de recarga

O analista importa a lista de colaboradores, revisa os valores por colaborador, confirma o pedido, gera o pagamento e acompanha até o crédito no cartão.

Requisitos funcionais:
- RF1.1 — O portal deve permitir importar a lista de colaboradores elegíveis (substituindo a exportação manual da folha), com validação de formato antes da confirmação do pedido (a validação de CPF é a que já causou falha silenciosa e deve ser tratada como caso crítico).
- RF1.2 — O portal deve exibir, por colaborador, o direito a vale-transporte e a quantidade de passagens/dia antes da confirmação, permitindo edição pontual.
- RF1.3 — Após a confirmação, o portal deve emitir um pedido de recarga rastreável, com identificador único, status visível (recebido, em processamento, pago, creditado, rejeitado) e histórico de mudança de status.
- RF1.4 — O acompanhamento do pedido deve seguir até a confirmação do crédito no cartão do colaborador pela operadora, não apenas até o pagamento.

### J2 — Tratamento de rejeições

Linhas com CPF inválido, cartão bloqueado ou colaborador desligado voltam para o analista corrigir e reenviar sem refazer o pedido inteiro.

Requisitos funcionais:
- RF2.1 — O portal deve identificar e reportar rejeições no nível da linha (colaborador), nunca do pedido inteiro, e no mesmo dia em que a rejeição ocorrer — este é o requisito que resolve diretamente a lacuna relatada na Entrevista 1.
- RF2.2 — Cada rejeição deve vir com o motivo específico (CPF inválido, cartão bloqueado, colaborador desligado, e outros motivos a serem levantados com a operadora no FRD/TRD).
- RF2.3 — O analista deve poder corrigir e reenviar apenas as linhas rejeitadas, mantendo o restante do pedido já em processamento intacto.
- RF2.4 — O portal deve notificar o analista responsável (dentro do portal e, a avaliar no FRD, por e-mail) assim que uma rejeição for detectada, sem depender de o analista consultar o status manualmente.

### J3 — Conciliação financeira

O financeiro compara o valor pago com o valor efetivamente creditado por colaborador e por centro de custo e exporta o relatório.

Requisitos funcionais:
- RF3.1 — O portal deve consolidar, para empresas com múltiplos CNPJs, o pedido e o pagamento em uma única operação, mantendo a rastreabilidade por CNPJ internamente para fins contábeis.
- RF3.2 — O portal deve registrar o valor pago e o valor efetivamente creditado por colaborador, permitindo identificar divergências automaticamente (o caso relatado de R$ 4.180 de diferença deve deixar de exigir investigação manual de três semanas).
- RF3.3 — O portal deve gerar um relatório de conciliação exportável, segmentado por centro de custo, para uso do financeiro interno do cliente.
- RF3.4 — O portal deve suportar, a confirmar viabilidade com a operadora e o time de pagamentos, meio de pagamento adicional ao boleto (Pix foi pedido explicitamente por um cliente) — tratar como requisito candidato, não confirmado, até validação no FRD.

### Requisito adicional identificado fora das três jornadas formais

- RF4.1 — Notificação ao colaborador final quando a recarga for creditada no cartão (relatado na Entrevista 3). O canal (push, SMS, e-mail, ou notificação via app da operadora) e a titularidade do dado de contato do colaborador não foram definidos no discovery e ficam como pergunta aberta para o FRD.

## 6. Fora de escopo (nesta fase)

- Suporte a operadoras de bilhetagem além do CMT — não há acordo comercial nem técnico com outras operadoras.
- Portal ou aplicativo dedicado para o colaborador final; o discovery aponta apenas a necessidade de notificação, não de um canal de autoatendimento completo.
- Qualquer meio de pagamento além de boleto e, condicionalmente, Pix — outros meios (cartão corporativo, débito automático) não foram mencionados no discovery e não entram nesta fase.

## 7. Requisitos não funcionais — sinalizados, não definidos

O discovery não produziu números de disponibilidade, volume de pico esperado nem prazo contratual de crédito com o CMT; no workshop, quando perguntado, ninguém do lado de negócio soube informar essas metas. Como o NFRD será derivado deste PRD, registro aqui como lacuna explícita a ser fechada antes ou durante a elaboração do NFRD, não como requisito já definido:

- Disponibilidade-alvo do portal e janelas de manutenção aceitáveis.
- Volume de pico esperado (o ciclo mensal de pedidos concentra carga em dias específicos do mês, dado o relato de "todo dia 20").
- SLA de crédito com o CMT (quanto tempo entre pagamento confirmado e crédito no cartão) — hoje o relato indica D+2 apenas para o repasse do boleto, sem clareza sobre o prazo total até o crédito.
- Requisitos de proteção de dados pessoais de colaboradores (nome, CPF, matrícula): o jurídico ainda não se manifestou sobre base legal de tratamento (provavelmente execução de contrato ou obrigação legal, a confirmar) nem sobre prazo de retenção. Este ponto bloqueia parte do NFRD e deve ser escalado antes do início do TRD, dado que envolve dado sensível de CPF.

## 8. Decisões técnicas já sinalizadas (para o TRD, não deste documento)

No workshop, o tech lead comentou a intenção de expor `POST /v1/pedidos-recarga`, persistir em uma tabela `pedido_recarga_item` no Postgres e usar fila no RabbitMQ para o envio ao CMT. Registro aqui apenas como sinal de intenção arquitetural levantado em discovery — é decisão de design/arquitetura a ser formalizada no TRD, e não deve ser tratada como requisito de produto nem congelada neste PRD.

## 9. Métricas de sucesso

- Redução do tempo de execução do pedido mensal de recarga por cliente, partindo da referência atual de aproximadamente dois dias úteis por mês por analista.
- Redução a zero (ou a um número alvo a definir com o negócio) de casos de colaborador sem recarga por rejeição não detectada a tempo, partindo do caso relatado de 37 colaboradores em um único cliente em um único mês.
- Tempo de resolução de divergência de conciliação financeira, partindo da referência atual de três semanas para um caso de R$ 4.180.
- Número de empresas clientes ativas no portal, acompanhando a meta comercial de 40 empresas até março de 2027 (partindo de 14 hoje no processo por CSV).

## 10. Perguntas em aberto para o FRD/NFRD/TRD

1. Qual o canal e o dono do dado de contato para notificar o colaborador final sobre o crédito (RF4.1)?
2. Pix será viabilizado como meio de pagamento nesta fase ou fica para uma fase posterior (RF3.4)?
3. Quais são as metas de disponibilidade, volume de pico e SLA de crédito com o CMT (seção 7)?
4. Qual a base legal e o prazo de retenção para os dados pessoais de colaboradores (seção 7) — pendência formal do jurídico?
5. A intenção arquitetural relatada pelo tech lead (seção 8) já é compromisso de design ou ainda está aberta a alternativas no TRD?
6. Existe hoje um processo de suporte/operações interno que deva ser mapeado como ator adicional no FRD, dado o volume de erro absorvido hoje pelo processo manual?

## 11. Rastreabilidade das fontes

- Entrevista 1 (Clara Mendes) → seções 2, 5 (J1, J2 — RF1.1, RF2.1), 9.
- Entrevista 2 (Rogério Alves) → seções 2, 5 (J3 — RF3.1, RF3.2, RF3.4), 9.
- Entrevista 3 (Denise Couto) → seções 5 (RF4.1), 10.
- Jornadas do workshop (J1, J2, J3) → seção 5.
- Notas de discovery → seções 1, 3, 6, 7, 8.
