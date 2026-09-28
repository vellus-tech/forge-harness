# Pendências para o PRD — Zona Azul digital de Itajubá

> O PRD completo (`prd.md`) ainda não foi produzido. O único insumo disponível — `docs/discovery/ideia.md` — é uma nota de uma conversa informal, com cerca de três frases, e cobre bem menos de 50% das 13 seções do template obrigatório (só dá para inferir, com evidência fraca, um recorte de Contexto/Problema e duas personas prováveis: motorista e fiscal). Conforme a regra de escalada do agente, a escrita foi pausada em vez de completar o restante com suposições ou "padrão de mercado" — nenhum requisito, meta, tarifa, prazo ou base legal foi inventado.

## Lacunas que bloqueiam o PRD

| Código | Lacuna ou Ponto a Validar | Impacto Potencial | Responsável pela Validação | Status |
|---|---|---|---|---|
| LAC-01 | Tarifa por hora/fração e tempo máximo de permanência por vaga | Sem isso não há regra de cobrança nem RF de tarifação — núcleo do produto | Secretaria de Mobilidade de Itajubá | Aberto |
| LAC-02 | Número de vagas/setores azuis e delimitação geográfica (ruas, quadras, zonas) | Define escopo operacional, capacidade e desenho de mapa/seleção de vaga no app | Secretaria de Mobilidade de Itajubá | Aberto |
| LAC-03 | Meios de pagamento aceitos (cartão, Pix, saldo pré-pago, carteira digital) e regras de estorno | Afeta requisitos funcionais de pagamento e integrações a endereçar no TRD | Secretaria de Mobilidade / Financeiro | Aberto |
| LAC-04 | Regras de fiscalização e autuação (o que caracteriza infração, prazo de tolerância, integração com o fiscal, emissão de multa) | Sem isso, a jornada do fiscal e os RFs de conferência por placa não podem ser especificados com precisão | Secretaria de Mobilidade / Guarda Municipal | Aberto |
| LAC-05 | Lei municipal, decreto ou norma que regula a Zona Azul de Itajubá (base legal do serviço, tarifas, sanções) | Sem base legal citada, não é possível preencher § 8.8 Compliance nem justificar restrições regulatórias | Secretaria de Mobilidade / Jurídico do Município | Aberto |
| LAC-06 | Personas além de motorista e fiscal (ex.: administrador municipal do sistema, operador de retaguarda, contabilidade/tesouraria da prefeitura, cidadão que denuncia irregularidade) | Sem elas, § 3 Personas e os RFs de backoffice ficam incompletos | Secretaria de Mobilidade de Itajubá | Aberto |
| LAC-07 | Metas de negócio e volumes (nº esperado de usuários/dia, transações/dia, pico de uso, meta de adesão) | Necessário para § 8.7 Escalabilidade e Capacidade e § 11 Métricas de Sucesso | Secretaria de Mobilidade de Itajubá | Aberto |
| LAC-08 | Tratamento de dados pessoais — placas de veículo e dados do condutor sob a LGPD (base legal, retenção, compartilhamento com a fiscalização) | Sem isso, § 8.4 Privacidade e Proteção de Dados não pode ser preenchida sem suposição | Encarregado de Dados (DPO) do Município / Jurídico | Aberto |
| LAC-09 | Prazo e orçamento do projeto, e se há sistema legado (talão de papel) a ser descontinuado ou convivendo em transição | Afeta § 2.5 Sistemas Existentes e o roadmap de migração | Secretaria de Mobilidade de Itajubá | Aberto |
| LAC-10 | Meta de disponibilidade do serviço e canal de suporte ao cidadão em caso de falha de pagamento em campo | Necessário para § 8.1 Disponibilidade e § 8.6 Observabilidade | Secretaria de Mobilidade / TI do Município | Aberto |

## Por que o PRD não foi escrito hoje

O pedido do usuário foi "completa com o que é padrão nesse tipo de app" para tudo que faltar. Isso violaria diretamente as Regras Absolutas do agente `prd-generator` (nunca assumir tarifas, regras de negócio, prazos ou obrigações regulatórias sem evidência nos insumos) e o critério de escalada ("quando os insumos forem insuficientes para produzir mais de 50% das seções, pause a escrita e devolva ao usuário a lista de informações faltantes antes de prosseguir"). A nota de discovery cobre, na melhor das hipóteses, o Resumo Executivo e uma fração de Contexto/Problema e Personas — as 10 lacunas acima tocam praticamente todas as demais seções (Escopo, Requisitos Funcionais, Requisitos Não Funcionais, Restrições/Premissas, Riscos, Métricas, Compliance).

**Próximo passo:** responder as 10 lacunas acima (ou indicar que o secretário "vai mandar mais coisa depois", conforme a própria nota) para que o PRD completo seja produzido com rastreabilidade real.
