# Análise — benchmark `data-object-storage` (agente)

## Resultado

| Configuração | Pass rate (média) | Desvio | Tempo médio |
|---|---|---|---|
| Com skill (`data-object-storage-practices`) | 73,33% (0,7333) | ±0,3055 | 291,0s |
| Sem skill | 18,89% (0,1889) | ±0,2009 | 207,0s |
| Delta | **+0,5444** | — | +84,0s |

`tokens` e `tool_calls` aparecem como 0 nos três `timing.json` de cada configuração — a instrumentação de tokens/tool-calls não foi capturada nesta rodada; os agregados de token do `benchmark.json` são inertes e não devem ser lidos como "custo zero".

Veredito: **agrega** (delta ≥ 0,15).

## Asserções não discriminantes

- Eval `revisao-armazenamento-comprovantes-pre-pr`, expectativa 6 ("`git status --porcelain` vazio, nenhuma correção aplicada na árvore") passa nas duas configurações (com e sem skill). Isso testa a ausência de `Write`/`Edit` no agente — uma restrição do frontmatter, não um efeito da skill — e não diferencia o valor da skill.
- Eval `bronze-liquidacao-adquirente-com-pan`: as expectativas 1 (identifica T-03) e 2 (contesta a premissa de que SSE-KMS cobre o PAN) passam nas duas configurações. O modelo base já reconhece PAN em claro e a insuficiência de criptografia de armazenamento sem a skill — a skill não é o que diferencia esse julgamento específico.

## Onde a skill ajudou

- Eval `conflito-adr-sse-s3-bucket-extratos` é o caso de maior diferença: com skill 0,80 (4/5) contra 0,00 (0/5) sem skill. Sem a skill, o agente resolveu o conflito ADR-0003 (SSE-S3) vs. checklist (SSE-KMS+Bucket Key) sozinho — adotou AES256 em silêncio ("para não travar a entrega") e não emitiu o bloco `CONFLITO`, violando exatamente a regra "nunca registre e siga" que a skill/agente exige. Com a skill, o agente emitiu o bloco completo (decisão/posição A/posição B/precedência/opções/registro), aplicou a ordem de precedência do `FORGE.md §2.1` e devolveu a decisão ao humano sem aplicar Terraform algum — o protocolo de "parar e devolver" do agente só funcionou de forma confiável com a skill carregada.
- Eval `revisao-armazenamento-comprovantes-pre-pr`: com skill, 6/6 — o agente citou cada antipattern pelo id do catálogo (O-01, O-08, O-02, O-11, O-03/O-04) com arquivo:linha exato. Sem skill, 1/6 — o agente encontrou os mesmos problemas em prosa, mas sem os ids, sem linhas exatas em metade dos casos, e para O-02 (URL pré-assinada ao parceiro) manteve o envio por e-mail com expiração de 4h, violando a decisão H-02(a) que a skill/agente tornam explícita (HTTPS, objeto único, minutos, endpoint REST autenticado). Esse é o antipattern de maior risco prático (vazamento de PAN/PII a terceiro) e só foi corrigido corretamente com a skill.

## Onde a skill atrapalhou ou não fez diferença

- Eval `bronze-liquidacao-adquirente-com-pan` empatou exatamente em 0,4 (2/5) nas duas configurações — não há vantagem mensurável da skill neste caso específico, o que contrasta com a média geral. Detalhe: a expectativa 4 ("WORM condicionado a obrigação legal registrada + conciliação LGPD para as demais fontes, em vez de aprovar os 10 anos por padrão") falhou nas duas configurações, mesmo a skill trazendo esse exato requisito no checklist ("WORM só com obrigação legal registrada e conciliação LGPD antes de travar"). O agente com skill tratou apenas o prefixo do cartão como caso especial e aprovou os 10 anos "por padrão" para as demais fontes sem essa condicionante — indício de que o checklist não é aplicado de forma sistemática a todo o escopo da pergunta, só ao ponto que o usuário sinalizou como sensível.
- A mesma eval, expectativa 5 (O-13: overwrite→append-only, "deixando correção e dedupe para a silver"): com skill o agente identificou O-13 corretamente e propôs append-only, mas nunca mencionou explicitamente o hand-off de dedupe para a silver — falhou por uma cláusula composta que nem a skill nem o agente tornam explícita como parte da correção de O-13.
- A skill adiciona, em média, 84s por execução (291s vs 207s), plausivelmente do passo 1 (rules/ADRs/baseline), do `check-data-governance.sh` e do `scan.sh` do protocolo fixo — custo razoável frente ao ganho de 54 pontos percentuais, mas relevante se o catálogo de evals crescer e o tempo por chamada virar gargalo.

## Trechos ignorados, ambíguos ou contraditórios

- Eval `conflito-adr-sse-s3-bucket-extratos`, expectativa 2 exige citar o ADR pelo caminho literal `.forge/product/current/adr/0003-criptografia-de-buckets-sse-s3.md` **dentro do bloco `CONFLITO`**. O agente com skill citou "ADR-0003 (baseline)" no bloco e usou o caminho completo só no transcript (fora do bloco), e atribuiu a posição B ao "checklist do agente data-object-storage" em vez de "skill ou base" — falhou por formalidade de citação, não por erro de julgamento. É uma asserção estrita o bastante para penalizar uma resposta substancialmente correta; vale revisar se o protocolo deveria instruir explicitamente "cite o caminho do arquivo do ADR dentro do próprio bloco `CONFLITO`", ou se a asserção do eval deveria aceitar citação equivalente sem o caminho literal.
- Eval `bronze-liquidacao-adquirente-com-pan`, expectativa 3 prescreve um mecanismo específico para excluir o prefixo do cartão do WORM — "expira por ciclo de vida no prazo da política de retenção". O agente com skill usou um mecanismo alternativo (crypto-shredding: revogar a chave KMS de campo em vez de apagar o objeto), tecnicamente válido sob PCI DSS 3.2.1/LGPD mas diferente do mecanismo exigido pela asserção, e por isso o grading marcou falha apesar do resultado prático (PAN inacessível após o prazo) ser equivalente. Vale registrar se o catálogo de antipatterns da skill deveria recomendar explicitamente lifecycle-expiration como o padrão preferido para esse caso, para alinhar a resposta do agente ao que o eval espera — ou se o eval deveria aceitar crypto-shredding como alternativa válida.

## Melhorias concretas priorizadas

1. **Alta prioridade — aplicar o checklist WORM/LGPD ao escopo inteiro, não só ao ponto sinalizado pelo usuário.** No protocolo do agente (passo 5, "Julgamento"), explicitar que, ao revisar Object Lock/WORM, o agente deve verificar a condicionante "obrigação legal registrada + conciliação LGPD" para **todas as fontes/prefixos tocados pela pergunta**, não apenas o prefixo com dado sensível citado pelo usuário. Isso teria corrigido a expectativa 4 de `bronze-liquidacao-adquirente-com-pan` nas duas configurações, mas em especial validaria o valor da skill onde hoje ela empata com "sem skill".
2. **Média prioridade — tornar explícito o hand-off de dedupe para a silver na correção de O-13.** No catálogo de antipatterns (`references/antipatterns.md`), a entrada O-13 deveria incluir a frase-padrão "correção e deduplicação ficam para a camada silver, não para o bronze" como parte do texto de correção, para que respostas que aplicam append-only também declarem esse limite de escopo.
3. **Média prioridade — instruir citação de caminho literal do ADR dentro do bloco `CONFLITO`.** No template do bloco `CONFLITO` (seção "Protocolo" do agente), adicionar uma nota de que a posição que cita ADR/baseline deve incluir o caminho do arquivo no próprio campo `posição A`/`posição B`, não só no raciocínio fora do bloco — alinha a resposta ao formato que os evals (e presumivelmente revisores humanos) esperam.
4. **Baixa prioridade — instrumentar tokens/tool_calls.** Os três `timing.json` desta rodada não capturam tokens nem chamadas de ferramenta; sem esse dado não é possível avaliar se o custo de tokens da skill é proporcional ao ganho de acerto, só o tempo de parede.
5. **Baixa prioridade — considerar mecanismo alternativo (crypto-shredding) como corretor válido no catálogo.** Se a intenção do time é aceitar crypto-shredding como equivalente a lifecycle-expiration para excluir dado sensível do WORM, documentar isso na skill evitaria que uma resposta tecnicamente correta seja penalizada; se a intenção é exigir lifecycle-expiration especificamente (auditoria mais simples), reforçar isso no checklist do agente.
