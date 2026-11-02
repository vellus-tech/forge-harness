# Requirements — add-liaison-handoff-baton

> Requisitos do change `add-liaison-handoff-baton`. Cada requisito é verificável e rastreável à proposal. Identificadores, subcomandos, flags, chaves e valores em inglês, conforme a convenção de nomenclatura do harness. A implementação depende de `add-liaison-native-bridge` mesclado em `develop` (proposal §4). Iteração 2 do validador (2026-10-30): trava estendida ao `sync`, renovação manual com requisito próprio, desempate por code point, lista de elegíveis gravada na oferta, janela de folga e vereditos completados, carimbo de relógio declarado como exceção nova. Iteração 3: validação em duas camadas (envelope tolerante a operação futura, regras do bastão na dobra), aviso de relógio fora do `CHANNEL.md`, conjunto fechado de estados, operação em thread errada ou anterior à oferta, prazo da renovação, critério de gravação da reivindicação, continuidade de sessão, referência fixa do gate de compatibilidade.

Termos usados abaixo.

- **Bastão**: uma unidade de trabalho com no máximo um dono por vez, identificada pelo `msg_id` da mensagem de oferta que a criou (`baton_id`).
- **Operação de bastão**: uma das seis operações `offer | claim | renew | release | complete | withdraw`, sempre expressa como mensagem do liaison gravada no log de quem age.
- **Sessão titular**: o par `(sender, session)`, em que `sender` é o repositório (o `self.id` do liaison) e `session` é o identificador da sessão de agente que age (REQ-10). Duas sessões do mesmo repositório são titulares diferentes.
- **Titular corrente**: a sessão titular que a dobra aponta como dona do bastão, com o lease vencido ou não; ela deixa de ser titular só por `release`, `complete` ou por uma reivindicação válida de outra sessão.
- **Carimbo**: o instante de relógio de parede, em ISO 8601 UTC com segundos e sufixo `Z`, gravado na mensagem por quem a escreve (`stamped_at`). É dado da mensagem, não critério de ordem.
- **Elegíveis**: a lista de repositórios que podem reivindicar o bastão, gravada na oferta (REQ-02).
- **Ordem da thread**: `(lamport, sender, seq)`, com `sender` comparado por code point (REQ-04).
- **Dobra**: a função pura que percorre as mensagens de bastão de uma thread na ordem da thread e devolve o estado de cada bastão e o veredito de cada operação (REQ-04).
- **Réplica**: o conjunto de logs do canal visível num clone (o próprio log mais os logs de peers já importados).
- **Estados do bastão**: conjunto fechado `available` (oferecido ou liberado, sem titular), `held` (com titular corrente), `completed` e `withdrawn` (terminais).

## REQ-01 — Forma da mensagem de bastão

- **Quando** qualquer operação de bastão é gravada, **o sistema deve** gravá-la como mensagem `kind: note`, com `requires_ack: false`, `subject` igual ao `--subject` na oferta e, nas demais operações, `baton <op>: <assunto da oferta>` truncado a 200 caracteres, `in_reply_to` igual ao `baton_id` (exceto na oferta, em que é `null`) e um objeto `baton` com os subcampos `op`, `session`, `stamped_at` e os específicos de cada operação: `eligible`, `max_lease_seconds` e `skew_tolerance_seconds` na oferta; `lease_seconds` e `lease_until` em `claim` e `renew`.
- **Critérios de aceite:**
  - [ ] Validação em duas camadas. Camada de envelope (schema `liaison-message.schema.json` e `validateEnvelope`, aplicada no import e antes de toda gravação): `baton` é objeto, só em `kind: note`, com `requires_ack: false`, e `op` é string no padrão `^[a-z][a-z-]{0,31}$`; nada além disso, para que uma operação acrescentada por versão futura do harness entre na réplica sem virar conflito nem buraco de `seq`. Uma bateria com envelopes válidos e inválidos por regra desta camada dá o mesmo veredito no schema e no `validateEnvelope`.
  - [ ] Camada de bastão (`validateBaton`, uma única função): `op` na lista das seis, subcampos obrigatórios e proibidos por `op`, padrões, limites absolutos (`lease_seconds` e `max_lease_seconds` em `[60, 86400]`, `skew_tolerance_seconds` em `[0, 3600]`, `eligible` com 1 a 64 ids no padrão de `sender`, sem repetição), `lease_until` igual a `stamped_at + lease_seconds`, `in_reply_to` obrigatório fora da oferta e `null` na oferta. O CLI a aplica antes de gravar (nunca grava bastão inválido); a dobra a aplica a toda mensagem com `baton` e dá `malformed` a quem falha (REQ-04). Bateria própria com um caso por regra; o schema documenta os subcampos com tipos e a descrição destas regras, sem `additionalProperties: false` nem enum de `op`, e diz que a validação completa é a do `validateBaton`.
  - [ ] O objeto `baton` entra no `content_sha` (não é excluído como `trust`), conferido por teste que altera um subcampo e vê o `content_sha` recalculado divergir.
  - [ ] Compatibilidade nos dois sentidos: (a) o `validateEnvelope` e o import da última tag publicada cujo schema não contém `baton` (resolvida pelo gate percorrendo as tags em ordem decrescente de versão, nunca "a mais recente", que depois deste change passaria a conter o bastão) aceitam uma mensagem de cada operação sem conflito nem quarentena; (b) o import deste harness aceita uma mensagem com `op` desconhecido (`op: transfer`) sem conflito, e a dobra lhe dá `malformed`.
  - [ ] Os seis valores de `op`, os quatro estados e os vereditos do REQ-04 vêm de uma única fonte no código, usada pelo `validateBaton`, pela dobra e pela mensagem de flags do CLI, conferida por teste.
- **Rastreia:** proposal §2.1
- **Notas:** a escolha de campo sobre `kind: note`, e não de `kind` novo, é deliberada: o `validateEnvelope` atual recusa `kind` desconhecido e o import transforma a mensagem em conflito, o que deixaria um participante desatualizado com buraco de `seq` e posições retidas; o mesmo validador ignora campo desconhecido. A camada de envelope é deliberadamente tolerante pelo mesmo motivo, agora para o futuro: se ela recusasse `op` desconhecido, a próxima versão do harness que acrescentasse uma operação abriria buraco de `seq` nesta, e pelo REQ-05 o buraco deixaria a posse `provisional` para sempre.

## REQ-02 — Oferta (`baton offer`)

- **Quando** o operador roda `liaison-ops.sh baton offer <channel> --thread <id> --subject "<txt>" [--body "<txt>" | --body-file <path> | --from-handoff] [--for <a,b>] [--max-lease <s>] [--session <id>]`, **o sistema deve** gravar uma oferta no log próprio, com `eligible` igual a `--for` ou, sem a flag, a todos os participantes da thread conhecidos na réplica no momento da oferta (inclusive o próprio repositório), e imprimir o `baton_id`, sem que nenhuma sessão, inclusive a ofertante, passe a deter o bastão.
- **Critérios de aceite:**
  - [ ] Depois da oferta, `baton status` mostra o bastão como `available` e sem titular; não existe reivindicação implícita.
  - [ ] Thread cujos participantes não incluem nenhum repositório além do próprio → rc 1, nada gravado, explicando que coordenação só dentro do repositório não é material de liaison (`liaison-protocol`).
  - [ ] `--for` com algum id que não é participante da thread → rc 1, nada gravado, nomeando o id; `eligible` resultante sem nenhum repositório além do próprio (por exemplo `--for` só com o próprio id) → rc 1, nada gravado, pelo mesmo motivo do critério anterior.
  - [ ] `max_lease_seconds` gravado vem de `--max-lease` ou de `liaison.baton.max_lease_seconds`; `skew_tolerance_seconds` vem de `liaison.baton.skew_tolerance_seconds`; `--max-lease` fora de `[60, liaison.baton.max_lease_seconds]` → rc 1, nada gravado.
  - [ ] Corpo passa pela mesma varredura de segredo, tetos e blob do `send`, sem caminho de escrita paralelo.
  - [ ] Flag desconhecida, `--thread` ou `--subject` ausente, ou thread desconhecida localmente → rc 1 nomeando o subcomando e as flags aceitas.
  - [ ] A saída de sucesso imprime o `baton_id`, o comando `sync` que publica a oferta e, quando o canal tem transporte, o comando `notify` do REQ-15.
- **Rastreia:** proposal §2.1, §2.7
- **Notas:** a lista de elegíveis é gravada, e não recalculada a cada leitura, para que o conjunto de quem pode afetar a posse seja finito e igual em todas as réplicas (base do REQ-05). Quem entra na thread depois da oferta reivindica ofertas novas, não esta.

## REQ-03 — Reivindicação com compare-and-set local (`baton claim`)

- **Quando** o operador roda `liaison-ops.sh baton claim <channel> <baton_id> [--lease <s>] [--session <id>]`, **o sistema deve**, sob a trava exclusiva do log próprio (REQ-09), recusar sem gravar (rc 1) os casos de pré-condição — oferta desconhecida na réplica, `--lease` fora dos limites, sessão já titular com lease não vencido (rc 0 neste caso, dizendo que ela já detém o bastão e que a renovação é `baton renew`) — e, nos demais casos, gravar a reivindicação, calcular a dobra com ela incluída e responder com o veredito dela: rc 0 se `won` (com a marca `provisional` ou `stable` do REQ-05), rc 3 em qualquer outro veredito, nomeando o veredito e, quando houver, a titular corrente.
- **Critérios de aceite:**
  - [ ] Critério de gravação: a reivindicação só é recusada sem gravar quando o pedido em si é defeituoso ou inócuo (referência a oferta que a réplica não conhece, parâmetro fora de faixa, sessão que já é a titular vigente); todo resultado que depende do estado do bastão é gravado, inclusive `lost-held`, `not-eligible` e `closed`, porque é a disputa pelo bastão que se audita. O histórico do REQ-08 mostra cada uma com o veredito.
  - [ ] Fixture de concorrência no mesmo clone: 10 processos `claim` disparados juntos para o mesmo bastão, de 10 sessões diferentes → exatamente um rc 0, nove rc 3 nomeando o mesmo vencedor, dez mensagens `claim` no log com `seq` contíguo, e `baton status` concorda com o rc 0.
  - [ ] Cada caso de pré-condição tem fixture própria: oferta desconhecida → rc 1 sem gravar; `--lease` fora de `[60, max_lease_seconds da oferta]` → rc 1 sem gravar; sessão titular com lease válido → rc 0 sem gravar.
  - [ ] Sem `--lease`, usa `liaison.baton.default_lease_seconds`, reduzido ao `max_lease_seconds` da oferta quando o exceder, informando a redução na saída.
  - [ ] Reivindicação de bastão detido por outra sessão com lease vigente (inclusive dentro da folga do REQ-06) é gravada e recebe `lost-held` (rc 3); o bastão não troca de dono.
  - [ ] Tomada por vencimento contra titular de outro repositório: antes de gravar, se o canal tem transporte e o último `sync` com pull é anterior ao `lease_until` da titular, a saída avisa que uma renovação dela pode estar publicada e ainda não importada, e recomenda `sync` antes; o aviso não bloqueia.
- **Rastreia:** proposal §2.3, §2.6

## REQ-04 — Resolução determinística (dobra)

- **Quando** o estado de um bastão é consultado por qualquer comando, **o sistema deve** obtê-lo de uma única função pura que recebe as mensagens do canal, dobra cada thread em separado e aplica as operações de bastão na ordem da thread, usando só dados gravados nas mensagens (carimbos, prazos, folga e elegíveis da oferta), nunca o relógio nem a configuração local de quem lê.
- **Critérios de aceite:**
  - [ ] A comparação de `sender` na ordem da thread passa a ser por code point (ordem dos bytes UTF-8 dos ids, que são ASCII), e não por `localeCompare`, que depende de ICU e locale. A mudança vale para `threadOrder` e para a escolha do `thread-open` em `mergeLogs` (a ordem do liaison inteiro, não só a da dobra); teste com os ids `a_b`, `a-b`, `a-c`, `a.b`, `a0` e `ab` com o mesmo `lamport` fixa a ordem `a-b`, `a-c`, `a.b`, `a0`, `a_b`, `ab` sob `LANG` e `LC_ALL` diferentes.
  - [ ] Teste de propriedade: para 200 permutações aleatórias da mesma entrada, a dobra devolve estado e vereditos idênticos.
  - [ ] A dobra implementa esta tabela fechada, com um caso de teste por linha (aplicada na ordem; a primeira linha que casa decide; "carimbo" é o `stamped_at` da operação; `T` é o `lease_until` vigente e `S` a folga da oferta):
    - posição forkada (mesmo `sender` e `seq` com `content_sha` diferente na entrada) → `forked`, sem efeito, para todas as versões da posição;
    - forma inválida pelo `validateBaton` (inclusive `op` desconhecido) → `malformed`, sem efeito;
    - `offer` → `offered`, bastão `available`;
    - oferta referida ausente da réplica → `pending-offer`, sem efeito, reavaliada quando a oferta chegar (nunca vira perda definitiva);
    - oferta referida existe na réplica mas em outra thread do canal → `wrong-thread`, sem efeito;
    - `in_reply_to` aponta para mensagem presente na réplica que não é oferta aplicável (nota sem `baton`, outra operação de bastão, oferta `malformed` ou `forked`) → `not-an-offer`, sem efeito e definitivo; o CLI trata esses casos como oferta desconhecida (rc 1, nada gravado);
    - oferta referida existe na mesma thread mas vem depois da operação na ordem da thread (só possível com carimbo de ordem forjado, porque quem age já viu a oferta) → `before-offer`, sem efeito;
    - bastão `completed` ou `withdrawn` → `closed`, sem efeito;
    - `claim`/`renew` com `lease_seconds` acima do `max_lease_seconds` da oferta → `lease-over-max`, sem efeito;
    - `claim` de `sender` fora de `eligible` → `not-eligible`, sem efeito;
    - `claim` com bastão `available` → `won`, titular é `(sender, session)` com `lease_until` da claim;
    - `claim` da titular corrente com carimbo ≤ `T` → `duplicate-claim`, sem efeito;
    - `claim` da titular corrente com carimbo > `T` → `won` (retomada com lease novo);
    - `claim` de outra sessão com carimbo ≥ `T + S` → `won` (tomada após vencimento; a titular anterior aparece no histórico como `expired`);
    - `claim` de outra sessão com carimbo < `T + S` → `lost-held`, nomeando a titular;
    - `renew` da titular corrente com carimbo ≤ `T` → `renewed`, `T` passa a ser o `lease_until` da renovação;
    - `renew` da titular corrente com carimbo > `T` → `late-renew`, sem efeito;
    - `renew`, `release` ou `complete` de quem não é a titular corrente, ou com bastão sem titular → `not-holder`, sem efeito;
    - `release` da titular corrente → `released`, bastão `available`, sem titular;
    - `complete` da titular corrente → `completed`, terminal;
    - `withdraw` de `sender` que não é o ofertante → `not-offerer`, sem efeito;
    - `withdraw` do ofertante com bastão `available`, ou `held` com carimbo ≥ `T + S` → `withdrawn`, terminal;
    - `withdraw` do ofertante com bastão `held` e carimbo < `T + S` → `withdraw-while-held`, sem efeito.
  - [ ] Duas reivindicações concorrentes sobre bastão `available`: vence a primeira na ordem da thread (menor `lamport`; empate pelo menor `sender` em code point; empate pelo menor `seq`), e a outra recebe `lost-held` nomeando a vencedora.
  - [ ] Duas réplicas de fixture que importaram o mesmo conjunto de mensagens em ordens diferentes calculam o mesmo estado.
- **Rastreia:** proposal §2.2
- **Notas:** a correção do desempate por code point é um defeito do liaison existente que este change precisa corrigir: o schema já declara a ordem `(lamport, sender, seq)`, e a ordem efetiva hoje pode variar entre réplicas com ICU ou locale diferente (medido pelo validador do change em 2026-10-30). Como os ids só usam `[a-z0-9._-]`, a ordem só muda entre ids que diferem por pontuação com o mesmo `lamport`. Várias cópias do mesmo `self.id` escrevendo em clones diferentes continuam fora do suportado (rule `liaison-protocol`, item 6); a linha `forked` só garante que a dobra não dependa da ordem de entrada quando isso acontece.

## REQ-05 — Provisório e estável entre réplicas

- **Quando** a dobra declara uma sessão titular como dona, **o sistema deve** marcar a posse como `stable` se, para todo repositório do conjunto exigido (os `eligible` da oferta mais o ofertante, menos o `sender` da reivindicação que deu a posse à titular corrente), a réplica contém o log desse repositório com `seq` contíguo desde 1 até alguma mensagem dele na thread com `lamport` maior ou igual ao da reivindicação, e como `provisional` caso contrário, nomeando os repositórios ainda não observados.
- **Critérios de aceite:**
  - [ ] Fixture com três repositórios elegíveis: reivindicação vencedora antes de importar os outros dois → `provisional` nomeando os dois; depois de importar uma mensagem posterior de cada → `stable`.
  - [ ] Log de um repositório exigido com buraco de `seq` antes da mensagem posterior → continua `provisional`, nomeando o buraco.
  - [ ] Oferta com `eligible` igual ao `sender` da reivindicação e ofertante já observado → `stable` sem esperar quem não é elegível.
  - [ ] Perda tardia: uma sessão que recebeu rc 0 `provisional` e, depois de um `sync`, perde para uma reivindicação concorrente que a precede na ordem → `baton status` e o início de sessão (REQ-13) mostram a perda nomeando o vencedor; fixture com duas réplicas.
  - [ ] A documentação do `/forge:liaison` e a rule dizem que `provisional` é posse sujeita a reversão, que ela não impede trabalhar, que a recomendação é `sync` antes e depois de reivindicar, e que a posse só vira `stable` quando cada repositório exigido escreve alguma mensagem na thread depois da reivindicação: com participantes calados, ela fica `provisional` indefinidamente, por desenho (nenhuma mensagem automática é emitida para estabilizá-la).
- **Rastreia:** proposal §2.2, §3 (limite entre réplicas)

## REQ-06 — Lease: prazo, limites, folga e expiração

- **Quando** uma reivindicação ou renovação é gravada, **o sistema deve** carimbar `stamped_at` com o relógio de quem grava e `lease_until = stamped_at + lease_seconds`; **quando** o lease vence sem renovação, a titular corrente perde o direito de renovar, mas continua titular até liberar, concluir ou ser substituída, e outras sessões elegíveis só podem tomar o bastão com reivindicação carimbada a partir de `lease_until + skew_tolerance_seconds` da oferta.
- **Critérios de aceite:**
  - [ ] `forge.yaml` do template declara `liaison.baton.default_lease_seconds` (1800), `liaison.baton.max_lease_seconds` (14400), `liaison.baton.skew_tolerance_seconds` (120) e `liaison.baton.auto_renew` (true), com comentário explicando cada um; chave ausente usa o default; valor fora de faixa (`default` < 60, `max` > 86400, `default` > `max`, folga negativa ou > 3600) → rc 1 nos verbos que leem a configuração (`offer` e `claim`), nomeando a chave; `renew` (que repete o prazo vigente ou usa `--lease` limitado pela oferta), `release`, `complete`, `withdraw`, `status`, `list`, `liaison-ops.sh status`, `render`, o início de sessão e a dobra não leem a configuração e não são afetados; o gancho de renovação reporta a chave inválida em stderr e não renova.
  - [ ] O prazo máximo, a folga e os elegíveis que decidem a posse são os gravados na oferta; mudar a configuração local depois da oferta não muda o estado calculado (teste).
  - [ ] Titular depois do vencimento: `baton renew` → rc 1, nada gravado, dizendo que o lease venceu em `lease_until` e que a retomada é `baton claim`; `baton claim` dela é retomada (REQ-04); `release` e `complete` dela continuam válidos.
  - [ ] Janela de folga (`lease_until` < agora < `lease_until + folga`): reivindicação de outra sessão recebe `lost-held` com o motivo "folga de relógio até <instante>".
  - [ ] `status` e `baton status` mostram `expired` como rótulo informativo quando o relógio de quem lê passou de `lease_until`, sem alterar o estado da dobra.
  - [ ] Carimbo de operação de bastão mais de `skew_tolerance_seconds` à frente do relógio de quem lê → aviso não bloqueante `carimbo de bastão no futuro` no `liaison-ops.sh status` e no `baton status`, nunca no `CHANNEL.md`, que continua determinístico a partir da união das mensagens, sem relógio de quem lê (o mesmo vale para o rótulo `expired`); `render` e `status` mostram `stamped_at` para mensagens de bastão, e o diagnóstico de `created_at` incoerente deixa de considerar mensagens com `baton` (como toda operação de bastão responde à oferta, um repositório com HEAD mais antigo que o do ofertante geraria o aviso de forma sistemática, e a causalidade do bastão já é dada pelo `lamport`); para as demais mensagens ele não muda.
- **Rastreia:** proposal §2.4
- **Notas:** `stamped_at` é uma exceção nova ao invariante do liaison de que nada no envelope usa relógio de parede (`created_at` é a data do HEAD; `published_at` vive só no `state.json` local e não decide nada compartilhado). Ela é declarada como tal na rule (REQ-16), com dois limites: o carimbo nunca entra na ordem, e ele é autodeclarado por quem escreve. Um participante com relógio adiantado além da folga, ou mal-intencionado, consegue tomar o bastão antes da hora; a defesa é a renovação na metade do prazo (REQ-12), o aviso de carimbo no futuro e a perda tardia visível à titular (REQ-05, REQ-13). Isso é limite registrado, não tomada forçada como funcionalidade.

## REQ-07 — Renovação, liberação, conclusão e retirada

- **Quando** a titular corrente roda `baton renew`, `baton release` ou `baton complete`, ou uma sessão do repositório ofertante roda `baton withdraw`, **o sistema deve**, sob a trava do REQ-09, gravar a operação se ela for válida pela dobra local no momento da gravação (com o carimbo que vai gravar) e recusar sem gravar (rc 1) caso contrário, nomeando o motivo e a titular corrente quando houver.
- **Critérios de aceite:**
  - [ ] `renew <channel> <baton_id> [--lease <s>] [--session <id>]` da titular com lease vigente → grava, novo `lease_until`; sem `--lease`, mantém o `lease_seconds` do lease vigente (é esse prazo cuja metade dispara a renovação automática do REQ-12); de outra sessão, inclusive do mesmo repositório → rc 1 nomeando a titular; `--lease` fora de `[60, max_lease_seconds da oferta]` → rc 1.
  - [ ] Depois de um `renew` manual, se a thread tem participante de outro repositório e o canal tem transporte, a saída imprime o comando `sync --push-only` que publica a renovação, e diz que sem ele outro repositório pode considerar o lease vencido.
  - [ ] `release` → estado `available` com o histórico registrando quem liberou; o bastão pode ser reivindicado de novo, inclusive pela mesma sessão.
  - [ ] `complete` → estado `completed`, terminal.
  - [ ] `withdraw` com bastão sem titular, ou com titular cujo lease venceu além da folga → estado `withdrawn`, terminal; com lease vigente ou dentro da folga → rc 1, nada gravado, nomeando a titular e o `lease_until`.
  - [ ] `release`/`complete` por sessão que não é a titular corrente → rc 1, nada gravado, nomeando a titular.
  - [ ] Expiração, liberação, conclusão e retirada são distinguíveis no `baton status` (estado e última operação) e no histórico.
  - [ ] `release`, `complete` e `withdraw` aceitam `--body`/`--body-file` (motivo ou resultado) com a mesma varredura de segredo do `send`.
- **Rastreia:** proposal §2.4, §2.5, §2.6
- **Notas:** operações que a dobra local já sabe inválidas não são gravadas: ao contrário da reivindicação, não há disputa a auditar. Elas só aparecem no histórico com veredito de invalidez quando ficaram inválidas por mensagem que chegou depois de outra réplica (REQ-08).

## REQ-08 — Auditoria e consulta (`baton status`, `baton list`)

- **Quando** o operador roda `liaison-ops.sh baton status <channel> [<baton_id>] [--json]` ou `liaison-ops.sh baton list <channel> [--json]`, **o sistema deve** mostrar, por bastão, o estado, a titular corrente, `lease_until`, a marca `provisional`/`stable`, o rótulo `expired` quando aplicável e o histórico completo com, por operação, `msg_id`, `sender`, `session`, `op`, `stamped_at`, veredito e motivo; `list` mostra só bastões não terminais, um por linha.
- **Critérios de aceite:**
  - [ ] Toda mensagem de bastão da thread aparece no histórico do seu bastão (ou numa seção de órfãs, quando a oferta não está na réplica), com qualquer um dos vereditos do REQ-04.
  - [ ] `--json` produz um documento cujo formato é fixado por fixture; a saída textual e a JSON vêm do mesmo resultado da dobra.
  - [ ] `subject`, `session` e qualquer texto vindo de mensagem de peer são impressos com a moldura e a neutralização de `untrusted-render`, e o corpo nunca é impresso por `status`/`list`.
  - [ ] `render` (`CHANNEL.md`) mostra cada mensagem de bastão com `op`, `session`, `stamped_at` e veredito, e o estado de cada bastão sem rótulo dependente de relógio; a mesma união de mensagens produz o mesmo `CHANNEL.md` byte a byte sob relógios diferentes (teste com duas execuções com `TZ` e relógio diferentes); a variação por locale das demais ordenações do `render` é preexistente e fica fora deste change.
  - [ ] `liaison-ops.sh status` acrescenta à linha de cada canal a contagem de bastões disponíveis, detidos por este repositório e perdidos por este repositório.
  - [ ] `inbox` (inclusive `--titles-only`, usado pelo início de sessão) não lista mensagens `renew` de peer uma a uma: elas avançam o cursor como as demais, mas a listagem as condensa numa linha por bastão (`N renovação(ões) de <bastão>`), para que o início de sessão não duplique o bloco do REQ-13; fixture com 30 renovações.
- **Rastreia:** proposal §2.6

## REQ-09 — Trava do log próprio para todo escritor

- **Quando** qualquer caminho grava em `log/<self>.jsonl` — `send`, `ack`, `thread open`, `thread join`, `conflicts resolve`, os subcomandos `baton`, o `send --via cross-session` trazido por `add-liaison-native-bridge` e a cópia de volta da união para o log próprio feita pelo push do `sync` (inclusive `--repair-own-log`) — **o sistema deve** adquirir uma trava exclusiva por `(canal, self)`, resolvida no tronco (`--git-common-dir`), e fazer dentro dela a releitura do log próprio, a decisão e a gravação, sem gravar a partir de uma leitura feita antes da trava.
- **Critérios de aceite:**
  - [ ] Fixture de concorrência: 20 `send` simultâneos na mesma thread → 20 mensagens no log, `seq` 1..20 sem buraco nem repetição, nenhuma perdida; o mesmo teste falha (visto vermelho) sem a trava.
  - [ ] Fixture de concorrência entre `sync --push-only` (transporte `fs`) e 10 `send` simultâneos → nenhuma mensagem perdida no log próprio nem no hub.
  - [ ] Duas worktrees do mesmo repositório disputam a mesma trava (ela mora no tronco), conferido por fixture.
  - [ ] Trava não obtida em 10 segundos → rc 1, nada gravado, nomeando o dono da trava (pid, host, início).
  - [ ] Trava abandonada (pid dono inexistente no mesmo host, ou idade acima de 120 segundos) é recuperada com aviso em stderr nomeando o dono antigo; fixture para os dois casos.
  - [ ] Dentro da trava só roda leitura do canal, dobra, montagem do envelope e gravação local; geração de handoff, escrita de blob, varredura de segredo e transporte de rede rodam fora dela. Antes de gravar, o escritor confere que a trava ainda é dele; se foi recuperada por outro, aborta sem gravar (rc 1), conferido por fixture que simula a recuperação no meio da seção.
  - [ ] Um único ponto de aquisição usado por todos os escritores, conferido por teste que varre `liaison-ops.sh`, `lib/` e `lib/transports/` e reprova escrita em `log/<self>.jsonl` fora dele.
  - [ ] A trava e todo estado local do bastão (claims vencedoras, perdas exibidas, próximo instante de renovação, resultado de publicação) ficam em `.forge/cache/`, já ignorado pelo bloco gerenciado do `.gitignore` (nunca no `state.json` do canal, que é versionado), e nunca são transportados pelo `export`/`sync`.
  - [ ] A janela residual entre a conferência de posse da trava e o `rename` final (só alcançável depois de uma recuperação por idade, isto é, de uma seção crítica acima de 120 s) é registrada na rule como limite, com a detecção existente: `seq` repetido no log próprio aparece como posição forkada no `status`.
- **Rastreia:** proposal §2.3

## REQ-10 — Identidade de sessão

- **Quando** um subcomando `baton` grava ou decide por titularidade, **o sistema deve** obter `session` de `--session <id>` ou, na ausência, de `CLAUDE_CODE_SESSION_ID`; sem nenhum dos dois, recusar com rc 1 dizendo que agentes sem essa variável (Codex, Cursor, Gemini) devem passar `--session`.
- **Critérios de aceite:**
  - [ ] `session` aceita `^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$`; fora disso → rc 1.
  - [ ] Duas sessões do mesmo repositório com identificadores diferentes são titulares diferentes na dobra (REQ-04), conferido por fixture.
  - [ ] Continuidade: a identidade é o identificador da sessão, e uma sessão que recebe identificador novo (por exemplo depois de `/clear`) é outra titular; a documentação diz que, antes de trocar de sessão, a titular libera o bastão (`baton release`) ou aceita que a sessão nova só retome depois de `lease_until + folga`. A semântica de identificador do Claude Code em `/clear`, `--resume`, `--continue` e compactação é medida no design e fixada por fixture, e a documentação reflete o medido.
  - [ ] A rule e o `/forge:liaison` registram que `session` é autodeclarado: ele separa sessões honestas do mesmo repositório, não autentica; quem falsifica o identificador de outra sessão do mesmo repositório já tem acesso de escrita ao log e ao repositório.
- **Rastreia:** proposal §2.3

## REQ-11 — Escritor único e compatibilidade com o canal existente

- **Quando** qualquer operação de bastão é executada, **o sistema deve** escrever só no log próprio e manter válidas as regras de import, a cobrança de ack e a verificação de procedência existentes.
- **Critérios de aceite:**
  - [ ] Teste que varre os caminhos de escrita dos subcomandos `baton` e reprova qualquer escrita fora de `log/<self>.jsonl`, `blobs/`, `CHANNEL.md` (pelo `render` que todo escritor do canal já chama), do estado local não versionado e da trava.
  - [ ] `check-liaison-acks.sh` sobre um canal de fixture com todas as operações de bastão, de três repositórios → nenhum ack pendente novo e a verificação de `trust` sem violação.
  - [ ] Import de bundle com mensagem de bastão cujo `sender` não confere com o arquivo → conflito, como qualquer mensagem (regra existente, fixture nova).
  - [ ] As mensagens de bastão de peer chegam com `trust: untrusted-peer` e não carregam `authored_by` (o autor é o próprio `sender`).
  - [ ] Todos os gates existentes do liaison continuam verdes depois da troca do desempate (REQ-04) e da trava (REQ-09): `w110`, `w111`, `w112`, `w113`, `w136`, `w140`, `w143`, `w150`, `w166`, `w167`, `w168`, `w169`, `w195`, `w198`, `w219`, `w220`, `w258`, `w259`, mais qualquer gate cujo nome contenha `liaison` no momento da implementação; a lista é recalculada por `ls tests/*liaison*-gate.sh` no próprio critério, e a suíte completa (`tests/run-all.sh`) fica verde.
- **Rastreia:** proposal §2.1, §3

## REQ-12 — Renovação automática enquanto a sessão está ativa

- **Quando** `liaison.auto` e `liaison.baton.auto_renew` estão ligados e uma sessão do Claude Code que detém um bastão continua ativa, **o sistema deve** renovar o lease dela automaticamente quando restar menos da metade do prazo, a partir de um evento de ciclo de vida do Claude Code que ocorre enquanto a sessão age, inclusive em turnos longos (a escolha do evento é decisão de design), e **não deve** renovar quando a sessão está parada, para que o lease de uma sessão morta ou ociosa expire.
- **Critérios de aceite:**
  - [ ] Renova só bastões cuja titular corrente é a sessão do evento (identificador `session_id` lido do JSON do próprio evento, cuja igualdade com o `CLAUDE_CODE_SESSION_ID` que o REQ-10 usa para gravar é medida no design e fixada por fixture) e cujo lease ainda não venceu, pelo mesmo caminho do `baton renew` (REQ-07); nunca reivindica, nunca renova lease vencido.
  - [ ] No máximo uma renovação por bastão a cada metade de prazo: a condição "resta menos da metade" é reconferida pela dobra dentro da trava (REQ-09) antes de gravar; conferido por fixture que dispara o evento 50 vezes seguidas e por fixture que dispara 10 eventos concorrentes, ambas com exatamente uma renovação.
  - [ ] Caminho sem bastão detido e caminho "detém, mas ainda não é hora de renovar" terminam em ≤ 150 ms no p95 (NFR-02) e não gravam nada: o próximo instante de renovação de cada bastão detido fica em estado local não versionado, e a dobra só roda quando ele chega.
  - [ ] Depois de renovar, se a thread tem participante de outro repositório e o canal tem transporte `fs`, `fs-union` ou `git`, o `sync --push-only` roda desacoplado do evento (em segundo plano, com timeout de 30 s e registro do resultado em estado local), de modo que o evento termina dentro do teto acima mesmo com transporte travado; fixture com transporte que não responde mede o tempo do evento. Falha de publicação vira aviso no próximo evento e no `baton status`, nunca erro do evento.
  - [ ] Canal com transporte `manual` ou sem transporte: o gancho renova localmente e o `baton status` avisa que os outros repositórios não veem a renovação até uma publicação deliberada.
  - [ ] O gancho nunca bloqueia a sessão (rc 0 sempre) e reporta em stderr o que renovou ou por que não renovou.
  - [ ] Fiação gerada por `sync-adapters.mjs` a partir da configuração, sem literal novo, com instalação nova armada e consumidor com `.claude/settings.json` pré-existente recebendo o gancho conforme a regra de fiação existente para categorias derivadas; gate de fiação com `liaison.auto` e `auto_renew` nas quatro combinações.
  - [ ] Agentes sem ganchos renovam manualmente com `baton renew`, documentado.
- **Rastreia:** proposal §2.4, §2.7

## REQ-13 — Bastão no início de sessão

- **Quando** uma sessão começa com `liaison.auto` ligado, **o sistema deve** acrescentar ao bloco do liaison do `on-session-start.sh` as ofertas disponíveis em que este repositório é elegível, os bastões detidos por sessões deste repositório (sessão, `lease_until`, `provisional`/`stable`, `expired`) e as perdas tardias (REQ-05) ainda não exibidas, com `baton_id` e assunto, nunca o corpo.
- **Critérios de aceite:**
  - [ ] Assuntos vindos de peer passam por `untrusted-render`, e o bloco mantém o aviso existente de que conteúdo de peer é dado.
  - [ ] Cada perda tardia é exibida uma vez e marcada como entregue em estado local não versionado; fixture com duas sessões consecutivas.
  - [ ] Falha do cálculo de bastão não some com o bloco: aparece uma linha nomeando a falha, como o `doctor` já faz com `status`.
  - [ ] Bastão detido por sessão deste repositório que não é a sessão que começa aparece com a nota "detido por outra sessão (<id>); se ela terminou, libere com `baton release --session <id>` ou aguarde o vencimento". Liberar com o identificador de outra sessão do mesmo repositório é ato deliberado do operador, possível porque `session` é autodeclarado (REQ-10), e fica registrado no log como qualquer operação.
  - [ ] Sem nenhum bastão, o bloco não ganha linha nova.
- **Rastreia:** proposal §2.7

## REQ-14 — Oferta a partir do `/forge:handoff`

- **Quando** o operador roda `baton offer ... --from-handoff`, **o sistema deve** usar como corpo da oferta o `HANDOFF.md` que `handoff-gen.sh` gera para a árvore de trabalho corrente, gerado na hora se ausente, gravado como blob com a mesma varredura de segredo e o mesmo teto de 64 KB do `--body-file`, tudo antes de adquirir a trava.
- **Critérios de aceite:**
  - [ ] `--from-handoff` junto de `--body` ou `--body-file` → rc 1.
  - [ ] Handoff acima de 64 KB, com achado de segredo, ou geração falhando → rc 1, nada gravado.
  - [ ] O `/forge:handoff` documenta que o snapshot não tem dono e que, para transferir posse, o caminho é `baton offer --from-handoff`; o comportamento do `/forge:handoff` sem essa flag não muda (gate existente do handoff verde).
- **Rastreia:** proposal §2.7, §3

## REQ-15 — Campainha opcional

- **Quando** uma oferta, uma liberação ou uma conclusão é publicada, **o sistema deve** permitir avisar outra sessão pelo `notify` de `add-liaison-native-bridge` (ponteiro `liaison:<channel>/<msg_id>` para a mensagem de bastão publicada), e **não deve** depender do aviso para nenhuma decisão de posse.
- **Critérios de aceite:**
  - [ ] Gate do fluxo completo (oferta, duas reivindicações concorrentes, renovação, liberação, nova reivindicação, conclusão) entre duas réplicas sem nenhum `notify` → mesmo resultado que com `notify`.
  - [ ] `notify` sobre `baton_id` publicado → ponteiro válido aceito pelo gancho de saída de `add-liaison-native-bridge` (fixture daquele change reaproveitada); sobre oferta não publicada → recusa daquele change, inalterada.
  - [ ] Nenhum script ou gancho deste change envia mensagem entre sessões; a checagem do gate `w113` continua verde sobre os arquivos novos.
- **Rastreia:** proposal §2.7

## REQ-16 — Norma e documentação

- **Quando** este change for entregue, **o sistema deve** ter a rule `liaison-protocol.md` com uma seção do bastão (quando usar: unidade de trabalho que uma sessão de outro repositório participante poderia duplicar; quando não usar: coordenação só dentro do repositório; as seis operações; a dobra, a ordem e o desempate por code point; `provisional` versus `stable`; lease, folga e o carimbo como exceção declarada ao invariante de relógio, com seus limites; identidade de sessão autodeclarada; renovação automática e manual, com a publicação automática da renovação declarada como exceção ao item 5 da rule, "Sincronize deliberadamente"), o `/forge:liaison` documentando o subcomando `baton` e seus oito verbos (`offer`, `claim`, `renew`, `release`, `complete`, `withdraw`, `status`, `list`), o `/forge:handoff` com a nota do REQ-14, `docs/refer/slash-commands.md`, inventário de gates e scripts, entrada em `CHANGELOG.md` sob `[Unreleased]` e badge de gates do `README.md` atualizados.
- **Critérios de aceite:**
  - [ ] `baton` consta do `argument-hint` do `/forge:liaison`; para cada verbo, o conjunto de flags documentado é igual ao conjunto da mensagem de flags aceitas do script, conferido por teste.
  - [ ] `plugin/forge/commands/liaison.md` e `plugin/forge/commands/handoff.md` iguais às versões do template (gate de sincronia do plugin verde).
  - [ ] `validate-rules.sh` com `FORGE_ROOT` no template passa, com `last_reviewed` da rule atualizado.
  - [ ] A rule cita a classe "trabalho sobreposto" que `add-liaison-native-bridge` torna obrigatória no liaison e diz que o bastão é o registro estruturado dela.
  - [ ] O comentário de cabeçalho de `liaison-ops.sh` sobre relógio de parede e a descrição de `created_at` no schema passam a citar `stamped_at` como a exceção declarada.
  - [ ] Os gates de documentação existentes (CHANGELOG, badge, inventário) ficam verdes.
- **Rastreia:** proposal §2.7, §2.8

## Requisitos não funcionais do change

- **NFR-01 —** Zero dependência nova de runtime: bash, node (built-ins), git e o fallback `jq`/`python3` já usado pelos ganchos. Método: diff de `package.json` vazio e varredura de `require`/`import` nos arquivos novos.
- **NFR-02 —** O gancho de renovação, nos caminhos sem bastão detido e com bastão detido fora da hora de renovar, completa em ≤ 150 ms no p95, e no caminho que renova completa em ≤ 2,5 s no p95 sem esperar o transporte, sobre um canal de fixture com 2.000 mensagens; a dobra sobre uma thread de 2.000 mensagens de bastão completa em ≤ 500 ms; a seção crítica sob a trava, com 2.000 mensagens no canal, completa em ≤ 2 s no p95. Método: 50 execuções medidas com `node:perf_hooks`; fonte: relatório de verificação.
- **NFR-03 —** TDD: cada REQ tem ao menos um gate em `tests/` escrito e visto vermelho antes da implementação. Método: commit do teste vermelho anterior ao da implementação, conferido no `verify`.

## Checklist de cobertura de superfície

| REQ | Parâmetro/config exposto | Superfície (tela/endpoint/CLI) | Coberto por task |
|---|---|---|---|
| REQ-01 | campo `baton` (`op`, `session`, `stamped_at`, `eligible`, `max_lease_seconds`, `skew_tolerance_seconds`, `lease_seconds`, `lease_until`) | `liaison-message.schema.json`; envelope gravado pelo CLI `liaison-ops.sh baton` | TASK-13, TASK-14 |
| REQ-02 | `baton offer <channel> --thread --subject [--body/--body-file/--from-handoff] [--for] [--max-lease] [--session]` | CLI `liaison-ops.sh baton offer` | TASK-19, TASK-20 |
| REQ-03 | `baton claim <channel> <baton_id> [--lease] [--session]` | CLI `liaison-ops.sh baton claim` | TASK-19, TASK-20 |
| REQ-04 | sem parâmetro exposto (função pura; desempate por code point no `threadOrder`) | consumida por `baton status`, `status`, `render`, `on-session-start.sh` | TASK-02, TASK-03, TASK-15, TASK-16 |
| REQ-05 | sem parâmetro exposto (marca `provisional`/`stable`) | CLI `liaison-ops.sh baton status`; início de sessão | TASK-15, TASK-16, TASK-23, TASK-24 |
| REQ-06 | `liaison.baton.default_lease_seconds`, `max_lease_seconds`, `skew_tolerance_seconds`; `--lease`, `--max-lease` | `forge.yaml`; CLI `liaison-ops.sh baton claim/renew/offer` | TASK-17, TASK-18, TASK-21, TASK-22 |
| REQ-07 | `baton renew <channel> <baton_id> [--lease] [--session]`; `baton release/complete/withdraw <channel> <baton_id> [--session] [--body/--body-file]` | CLI `liaison-ops.sh baton` | TASK-21, TASK-22 |
| REQ-08 | `baton status <channel> [<baton_id>] [--json]`, `baton list <channel> [--json]` | CLI `liaison-ops.sh baton`; `liaison-ops.sh status`; `CHANNEL.md` | TASK-23, TASK-24 |
| REQ-09 | sem parâmetro exposto (trava interna, timeout fixo de 10 s e recuperação de 120 s) | todos os escritores do `liaison-ops.sh`, inclusive o push do `sync` | TASK-04, TASK-05, TASK-06, TASK-07, TASK-08, TASK-09 |
| REQ-10 | `--session <id>`; variável `CLAUDE_CODE_SESSION_ID` | CLI `liaison-ops.sh baton` | TASK-17, TASK-18 |
| REQ-11 | sem parâmetro exposto (invariantes) | import, `check-liaison-acks.sh` | TASK-12, TASK-13, TASK-19 |
| REQ-12 | `liaison.baton.auto_renew` | `forge.yaml`; gancho de ciclo de vida do Claude Code gerado por `sync-adapters.mjs` | TASK-26, TASK-27 |
| REQ-13 | sem parâmetro próprio (usa `liaison.auto`) | `on-session-start.sh` | TASK-28, TASK-29 |
| REQ-14 | `--from-handoff` | CLI `liaison-ops.sh baton offer`; `/forge:handoff` (documentação) | TASK-30, TASK-31 |
| REQ-15 | sem parâmetro próprio (usa `notify` de `add-liaison-native-bridge`) | CLI `liaison-ops.sh notify`; `SendMessage` do agente | TASK-20, TASK-25 |
| REQ-16 | sem parâmetro exposto (documentação) | `/forge:liaison`, `/forge:handoff`, rule `liaison-protocol`, `docs/refer/slash-commands.md` | TASK-32, TASK-33 |

## Fora de escopo (reafirmação)

- Formato do store, transporte, regras de import e cálculo de `trust` do liaison; da ordem da thread muda só o desempate de `sender`, de `localeCompare` para code point (REQ-04).
- Substituição do `/forge:handoff`: ele continua o caminho agente-agnóstico de passar contexto sem posse.
- Bastão em thread sem participante de outro repositório (coordenação só interna continua em ledger, specs e `ephemeral: internal-coordination`).
- Tomada forçada de bastão com lease vigente, por humano ou ofertante, como funcionalidade.
- Exclusão mútua forte entre réplicas não sincronizadas (o limite é explícito no REQ-05).
- Várias cópias do mesmo `self.id` escrevendo em clones diferentes.
- Autenticação de sessão e de carimbo: ambos são autodeclarados (REQ-06, REQ-10).
- Envio de mensagem entre sessões por script ou gancho.
- Servidor, banco ou daemon externo de coordenação.

**Atualização no `ship` (2026-11-02, round 1 do code-evaluator, ARCH-001):** o `baton renew` recusado deixou de sair sempre com rc 1. Perda real (sessão que não é a titular corrente, ou lease vencido) sai com rc 4; "ainda não é hora", só com `FORGE_BATON_RENEW_IF_DUE=1`, sai com rc 5; erro ou transitório (trava ocupada ou perdida, oferta desconhecida, argumento inválido) continua com rc 1. Onde o REQ-07 acima diz rc 1 para o renew, vale este contrato, registrado no baseline como SCN-FHT-092-C. O gancho de renovação automática só trata como perda o rc 4.
