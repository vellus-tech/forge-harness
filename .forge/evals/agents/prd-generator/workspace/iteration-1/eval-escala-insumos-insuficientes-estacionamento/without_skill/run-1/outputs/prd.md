# PRD — Zona Azul Digital de Itajubá

## Status do documento

Este PRD foi escrito a partir de uma única fonte disponível — `docs/discovery/ideia.md`, uma anotação de conversa informal com o secretário de mobilidade — e não a partir de uma descoberta estruturada (personas validadas, requisitos legais confirmados, levantamento de sistemas existentes). Onde a anotação original não cobre uma decisão necessária para engenharia começar, este documento assume o padrão de mercado para apps de zona azul digital brasileiros e marca a premissa explicitamente na seção 11. Antes da primeira sprint, cada premissa marcada como **[ASSUMIDO]** precisa ser confirmada com a prefeitura — em especial modelo de cobrança, integração com o sistema de fiscalização existente e enquadramento legal municipal, porque uma suposição errada nesses três pontos invalida arquitetura inteira do módulo de pagamento e do módulo de fiscalização.

## 1. Sumário executivo

A Prefeitura de Itajubá (MG) quer substituir o talão de papel da Zona Azul por um aplicativo digital: o motorista compra e ativa o tempo de estacionamento pelo celular, e o fiscal confere a vigência da compra pela placa do veículo. O objetivo de negócio é reduzir fraude e evasão de receita do talão físico, agilizar a fiscalização e dar ao munícipe um canal de pagamento mais simples. Este documento define o escopo mínimo viável para a equipe de engenharia iniciar o desenvolvimento, com as premissas assumidas explicitadas para validação incremental com o cliente.

## 2. Problema e contexto

- Hoje a Zona Azul de Itajubá opera com talão de papel, que exige compra antecipada, é rasurável, e depende de conferência visual pelo fiscal.
- Não há visibilidade digital de ocupação de vagas nem de receita arrecadada.
- O pedido do secretário enfatiza dois fluxos como críticos: pagamento pelo motorista e conferência pelo fiscal via placa — o restante do produto orbita esses dois fluxos.

## 3. Objetivos e métricas de sucesso

| Objetivo | Métrica | Meta [ASSUMIDO] |
|---|---|---|
| Substituir o talão físico sem queda de arrecadação | Receita mensal da Zona Azul digital vs. média histórica do talão | ≥ 100% em 3 meses após lançamento |
| Reduzir tempo de fiscalização por vaga | Tempo médio de conferência por placa | < 15 segundos |
| Adoção pelo motorista | % de transações feitas pelo app vs. meios alternativos | ≥ 60% em 6 meses |
| Confiabilidade da fiscalização | Taxa de falso negativo (vaga paga marcada como não paga) | < 1% |

## 4. Personas

1. **Motorista/usuário pagante** — mora ou circula em Itajubá, estaciona no centro, quer pagar rápido sem precisar achar troco ou talão físico.
2. **Fiscal de trânsito da prefeitura** — percorre as ruas a pé ou de moto, precisa confirmar em segundos se uma placa está com o tempo pago, mesmo em áreas com sinal de internet instável.
3. **Gestor de mobilidade urbana (secretário e equipe)** — quer relatório de arrecadação, ocupação e autuações para tomada de decisão e prestação de contas.
4. **[ASSUMIDO] Operador financeiro/administrativo da prefeitura** — concilia a receita do app com o sistema financeiro municipal.

## 5. Escopo — MVP

### 5.1 App do motorista (mobile, iOS + Android [ASSUMIDO])

- Cadastro simplificado (nome, CPF, placa do veículo, telefone).
- Cadastro de um ou mais veículos por conta.
- Compra de crédito/tempo de Zona Azul por cartão de crédito e Pix [ASSUMIDO — meios de pagamento mais comuns nesse segmento no Brasil].
- Ativação do tempo de estacionamento por placa, com seleção de duração dentre as frações vigentes na legislação municipal [ASSUMIDO: 1h e 2h, prorrogável].
- Notificação push nos últimos 10 minutos antes do vencimento [ASSUMIDO].
- Histórico de compras e extrato para o usuário.
- Consulta de saldo de créditos pré-pagos, se o modelo de cobrança for pré-pago [ASSUMIDO — ver seção 11].

### 5.2 App do fiscal (mobile, uso em campo)

- Login com credencial funcional da prefeitura.
- Consulta de placa com retorno imediato: pago/vigente, expirado, ou sem registro.
- Funcionamento offline com sincronização posterior, para áreas de sinal instável [ASSUMIDO — requisito comum e crítico em apps de fiscalização de rua].
- Registro de autuação/notificação para placas sem pagamento vigente, com foto do veículo [ASSUMIDO].
- Histórico de consultas do turno do fiscal.

### 5.3 Painel administrativo (web)

- Dashboard de arrecadação por período, por rua/setor [ASSUMIDO — setorização das vias precisa ser confirmada com a prefeitura].
- Relatório de autuações emitidas.
- Gestão de tabela de preços e regras de vigência (dias/horários em que a Zona Azul é cobrada) [ASSUMIDO: seg-sex, 8h-18h, exceto feriados — padrão nacional mais comum].
- Exportação de dados para conciliação financeira.
- Gestão de usuários administrativos e fiscais (papéis e permissões).

### 5.4 Backend / integrações

- API central de validação de placa + vigência, consumida pelo app do fiscal.
- Gateway de pagamento (cartão + Pix) via provedor terceirizado [ASSUMIDO: integração via Stripe, Pagar.me ou similar — a decisão final depende de contrato já existente da prefeitura, que não consta na anotação original].
- **[ASSUMIDO — pendência crítica]** Integração com o sistema de fiscalização de trânsito já usado pela prefeitura (se houver um DETRAN-MG ou sistema de multas municipal em uso), para que autuações registradas no app cheguem ao fluxo oficial de notificação de infração. Sem essa confirmação, o app de fiscalização fica isolado do processo legal de cobrança de multa.
- Base de dados de vias e vagas da Zona Azul (setores, capacidade, preço por setor).

## 6. Fora de escopo (nesta primeira versão)

- Sensores de vaga (IoT) para detecção automática de ocupação.
- Reserva antecipada de vaga.
- Integração com apps de terceiros (Waze, Google Maps) para exibir ocupação em tempo real.
- Emissão automática de boleto/carnê mensal para usuários recorrentes.
- Modelo de assinatura mensal (será avaliado em versão futura, se o modelo pré-pago validar).

## 7. Requisitos não funcionais

- **Disponibilidade:** API de validação de placa é o componente mais crítico — indisponibilidade impede fiscalização e gera risco jurídico (autuação indevida). Meta [ASSUMIDO]: 99,5% em horário de cobrança.
- **LGPD:** o app trata CPF, placa e dados de pagamento de pessoa física — exige política de privacidade, base legal de tratamento e retenção de dados definida antes do lançamento. Este ponto não está endereçado na anotação original e precisa de validação jurídica com a prefeitura.
- **PCI DSS:** se o processamento de cartão não for inteiramente delegado a um gateway certificado, o escopo de conformidade PCI recai sobre o app — recomenda-se delegar 100% do processamento ao gateway (tokenização, sem armazenar dado de cartão).
- **Desempenho:** consulta de placa pelo fiscal precisa responder em menos de 3 segundos em conexão 3G/4G padrão de rua [ASSUMIDO].
- **Acessibilidade:** app do motorista segue diretrizes básicas de acessibilidade mobile (contraste, tamanho de toque), dado o público idoso que também estaciona no centro da cidade.

## 8. Riscos e dependências

| Risco | Impacto | Mitigação |
|---|---|---|
| Modelo de cobrança (pré-pago vs. por sessão) não confirmado pelo cliente | Refação de arquitetura de pagamento | Validar com o secretário antes do início da sprint de pagamento |
| Ausência de integração confirmada com sistema de multas municipal | Autuação registrada no app sem efeito legal | Levantar com a prefeitura se existe sistema de trânsito integrável |
| Cobertura de internet instável em campo para o fiscal | Falha de fiscalização | Modo offline com fila de sincronização |
| Enquadramento legal da Zona Azul digital (lei municipal vigente pode exigir características específicas, como o talão físico como alternativa obrigatória) | Risco jurídico/contratual | Validar com jurídico da prefeitura se o talão físico precisa continuar coexistindo |
| Prazo "hoje" para entrega do PRD sem descoberta completa | Requisitos incompletos chegarem à engenharia | Marcar este PRD como v0.1 e agendar sessão de validação com o secretário nos próximos dias |

## 9. Cronograma sugerido [ASSUMIDO — não solicitado explicitamente, incluído como referência de planejamento]

1. Semana 1-2: validação das premissas críticas (seção 11) + design de telas do app do motorista e do fiscal.
2. Semana 3-6: desenvolvimento do MVP (cadastro, pagamento, ativação, consulta de placa).
3. Semana 7: piloto controlado em um setor único do centro de Itajubá.
4. Semana 8: ajustes pós-piloto e expansão gradual para os demais setores.

## 10. Perguntas em aberto para o secretário de mobilidade

1. O modelo de cobrança será pré-pago (créditos) ou por sessão (paga e ativa na hora)?
2. Existe hoje algum sistema de fiscalização/multas municipal com o qual o app precisa se integrar?
3. Quais são os setores/ruas cobertos pela Zona Azul e os preços vigentes por setor?
4. O talão de papel será desligado imediatamente ou vai coexistir com o app por um período de transição?
5. Há um provedor de pagamento (gateway) já contratado pela prefeitura, ou a escolha é livre?
6. Existe alguma exigência legal municipal específica (lei ou decreto) que regula a Zona Azul e precisa ser respeitada no produto?

## 11. Lista consolidada de premissas assumidas

Todas as premissas abaixo foram assumidas por padrão de mercado, na ausência de informação em `docs/discovery/ideia.md`, e precisam de confirmação antes ou durante a implementação:

- Plataformas mobile: iOS + Android.
- Meios de pagamento: cartão de crédito e Pix.
- Frações de tempo: 1h e 2h, prorrogável.
- Notificação de vencimento: 10 minutos antes.
- Modo offline no app do fiscal.
- Registro fotográfico na autuação.
- Horário de cobrança: dias úteis, 8h-18h, exceto feriados.
- Gateway de pagamento terceirizado com tokenização (sem custódia de dado de cartão pela prefeitura).
- Meta de disponibilidade de 99,5% e resposta de consulta de placa em até 3 segundos.
- Cronograma de 8 semanas até o piloto.
