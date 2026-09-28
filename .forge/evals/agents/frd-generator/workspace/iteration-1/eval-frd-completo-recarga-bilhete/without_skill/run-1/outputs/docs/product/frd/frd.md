# FRD - Recarga Metropolitana

**Produto:** Recarga Metropolitana
**Versão:** v1.0
**Data:** 2026-09-26
**Status:** Rascunho para revisão de engenharia e QA
**Origem:** `docs/product/prd/prd.md` (aprovado em 2026-09-09) e `docs/discovery/discovery-notes.md`

## 1. Objetivo e escopo deste documento

Este FRD detalha, em nível funcional, as seis funcionalidades aprovadas no PRD da Recarga Metropolitana (F-01 a F-06), de modo que engenharia e QA possam quebrar o backlog em tasks a partir de segunda-feira, sem depender de negociação adicional de escopo com produto. Cada requisito funcional (RF) carrega critérios de aceite testáveis, regras de negócio associadas, mensagens de erro e permissões por perfil. A rastreabilidade com o PRD é explícita em cada seção e consolidada na matriz da seção 8.

Ficam fora deste FRD, por herdarem diretamente o "Fora de escopo" do PRD: programa de fidelidade ou cashback, recarga por boleto, transferência de saldo entre cartões e venda de cartão novo pelo app.

## 2. Perfis e permissões

| Perfil | Código PRD | O que pode fazer neste FRD |
|---|---|---|
| Passageiro | P-01 | Cadastro, login, vínculo de cartão, recarga, consulta de saldo/extrato, abertura de contestação, bloqueio de cartão próprio |
| Atendente SAC | P-02 | Consulta de recargas de qualquer passageiro, abertura de contestação em nome do passageiro, acompanhamento de contestações |
| Analista Financeiro | P-03 | Consulta de conciliação, aprovação ou recusa de estorno de contestação |

Duas lacunas do PRD (seção "Pontos em aberto") afetam diretamente permissões e prazos deste FRD e ficam registradas como pendências de decisão, não como suposição do time de engenharia:

- Não está definido se o atendente SAC pode bloquear cartão em nome do passageiro (afeta RF-06). Até decisão do produto, este FRD trata o bloqueio como ação exclusiva do próprio passageiro (RF-06.1), e a ação do SAC fica marcada como **NEEDS CLARIFICATION** em RF-06.
- Não está definido o prazo para abertura de contestação (afeta RF-05). Este FRD assume, como valor de trabalho a confirmar com produto, o prazo de 90 dias corridos a partir da data da recarga, por ser o mesmo horizonte do extrato (F-04). Está marcado como **NEEDS CLARIFICATION** em RF-05.
- O valor máximo por recarga (RN-04 do PRD) está pendente de definição jurídica. Este FRD assume um teto de configuração (parâmetro `recarga.valor_maximo_centavos`) para não bloquear o desenvolvimento, com valor inicial de R$ 500,00 (50000 centavos) sujeito a confirmação jurídica antes do go-live.

## 3. RF-01 — Cadastro e login (rastreia F-01)

### 3.1 Descrição

Permite que o passageiro crie uma conta com CPF, e-mail e senha, e realize login subsequente com e-mail e senha.

### 3.2 Critérios de aceite

- CA-01.1: dado um CPF válido (dígitos verificadores corretos) ainda não cadastrado, um e-mail em formato válido ainda não cadastrado e uma senha que atende à política de senha (mínimo 8 caracteres, ao menos uma letra e um número), quando o passageiro submete o cadastro, então a conta é criada com status ativo e o passageiro é autenticado automaticamente.
- CA-01.2: dado um CPF com dígito verificador inválido, quando o passageiro submete o cadastro, então o cadastro é rejeitado com a mensagem de erro E-01.1 e nenhuma conta é criada.
- CA-01.3: dado um CPF já cadastrado, quando o passageiro submete novo cadastro com o mesmo CPF, então o cadastro é rejeitado com a mensagem E-01.2.
- CA-01.4: dado um e-mail já cadastrado, quando o passageiro submete novo cadastro com o mesmo e-mail, então o cadastro é rejeitado com a mensagem E-01.3.
- CA-01.5: dado um e-mail e senha corretos de uma conta ativa, quando o passageiro faz login, então uma sessão válida é criada.
- CA-01.6: dado um e-mail cadastrado com senha incorreta, quando o passageiro tenta login, então o acesso é negado com a mensagem E-01.4, sem indicar se o e-mail existe ou não.
- CA-01.7: dado um e-mail não cadastrado, quando alguém tenta login, então o acesso é negado com a mesma mensagem E-01.4 (evita enumeração de contas).
- CA-01.8: após 5 tentativas de login malsucedidas para a mesma conta em 15 minutos, a conta é temporariamente bloqueada para login por 15 minutos, e a tentativa seguinte recebe a mensagem E-01.5.

### 3.3 Regras de negócio

- RN-F01-01: o CPF é validado por algoritmo de dígito verificador antes de qualquer chamada a serviço externo.
- RN-F01-02: CPF e e-mail são chaves únicas por conta; não há duas contas ativas com o mesmo CPF ou o mesmo e-mail.
- RN-F01-03: senhas nunca são armazenadas em texto puro; armazenamento via hash com salt (algoritmo a definir em design técnico, fora de escopo deste FRD).
- RN-F01-04: o bloqueio por tentativas malsucedidas (CA-01.8) é por conta, não por IP, para não impactar múltiplos passageiros atrás do mesmo NAT.

### 3.4 Mensagens de erro

| Código | Situação | Mensagem ao usuário |
|---|---|---|
| E-01.1 | CPF inválido | "CPF inválido. Confira os números digitados." |
| E-01.2 | CPF já cadastrado | "Este CPF já possui uma conta. Faça login ou recupere sua senha." |
| E-01.3 | E-mail já cadastrado | "Este e-mail já está em uso. Faça login ou recupere sua senha." |
| E-01.4 | Credenciais inválidas | "E-mail ou senha incorretos." |
| E-01.5 | Conta temporariamente bloqueada | "Muitas tentativas. Tente novamente em 15 minutos." |

### 3.5 Permissões

Fluxo público (sem autenticação prévia) para cadastro e login. Não se aplica a SAC nem a financeiro, que possuem autenticação própria fora de escopo deste FRD (ferramentas internas do consórcio).

## 4. RF-02 — Vincular cartão de transporte (rastreia F-02)

### 4.1 Descrição

Permite que o passageiro autenticado vincule à sua conta um cartão de transporte físico, informando o número impresso (16 dígitos) e a data de nascimento do titular do cartão, respeitando o limite de 5 cartões por conta.

### 4.2 Critérios de aceite

- CA-02.1: dado um passageiro autenticado com menos de 5 cartões vinculados, um número de cartão de 16 dígitos existente na base de cartões emitidos e a data de nascimento correta do titular, quando o passageiro submete o vínculo, então o cartão passa a constar na lista de cartões da conta com status "vinculado".
- CA-02.2: dado um número de cartão com quantidade de dígitos diferente de 16, quando o passageiro submete o vínculo, então a operação é rejeitada com a mensagem E-02.1.
- CA-02.3: dado um número de cartão de 16 dígitos que não existe na base de cartões emitidos, quando o passageiro submete o vínculo, então a operação é rejeitada com a mensagem E-02.2.
- CA-02.4: dado um número de cartão válido e existente, mas com data de nascimento informada divergente da registrada para o titular, quando o passageiro submete o vínculo, então a operação é rejeitada com a mensagem E-02.3.
- CA-02.5: dado um cartão já vinculado a outra conta, quando um segundo passageiro tenta vincular o mesmo cartão, então a operação é rejeitada com a mensagem E-02.4 (um cartão pertence a uma única conta por vez).
- CA-02.6: dado um passageiro que já possui 5 cartões vinculados, quando ele tenta vincular um sexto cartão, então a operação é rejeitada com a mensagem E-02.5.
- CA-02.7: dado um cartão com status "bloqueado" (RF-06), quando o titular da conta tenta revincular esse mesmo cartão à mesma conta, então o sistema permite a consulta do cartão na lista, mas mantém o status "bloqueado" — vínculo não reativa cartão bloqueado.

### 4.3 Regras de negócio

- RN-F02-01: o vínculo exige posse implícita do cartão físico (número impresso) e conhecimento de um dado pessoal do titular (data de nascimento) como fator de verificação; não há validação biométrica ou documento neste v1.
- RN-F02-02: o limite de 5 cartões por conta é contado apenas sobre cartões com status "vinculado" ou "bloqueado"; não há como o PRD ou a discovery indicarem exceção a este limite.
- RN-F02-03: um cartão vinculado a uma conta não pode ser vinculado simultaneamente a outra conta (CA-02.5); o desvínculo está fora de escopo deste v1, pois o PRD não descreve essa funcionalidade — registrado como lacuna a validar com produto antes da implementação, e não assumido como implícito.

### 4.4 Mensagens de erro

| Código | Situação | Mensagem ao usuário |
|---|---|---|
| E-02.1 | Número de cartão com formato inválido | "Número do cartão deve ter 16 dígitos." |
| E-02.2 | Cartão não encontrado | "Não encontramos esse cartão. Confira o número impresso." |
| E-02.3 | Data de nascimento divergente | "Data de nascimento não confere com o titular do cartão." |
| E-02.4 | Cartão já vinculado a outra conta | "Este cartão já está vinculado a outra conta." |
| E-02.5 | Limite de cartões atingido | "Limite de 5 cartões por conta atingido." |

### 4.5 Permissões

Somente o passageiro autenticado (P-01) vincula cartão à própria conta. SAC (P-02) tem acesso apenas de consulta a cartões vinculados de um passageiro (ver RF-05), sem poder vincular cartão em nome dele — o PRD não descreve essa ação para o SAC.

## 5. RF-03 — Recarregar cartão (rastreia F-03, RN-01, RN-02, RN-03, RN-04)

### 5.1 Descrição

Permite que o passageiro autenticado escolha um dos seus cartões vinculados e ativos, informe um valor de recarga (mínimo R$ 5,00) e pague por Pix ou cartão de crédito. O crédito só é gerado após confirmação do pagamento.

### 5.2 Critérios de aceite

- CA-03.1: dado um cartão vinculado com status "vinculado" (não bloqueado) e um valor de recarga maior ou igual a R$ 5,00 (500 centavos) e menor ou igual ao teto vigente (`recarga.valor_maximo_centavos`), quando o passageiro escolhe Pix e o pagamento é confirmado pelo provedor de pagamento, então o crédito é registrado no sistema com status "pago, aguardando sincronização".
- CA-03.2: nas mesmas condições de CA-03.1, mas pagando por cartão de crédito, quando a transação é aprovada, então o crédito é registrado com status "pago, aguardando sincronização".
- CA-03.3: dado um valor de recarga menor que R$ 5,00, quando o passageiro tenta iniciar a recarga, então a operação é rejeitada com a mensagem E-03.1 antes de qualquer chamada ao provedor de pagamento.
- CA-03.4: dado um valor de recarga maior que o teto vigente, quando o passageiro tenta iniciar a recarga, então a operação é rejeitada com a mensagem E-03.2 antes de qualquer chamada ao provedor de pagamento.
- CA-03.5: dado um cartão com status "bloqueado", quando o passageiro tenta recarregá-lo, então a operação é rejeitada com a mensagem E-03.3 (RN-03 do PRD), sem chamar o provedor de pagamento.
- CA-03.6: dado um pagamento por Pix não confirmado em até 30 minutos (janela de expiração do QR code, valor de referência a confirmar em design técnico), quando o passageiro consulta o status, então a recarga aparece como "expirada" e nenhum crédito é gerado.
- CA-03.7: dado um pagamento por cartão de crédito recusado pela operadora, quando a recusa é recebida, então a recarga aparece como "recusada" e nenhum crédito é gerado, com a mensagem E-03.4.
- CA-03.8: dado um cartão que já recebeu uma recarga confirmada de exatamente o mesmo valor há menos de 2 minutos, quando o passageiro tenta submeter nova recarga de mesmo valor para o mesmo cartão, então a operação é rejeitada com a mensagem E-03.5 (RN-02 do PRD, proteção contra duplicidade).
- CA-03.9: dado um crédito registrado com status "pago, aguardando sincronização", quando o próximo ciclo de sincronização do validador ocorre (até 30 minutos, conforme discovery), então o crédito passa a estar disponível no validador do ônibus.

### 5.3 Regras de negócio

- RN-F03-01 (= RN-01 do PRD): a recarga só gera crédito disponível após confirmação do pagamento pelo provedor; nunca antes.
- RN-F03-02 (= RN-02 do PRD): um mesmo cartão não recebe duas recargas confirmadas de mesmo valor em menos de 2 minutos. A checagem de duplicidade considera cartão + valor + janela de 2 minutos a partir da confirmação da recarga anterior, não do início da tentativa.
- RN-F03-03 (= RN-03 do PRD): cartão com status "bloqueado" não recebe recarga, verificado antes de acionar o provedor de pagamento.
- RN-F03-04 (= RN-04 do PRD, pendente jurídico): o valor máximo por recarga é parametrizável (`recarga.valor_maximo_centavos`); valor inicial de trabalho R$ 500,00, a confirmar com jurídico antes do go-live. Enquanto não confirmado, QA testa contra o valor parametrizado vigente, não contra um número fixo no código.
- RN-F03-05: o ciclo de sincronização do validador (até 30 minutos) é uma limitação de hardware do equipamento atual (conforme discovery notes) e não depende do backend da Recarga Metropolitana; o FRD trata isso como expectativa de SLA a comunicar ao passageiro na tela de confirmação, não como algo que o time de recarga controla diretamente.
- RN-F03-06: todo valor monetário é tratado internamente em centavos (inteiro), nunca em ponto flutuante, para evitar erro de arredondamento em conciliação financeira.

### 5.4 Mensagens de erro

| Código | Situação | Mensagem ao usuário |
|---|---|---|
| E-03.1 | Valor abaixo do mínimo | "O valor mínimo de recarga é R$ 5,00." |
| E-03.2 | Valor acima do máximo permitido | "O valor máximo de recarga é R$ [valor vigente]." |
| E-03.3 | Cartão bloqueado | "Este cartão está bloqueado e não pode receber recarga." |
| E-03.4 | Pagamento recusado | "Pagamento não aprovado. Tente novamente ou use outro método." |
| E-03.5 | Recarga duplicada | "Já identificamos uma recarga de mesmo valor para este cartão há poucos instantes. Aguarde alguns minutos." |

### 5.5 Permissões

Somente o passageiro autenticado (P-01) inicia recarga, e apenas para cartões da própria conta. SAC e financeiro não iniciam recarga em nome do passageiro — essa ação não consta no PRD para esses perfis.

## 6. RF-04 — Consultar saldo e extrato (rastreia F-04)

### 6.1 Descrição

Permite que o passageiro autenticado consulte o saldo atual e o histórico de recargas e usos dos últimos 90 dias, por cartão vinculado.

### 6.2 Critérios de aceite

- CA-04.1: dado um passageiro autenticado com ao menos um cartão vinculado, quando ele acessa a consulta de saldo, então o sistema exibe o saldo atual de cada cartão vinculado (vinculado ou bloqueado).
- CA-04.2: dado um cartão com movimentações (recargas e/ou usos em validador) nos últimos 90 dias, quando o passageiro acessa o extrato desse cartão, então o sistema lista as movimentações em ordem cronológica decrescente, com data, tipo (recarga ou uso), valor e status.
- CA-04.3: dado um cartão sem nenhuma movimentação nos últimos 90 dias, quando o passageiro acessa o extrato, então o sistema exibe uma lista vazia com mensagem informativa, não um erro.
- CA-04.4: dado o extrato de um cartão, quando o passageiro solicita movimentações anteriores a 90 dias, então o sistema não retorna esses dados (fora do escopo definido pelo PRD para v1) e informa ao usuário o limite de 90 dias.
- CA-04.5: dado um crédito com status "pago, aguardando sincronização" (RF-03), quando exibido no extrato, então aparece com um indicador visual distinto de "processando", diferente de um crédito já "disponível" — atendendo à dor central do discovery ("não saber se a recarga caiu").

### 6.3 Regras de negócio

- RN-F04-01: a janela de consulta de extrato é de 90 dias corridos a partir da data da consulta, conforme F-04 do PRD.
- RN-F04-02: o extrato reflete o status real de sincronização do crédito (RN-F03-05), nunca apresenta um crédito como "disponível" antes da confirmação de sincronização do validador.

### 6.4 Mensagens de erro

| Código | Situação | Mensagem ao usuário |
|---|---|---|
| E-04.1 | Extrato sem movimentações | "Nenhuma movimentação nos últimos 90 dias." |
| E-04.2 | Solicitação de período além de 90 dias | "Só é possível consultar os últimos 90 dias." |

### 6.5 Permissões

O passageiro (P-01) consulta apenas saldo e extrato dos próprios cartões. O SAC (P-02) consulta saldo e extrato de qualquer passageiro, mediante identificação do cartão ou da conta, exclusivamente no contexto de atendimento (RF-05); esta consulta ampla do SAC é necessária para F-05 do PRD e fica registrada aqui como extensão de RF-04 para esse perfil. O analista financeiro (P-03) não consulta extrato individual do passageiro por esta funcionalidade; sua visão é a de conciliação agregada, fora do escopo detalhado deste FRD (mencionada na discovery como planilha manual, sem funcionalidade correspondente no PRD além de RF-05).

## 7. RF-05 — Contestação de recarga (rastreia F-05, discovery: ~900 reclamações/mês)

### 7.1 Descrição

Permite que o passageiro, ou o atendente SAC em nome do passageiro, conteste uma recarga que foi paga mas não gerou crédito no cartão. O analista financeiro aprova ou nega o estorno.

### 7.2 Critérios de aceite

- CA-05.1: dado uma recarga com status "pago, aguardando sincronização" há mais tempo do que o ciclo esperado de sincronização (30 minutos) sem ter virado crédito "disponível", quando o passageiro abre uma contestação para essa recarga, então uma contestação é criada com status "aberta", vinculada à recarga original.
- CA-05.2: dado uma recarga já com crédito "disponível", quando alguém tenta abrir contestação para ela, então a operação é rejeitada com a mensagem E-05.1 (não há o que contestar).
- CA-05.3: dado um passageiro que liga ou comparece ao SAC relatando recarga não creditada, quando o atendente SAC abre a contestação em nome do passageiro, então a contestação é criada com status "aberta", com o campo "aberta por" registrando o atendente e o passageiro associado.
- CA-05.4: dado uma contestação com status "aberta", quando o analista financeiro consulta a fila de contestações, então ela aparece disponível para análise, com os dados da recarga original (valor, cartão, método de pagamento, timestamps).
- CA-05.5: dado uma contestação em análise, quando o analista financeiro aprova o estorno, então a contestação passa para status "estorno aprovado" e um evento de estorno é registrado para o meio de pagamento original (Pix ou cartão de crédito).
- CA-05.6: dado uma contestação em análise, quando o analista financeiro identifica que o crédito na verdade foi aplicado (falso positivo, ex.: atraso maior que o normal na sincronização), quando ele nega o estorno, então a contestação passa para status "negada" com justificativa obrigatória em texto livre.
- CA-05.7: dado uma contestação com qualquer status, quando o passageiro ou o SAC consulta o acompanhamento, então o status atual e a justificativa (se negada) são exibidos.
- CA-05.8 **(NEEDS CLARIFICATION — prazo não definido pelo PRD)**: dado o prazo de abertura de contestação assumido neste FRD como 90 dias corridos a partir da recarga (ver seção 2), quando o passageiro tenta contestar uma recarga fora desse prazo, então a operação é rejeitada com a mensagem E-05.2. Este critério e o prazo de 90 dias devem ser confirmados com produto antes da implementação; QA deve tratar o número como parâmetro, não como valor fixo de teste.

### 7.3 Regras de negócio

- RN-F05-01: uma recarga só pode ter uma contestação "aberta" por vez; uma nova tentativa de abertura enquanto já existe uma contestação aberta para a mesma recarga é rejeitada com a mensagem E-05.3 e direciona para o acompanhamento da contestação existente.
- RN-F05-02: somente recargas com pagamento confirmado, mas sem crédito "disponível" após o ciclo esperado de sincronização, são elegíveis para contestação (CA-05.1); recarga com pagamento recusado ou expirado (RF-03) não gera contestação, pois não houve cobrança.
- RN-F05-03: a aprovação de estorno (CA-05.5) dispara a devolução ao meio de pagamento original; a Recarga Metropolitana não faz estorno em outro meio de pagamento diferente do usado na recarga original.
- RN-F05-04: toda decisão do analista financeiro (aprovação ou negativa) é auditável — registra identificação do analista, timestamp e, quando negada, a justificativa (RN de domínio: dado financeiro exige trilha de auditoria).

### 7.4 Mensagens de erro

| Código | Situação | Mensagem ao usuário |
|---|---|---|
| E-05.1 | Recarga já creditada, sem o que contestar | "Esta recarga já está disponível no seu cartão." |
| E-05.2 | Prazo de contestação expirado | "O prazo para contestar esta recarga já passou." |
| E-05.3 | Contestação duplicada | "Já existe uma contestação em aberto para esta recarga." |

### 7.5 Permissões

| Ação | Passageiro (P-01) | SAC (P-02) | Financeiro (P-03) |
|---|---|---|---|
| Abrir contestação para si mesmo | Sim | Não se aplica | Não |
| Abrir contestação em nome de um passageiro | Não | Sim | Não |
| Consultar/acompanhar contestação própria | Sim | Sim (de qualquer passageiro) | Sim (de qualquer passageiro, em fila de análise) |
| Aprovar ou negar estorno | Não | Não | Sim |

## 8. RF-06 — Bloqueio de cartão por perda (rastreia F-06)

### 8.1 Descrição

Permite que o passageiro bloqueie um cartão perdido, preservando o saldo para transferência futura (transferência em si é v2, fora de escopo, conforme PRD seção 7).

### 8.2 Critérios de aceite

- CA-06.1: dado um cartão com status "vinculado" pertencente à conta do passageiro autenticado, quando o passageiro solicita o bloqueio, então o cartão passa para status "bloqueado" imediatamente e o saldo existente é preservado, sem alteração de valor.
- CA-06.2: dado um cartão já com status "bloqueado", quando o passageiro tenta bloqueá-lo novamente, então o sistema informa que o cartão já está bloqueado (idempotente, não é tratado como erro bloqueante) e não gera novo evento de bloqueio.
- CA-06.3: dado um cartão bloqueado, quando qualquer tentativa de recarga é feita para esse cartão (RF-03), então ela é rejeitada conforme CA-03.5 / E-03.3.
- CA-06.4: dado um cartão bloqueado, quando o passageiro consulta a lista de cartões (RF-02) ou o extrato (RF-04), então o cartão aparece listado com status "bloqueado" e o histórico anterior ao bloqueio permanece visível.
- CA-06.5 **(NEEDS CLARIFICATION — PRD não define se o SAC pode bloquear em nome do passageiro)**: este FRD assume, até decisão de produto, que o bloqueio é ação exclusiva do passageiro autenticado (RF-06.1) e que o SAC não bloqueia cartão em nome de terceiros. Caso produto decida o contrário, este RF precisa de um novo ciclo de requisitos e critérios de aceite equivalentes aos de RF-02/RF-05 para ação em nome de terceiro (autenticação do relato, registro de quem solicitou), antes de virar task de engenharia.

### 8.3 Regras de negócio

- RN-F06-01: bloqueio de cartão não zera nem altera o saldo; o saldo permanece associado ao cartão bloqueado.
- RN-F06-02: cartão bloqueado não pode ser desbloqueado neste v1 — o PRD não descreve desbloqueio, apenas preservação de saldo para "transferência futura" (v2); a ausência de desbloqueio é tratada como escopo atual, não como lacuna a resolver agora.
- RN-F06-03: bloqueio é definitivo para fins de uso no validador (RN-F03-03) a partir do momento em que a solicitação é confirmada, sem janela de carência.

### 8.4 Mensagens de erro

| Código | Situação | Mensagem ao usuário |
|---|---|---|
| E-06.1 | Cartão não pertence à conta autenticada | "Este cartão não pertence à sua conta." |

### 8.5 Permissões

Somente o passageiro autenticado (P-01) bloqueia cartão da própria conta, até decisão de produto sobre CA-06.5. SAC e financeiro não têm ação de bloqueio neste FRD.

## 9. Requisitos não funcionais que afetam os RFs (referência rápida)

Este FRD é funcional; requisitos não funcionais completos (performance, disponibilidade, segurança de dados de pagamento, LGPD) pertencem a um NFRD ou ADR próprio, fora de escopo aqui. Ficam citados apenas os pontos que já aparecem implícitos no PRD e na discovery e que a engenharia precisa considerar ao dimensionar as tasks:

- Dados de pagamento (Pix, cartão de crédito) implicam aderência a padrões de segurança de pagamento na integração com o provedor; o desenho técnico dessa integração é responsabilidade do design técnico do módulo, não deste FRD.
- CPF e data de nascimento são dados pessoais sensíveis sob a LGPD; tratamento, retenção e consentimento também pertencem ao design técnico e a um DPIA, se aplicável, não a este FRD.
- O volume de ~900 reclamações/mês relatado na discovery dimensiona a fila de contestações (RF-05) esperada para o SAC e o financeiro; é um dado de contexto para dimensionamento de capacidade, não um requisito funcional em si.

## 10. Matriz de rastreabilidade com o PRD

| RF (FRD) | Funcionalidade (PRD) | Regra(s) de negócio do PRD | Jornada(s) do PRD |
|---|---|---|---|
| RF-01 | F-01 | — | J-01 (parte de cadastro) |
| RF-02 | F-02 | — | J-01 (parte de vínculo) |
| RF-03 | F-03 | RN-01, RN-02, RN-03, RN-04 | J-01 (recarga por Pix) |
| RF-04 | F-04 | — | J-01 (confirmação), J-02 (acompanhamento) |
| RF-05 | F-05 | — | J-02 (recarga não caiu) |
| RF-06 | F-06 | — | (não coberta explicitamente por J-01/J-02 no PRD) |

## 11. Pendências a resolver antes ou durante a implementação

| Pendência | Origem | RF afetado | Impacto se não resolvida a tempo |
|---|---|---|---|
| Valor máximo por recarga (RN-04) | PRD, seção 8 | RF-03 | QA testa contra parâmetro configurável; valor de R$ 500,00 é apenas provisório para não travar o desenvolvimento |
| Prazo para abrir contestação | PRD, seção 8 | RF-05 | FRD assume 90 dias como valor de trabalho; se produto decidir outro prazo, é mudança de configuração, não de arquitetura |
| SAC pode bloquear cartão em nome do passageiro? | PRD, seção 8 | RF-06 | Se a resposta for "sim", RF-06 precisa de novos critérios de aceite e permissões antes de virar task |
| Desvínculo de cartão (não descrito no PRD) | Observação deste FRD | RF-02 | Sem desvínculo, um cartão perdido do sistema de emissão (ex.: reemitido) pode ficar "preso" a uma conta; confirmar com produto se é lacuna aceitável para v1 |
