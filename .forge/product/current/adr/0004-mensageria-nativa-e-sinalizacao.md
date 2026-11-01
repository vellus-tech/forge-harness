# 0004. Mensageria nativa entre sessões é sinalização; o registro durável é o liaison

- **Status:** accepted — gate `design_reviewed` aprovado para `add-liaison-native-bridge` (3 rodadas de revisão adversarial; manifest.yaml do change).
- **Data:** 2026-10-31
- **Decisores:** milton (dono do projeto, decisões da revisão delegada de 2026-10-30 registradas em `requirements.md`)

## Contexto e Problema

Em 2026-10-30, a sessão "ORQUESTRADOR" da squad Payments (repositório `payments`, modo `bypass`) abordou por mensageria nativa (`SendMessage`) uma sessão do forge-harness. As duas sessões descobriram, em paralelo e sem saber uma da outra, que tinham feito a mesma avaliação de um projeto externo (`akitaonrails/ai-memory`) — trabalho duplicado que uma terceira sessão repetiria de novo, porque nada da descoberta ficou registrado fora dos dois transcripts efêmeros. A mesma troca expôs um vetor de vazamento entre empresas: o recurso nativo alcança qualquer sessão do mesmo usuário do sistema, e o `from-name` que identifica a origem é autodeclarado, sem prova de repositório nem de empresa. Era preciso decidir o que uma sessão de agente pode considerar **registro** — o que sobrevive, tem ordem garantida e pode ser citado num ADR — e o que é só **aviso**, descartável ao fim da sessão.

## Drivers da Decisão

- O liaison já existe como store append-only, ordenado, durável e versionado por repositório; duplicar essa propriedade dentro do mecanismo nativo custaria uma segunda fonte de verdade.
- O nativo não tem transporte configurável, não sobrevive à sessão e não distingue remetente confiável de remetente autodeclarado — propriedades que o liaison já resolve.
- NFR-02 (zero dependência nova) e a proibição de script/gancho invocar sessão de agente (`w113` [10]) eliminam qualquer solução que peça ao nativo se comportar como barramento.
- A decisão precisa ser transversal: vale para este change e para qualquer canal futuro entre agentes (ex.: o bastão de handoff do próximo change), não só para o incidente que a motivou.
- Contenção por workspace é tratável apenas como mitigação de **liberação induzida** (o fluxo normal de trabalho enviando para o lugar errado), nunca como fronteira de segurança contra um agente determinado rodando como o mesmo usuário do sistema — distinção que a decisão precisa declarar explicitamente para não ser lida como garantia que não entrega.

## Opções Consideradas

1. **Nativo como registro.** Tratar o conteúdo que chega por `SendMessage` como fonte de verdade equivalente ao liaison. Rejeitada: o nativo não é durável (desaparece com a sessão), não tem ordem garantida entre repositórios, e aceitar seu conteúdo como registro normativo sem o teto, a moldura e a neutralização do liaison contradiz a regra de dado não confiável (`liaison-untrusted-input.md`).
2. **Espelhamento total.** Toda mensagem nativa recebida gera automaticamente uma entrada no liaison. Rejeitada: não existe evento de hook para mensagem RECEBIDA (só para o envio, `PreToolUse` de `SendMessage`); forçar isso transformaria o canal em chat de baixo valor, inflando o liaison com tráfego que não é fato de contrato — fora do escopo que torna o canal útil.
3. **Campainha com ponteiro** (escolhida). O nativo avisa; o liaison registra. `send` grava o fato; `sync` publica; `notify` resolve o ponteiro (`liaison:<canal>/<msg_id>`); e só então o `SendMessage` leva, como primeira linha do corpo, esse ponteiro — nunca o conteúdo substantivo. Do lado de quem recebe, o registro do que chegou é explícito: `send --via cross-session --native-ref <fingerprint>` para o que vira mensagem própria, ou `native dispose <fingerprint> --ephemeral <classe>` para o que é genuinamente descartável, dentro de uma lista FECHADA de classes efêmeras.

## Decisão

Opção 3 — a mensageria nativa entre sessões do Claude Code é **sinalização** (campainha): ela avisa que algo aconteceu agora, na sessão do destinatário, mas não é tratada como fato de contrato nem citável. O **registro durável** de qualquer troca que afete outro repositório, mude contrato ou ack, retrate algo, revele achado de segurança, feche pergunta bloqueante, ou descubra trabalho sobreposto é sempre o liaison — e só o liaison.

## Consequências

- Positivas: o corpo canônico de qualquer fato que atravessa repositórios mora sempre no liaison, nunca dividido entre dois sistemas; o ponteiro `liaison:<canal>/<msg_id>` torna toda campainha auditável e rastreável a uma mensagem publicada; a lista fechada de classes efêmeras (`EPHEMERAL_CLASSES`) impede que "é só aviso" vire escotilha informal — alterar a lista é mudança de design, com gate de paridade contra a rule; a contenção por workspace (`allowed_workspaces`), com cadastro humano e detecção determinística nos três pontos (pre-push, doctor, PR), torna visível qualquer tentativa de liberação induzida, mesmo sabendo que não é fronteira contra um agente determinado.
- Negativas/débitos: a única contenção real contra um agente determinado rodando como o mesmo usuário do sistema é a configuração gerenciada do Claude Code, fora do alcance deste harness — documentada como recomendação para repositórios PCI, não implementada (ledger LDG-0203); o formato de agente nomeado (`Agent` com `input.name`, agent teams) não foi medido em produção, só em fixture sintética (ledger LDG-0204); mensagem nativa recebida entra crua no contexto, sem nenhuma guarda mecânica de moldura, teto ou neutralização — a disciplina de não executar, não configurar e não incorporar fica inteiramente a cargo do julgamento de quem lê (`liaison-untrusted-input.md`, seção "Mensagem nativa recebida").

## Links

- Change de origem: `add-liaison-native-bridge` (design §10, §2.8; requirements REQ-09; `requirements.md` revisão delegada de 2026-10-30).
- Rules: `template/.forge/rules/conventions/liaison-protocol.md` (seção "Mensageria nativa entre sessões"), `template/.forge/rules/conventions/liaison-untrusted-input.md` (seção "Mensagem nativa recebida").
- Ledger: LDG-0203 (configuração gerenciada PCI), LDG-0204 (medição de agente nomeado), LDG-0205 (auditoria de stdin sem limite de tempo), LDG-0206 (este ADR).
