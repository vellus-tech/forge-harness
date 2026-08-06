# Bloco 0 — triagem e desbloqueio (2026-08-03)

> Saída do Bloco 0 do plano de execução sequencial de 03/08. Nenhum código foi tocado neste bloco: ele produz um aviso operacional, uma recomendação de decisão para o usuário, uma issue reconciliada e três textos de cobrança prontos para envio. Sucede o checkpoint de [30/07](./2026-07-30-checkpoint-e-handoff.md).

## 0.1 — Aviso: o CI do `axis-go-cloud` está parado por billing, não por regressão

Não é tarefa de agente e não foi investigado além do já confirmado. As 29 execuções do `regression-nightly.yml` desde que o workflow existe falharam **sem executar um único passo**, com a mensagem de conta: *"recent account payments have failed or your spending limit needs to be increased"*. Não existe artifact de nenhuma delas, o que é consistente com falha anterior ao provisionamento do runner, não com falha de teste.

**Ação exclusiva do usuário**: GitHub → Settings → Billing & plans da conta que hospeda o `axis-go-cloud`. Enquanto isso não for resolvido, nenhum bloco desta sequência pode contar com CI verde nesse repositório — o Bloco 1 (fix de mTLS) vai depender inteiramente de `dotnet test` local, e o PR vai nascer sem checks.

## 0.2 — Acks pendentes do liaison no `Axis.PadSimulator`: recomendação

`liaison-ops.sh sync axis-contracts` rodou limpo (0 novas, 39 duplicatas, 0 conflitos, 0 em quarentena) e `check-liaison-acks.sh` continua reprovando com as mesmas 6 mensagens da thread `msa-tenant-canonical-identity`, todas com `requires_ack: true` e `enforce: block`.

### As 6 mensagens são 3 decisões

| msg_id | O que é | Corpo |
|---|---|---|
| `axis-fare-validator-0002` | `thread-open` da thread — carrega o enunciado curto da decisão | inline |
| `axis-fare-validator-0003` | a decisão formal do owner em 5 pontos | inline |
| `axis-device-platform-0004` | o ADP retrata publicamente a posição anterior (duas identidades) e adota `tenant_id` como canônico | blob `10d0028…-liaison-msa-supersede.txt` |
| `axis-device-platform-0005` | correção factual do 0004 sobre RLS/`scope_msa_ids`, e fixação da cardinalidade em 1:1 | blob `da5d419…-liaison-msa-correcao-rls.txt` |
| `axis-fare-validator-0009` | supersessão canônica, texto longo — supersede formalmente `axis-device-platform-0003` do canal antigo | inline |
| `axis-fare-validator-0013` | reemissão literal de `-0009`, porque a colisão de seq no log apagou silenciosamente a obrigação de ACK, não o histórico | blob `8e03ff4…-reemissao-msa-tenant.md` |

Descontando `-0002` (abertura de `-0003`) e `-0013` (reemissão de `-0009`, sem alteração de teor), o que exige julgamento são três posições: a decisão do owner (`-0003`/`-0009`), a retratação do ADP (`-0004`) e a correção de escopo de RLS com cardinalidade 1:1 (`-0005`).

### O que a decisão exige de quem acka

Da leitura dos três corpos, o que atravessa a fronteira do repositório é: identidade única (`tenant_id` é o identificador técnico da conta, `MSA` é rótulo de negócio para o mesmo valor, nenhum `MsaId`/`msa_id`/`msa_ids`/`scope_msa_ids` na camada técnica); cardinalidade 1:1 entre conta e contrato, com o nível `msa` colapsando nos vocabulários de escopo; nenhuma camada de agrupamento acima da conta — e `-0005` pede explicitamente que quem tiver modelado essa camada declare a divergência; e credenciais Pix pertencem ao Tenant no backend, com o dispositivo nunca recebendo segredo.

### Estado real do `Axis.PadSimulator` contra cada exigência

Auditei o código antes de recomendar, em vez de tratar o ack como formalidade.

- **Identidade única**: conforme, sem trabalho. `MSA`/`MSP` aparecem **zero vezes em código** (`.cs`, `.ts`, `.tsx`); todas as ocorrências do repositório vivem dentro do próprio store do canal — `CHANNEL.md`, os `.jsonl` e os blobs de corpo de mensagem. `ConnectionProfile.TenantId` é o único identificador de conta. O uso comprovado em código é como **path** (tópico de telemetria `device/{tenantId}/telemetry/v1`) e como componente da **chave de idempotência** de tap (`IdempotencyKeyDeriver`); o comentário XML da entidade também menciona composição de header multi-tenant, mas isso é aspiracional — o único `X-Tenant-Id` do repositório está num teste E2E que bate direto no gateway do AGC, fora do fluxo de `ConnectionProfile`.
- **Cardinalidade 1:1 e ausência de camada acima da conta**: conforme. Um `ConnectionProfile` aponta direto para um `tenantId`; não há agrupamento, escopo hierárquico nem enum de `scope_type` neste repositório. Nada a declarar como divergência ao pedido do `-0005`.
- **Credenciais Pix no backend**: conforme, e vale registrar no ack porque é o ponto do `-0003`/`-0009` que mais poderia colidir com um simulador de dispositivo. O `PixChargeClient` cria cobrança chamando `POST /api/v1/devices/me/pix/charges` no `device-management`, autenticando por identidade de device (`X-Client-Cert-Thumbprint` em `dev-seam` ou certificado cliente no handshake mTLS) — o simulador nunca vê credencial de PSP. Os segredos que ele guarda são de device (chave privada mTLS, JWT de operador), cifrados via `ISecretProtector`, que é exatamente o que se espera dele.

O refactor correspondente do lado do ADP já foi executado e é verificável: `ac9801c` no `axis-device-platform` ("unificar a identidade da MSA no tenant_id canônico"), com 34 testes verdes na categoria `Regression_MSA-TENANT-IDENTITY` e um gate em xUnit varrendo os fontes de produção para impedir reincidência.

### Recomendação, e o que o usuário decidiu

A recomendação foi **ackar as 6 como adoção (`acknowledged`), sem `wont-adopt` e sem dívida no ledger** — o `Axis.PadSimulator` já satisfaz as três decisões por construção, e o custo do ack aqui é registro, não trabalho. `wont-adopt` seria factualmente errado: não há recusa, há conformidade prévia.

O usuário aprovou essa recomendação na mesma sessão, e os seis acks foram emitidos (`axis-pad-simulator-0002` a `-0007`), cada um com `--subject` dizendo por que aquela decisão específica não gera trabalho aqui. `check-liaison-acks.sh` passou a retornar `OK` e o canal foi propagado por `sync` nos três peers — 6 novas no `axis-go-cloud`, 9 no `axis-fare-validator` (as 6 mais três que ainda faltavam lá), 6 no `axis-device-platform`.

O commit ficou no PR [Axis.PadSimulator#26](https://github.com/Axis-Mobfintech/Axis.PadSimulator/pull/26), montado em worktree isolado a partir de `github/develop`: a `develop` local daquele repositório carrega quatro commits de harness anteriores nunca publicados, cujo conteúdo já entrou por squash no `#25`, e empilhar em cima deles inflaria o diff em 65 mil linhas alheias. Os outros três repositórios ficaram com o store do canal sincronizado mas **não commitado** — em particular o `axis-fare-validator`, que está na branch do PR #148 e não pode ser contaminado.

## 0.3 — `axis-fare-validator#14` reconciliada e fechada

Fechada como concluída, com [comentário de reconciliação](https://github.com/MiltonSilvaJr/axis-fare-validator/issues/14#issuecomment-5167486346) mapeando cada um dos seis itens do escopo à evidência em `origin/develop`. Cinco entregues, o sexto com issue própria (`#16`).

A nomenclatura da issue ficou obsoleta porque o ADR-0007 (agnosticismo de fornecedor) renomeou as implementações: `PlanetaReaderDevice` virou `Scr916ReaderDevice`, `IdtechReaderDevice` virou `KioskIvReaderDevice`. O que mais chama atenção é que a issue previa esqueleto e o repositório tem implementação: `Scr916ReaderDevice.SUPPORTS_TRANSACTION` está `true` em `develop`, e `ValidatorViewModel.java:223` já declara `private ReaderDevice readerDevice` — as duas condições do guard `MergeOrderInvariantTest` estão positivas, ou seja, a Fase 2.1b e a Fase 3 de código foram ambas mergeadas. Os insumos que a issue listava como externos (`vlib_extra`, `map`) chegaram e estão em `res/raw/`; o jar é `aipatcpclient-1.4.5.jar`, não o `1.2.5` previsto.

Sobram três coisas, nenhuma delas desta issue: validação em hardware T10 (`#15`), catálogo PII dependente da confirmação de schema com a Planeta (`#16`), e o acordo de SLA sobre patches do daemon `br.inf.planeta.aipa` — que não é código, não tem issue e pertence ao ledger, não a uma issue de feature.

**Achado colateral registrado no comentário**: o `pii-catalog.yaml` tem 16 referências ao caminho antigo `br/com/setis/axisdemoapp/...` contra 6 já corrigidas para `br/com/axis/farevalidator/...`. É drift de referência, não de classificação, e o lugar de corrigir é o PR que fechar a `#16`.

## 0.4 — Textos de cobrança

Três textos, prontos para envio pelo usuário. Não foram enviados nem publicados em lugar nenhum.

### A — Planeta, sobre o schema do `TransactionResponse` (`#16`)

> **Assunto: SCR916 — confirmação do schema do `TransactionResponse` para fechamento do catálogo de dados pessoais**
>
> Prezados,
>
> A integração do SCR916 no nosso validador está com o código concluído: a leitora é acionada pelo daemon AIPA, a implementação está mergeada e o mapeamento de `TransactionResponse` para a estrutura interna do app já cobre catorze campos. O que ainda não conseguimos fechar é a classificação de dados pessoais desses campos, e é sobre isso que precisamos da confirmação de vocês.
>
> Precisamos da confirmação formal de três pontos do schema do `TransactionResponse` JSON: qual campo corresponde ao hash do PAN e com que algoritmo e comprimento ele é gerado (observamos 16 ou 32 bytes em hex, e precisamos saber o que determina cada caso); se e como o PAR EMV (tag `0x9F24`) é exposto; e a lista completa dos campos que a resposta pode carregar, com a condição exata de presença de cada um. Nossa leitura hoje distingue dois tipos de condição, e precisamos que vocês confirmem ou corrijam: `pan_index` e `card_bin` aparecem apenas quando habilitados na configuração do projeto, enquanto `last4` parece depender do tipo de transação (EMV) e `uid` do tipo de fluxo (closed loop). Precisamos saber se essa leitura está certa, o que ativa cada campo, e se há outros campos que não mapeamos.
>
> A razão do pedido é regulatória, não técnica: cada campo que carregue dado pessoal precisa entrar no nosso catálogo LGPD com classificação, base legal, retenção e regra de mascaramento antes de qualquer operação em produção, e a definição de escopo PCI do caminho SCR916 depende dessa mesma lista. Sem a confirmação de vocês, a alternativa é classificar por observação em bancada, o que é menos confiável e nos obrigaria a assumir a hipótese mais conservadora em cada campo ambíguo.
>
> Encadeamos este pedido com a janela de bancada do T10 que estamos agendando: os valores efetivamente observados em hardware vão validar a confirmação de vocês, e a ordem natural é recebermos o schema antes da bancada, para que a sessão sirva de verificação e não de descoberta.
>
> Aproveitamos para retomar um ponto ainda em aberto do nosso acordo: o SLA de patches do daemon `br.inf.planeta.aipa`. Como o daemon integra o ambiente de dados de cartão da solução, precisamos do compromisso formal de prazo de correção por severidade para conseguir sustentar nossa posição de conformidade.
>
> Ficamos no aguardo e à disposição para uma call técnica se for mais rápido que a troca por escrito.

### B — Agendamento da bancada T10 (`#15`)

> **Assunto: Janela de bancada T10 + SCR916 — agendamento**
>
> Precisamos agendar uma janela de bancada com hardware T10 e leitora SCR916 real. Não há decisão técnica pendente do nosso lado: o código está mergeado em `develop`, o `Scr916ReaderDevice` implementa a transação de fato e o mapeamento de resposta está escrito. O que falta é exclusivamente execução em hardware, e é a única coisa que destrava a sequência.
>
> O que a sessão precisa produzir, em ordem: fluxo completo ponta a ponta (registro do validador, download de parâmetros, leitura de cartão contactless, envio ao Axis Go Cloud); os valores reais de `code_status` do daemon, que é o que nos permite distinguir recusa de erro técnico em vez de tratar tudo como erro; os campos que o `TransactionResponse` efetivamente traz em campo, insumo direto do catálogo de dados pessoais; e a suíte de regressão no TPS530 com IDTech, para provar que o caminho antigo não regrediu.
>
> O que precisamos disponível: um validador T10 com a SCR916 e o daemon AIPA já instalado, cartões contactless de teste Visa Débito e Mastercard PayPass com BIN aceito no ambiente de homologação, e acesso ao backend de homologação durante a janela.
>
> Estimamos uma janela de meio período para a primeira sessão. Bloqueia três frentes de uma vez: a validação da Fase 3, o fechamento do catálogo de dados pessoais e o encerramento do ADR-0003, que segue em `proposed` justamente porque depende dessa validação. Podem indicar as datas possíveis nas próximas duas semanas?

### C — PM + Compliance/Security + Backend, decisão de política do ARQC (`#33`)

> **Assunto: Decisão pendente há três meses — o que o validador faz quando o cartão pede autorização online (ARQC)**
>
> Precisamos de uma decisão de política que está aberta desde 10/05 e que não é técnica: qual deve ser o comportamento do validador quando o cartão responde ARQC, isto é, quando o próprio EMV determina que a autorização cabe ao emissor e não pode ser resolvida offline.
>
> Hoje o app trata apenas os dois extremos: TC aprova a passagem, AAC bloqueia. Para ARQC a máquina de estados tem um estado sem saída. Isso não é caso de borda — cartões de perfil de risco mais alto, cartões internacionais, corporativos pré-pagos e cartões com contador offline excedido pedem ARQC com frequência em campo. Enquanto a decisão não vier, qualquer implementação escolheria arbitrariamente entre travar a fila do ônibus, perder receita recusando cartão legítimo, ou aprovar localmente uma autorização que o EMV explicitamente delegou ao emissor — este último com risco de fraude e de escopo PCI.
>
> As quatro opções e seus trade-offs estão na issue #33 e no ADR-0011. Nossa inclinação preliminar, já documentada, é a Opção 1, negação conservadora com mensagem própria ao passageiro: risco PCI zero, implementável sem depender da squad Backend, e reversível quando tivermos volume real medido.
>
> **Do PM** precisamos de duas coisas: a posição sobre o trade-off receita versus risco aceitável para a operadora, e a aprovação do texto exato da mensagem ao passageiro — o texto vai à tela do validador e não pode ser escrito ad-hoc pela engenharia.
>
> **De Compliance/Security** precisamos saber se as regras transit dos esquemas Visa e Mastercard existem hoje para o caso de uso da operadora ou são roadmap, porque a Opção 2 só é viável com elas; e, se a Opção 1 for confirmada, qual o gatilho formal de reabertura.
>
> **Da squad Backend** precisamos de uma resposta binária: a rota de autorização online ao emissor está fora do roadmap? Se estiver, precisamos disso registrado, porque é o que elimina a Opção 3 formalmente em vez de deixá-la em suspenso.
>
> Uma nota de sequenciamento que vale para qualquer das quatro opções: vamos instrumentar a telemetria de volume de ARQC agora, sem esperar a decisão. A própria cláusula de reversão do ADR-0011 exige noventa dias de dados de campo, e se o contador só começar a rodar depois da decisão, os noventa dias começam depois — a decisão ficaria travada por um dado que ninguém está coletando. A telemetria não decide nada e não antecipa opção nenhuma; só garante que a revisão futura tenha base.

## Estado ao fim do Bloco 0

Executado: o `sync` do canal nos quatro repositórios, os seis acks no `Axis.PadSimulator` (aprovados pelo usuário) com PR aberto, e o fechamento da `#14` com comentário de reconciliação. Nenhum PR foi mergeado. Fica pendente do usuário: o billing do GitHub (0.1), o merge dos dois PRs abertos e o envio dos três textos de cobrança (0.4).
