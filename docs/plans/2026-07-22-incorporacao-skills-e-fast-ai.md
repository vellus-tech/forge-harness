# Plano de incorporação de skills do e-fast-ai

## Sumário executivo

O repositório externo oferece uma coleção bem delimitada de 16 skills de "squad": uma orquestradora, especialistas por stack e práticas transversais para banco, segurança, testes, Docker, documentação, revisão e Git. Sua maior contribuição potencial para o Forge é tornar as escolhas técnicas e os critérios de aceite mais explícitos para cada stack. Ele não deve ser copiado nem instalado como está: introduziria uma segunda fonte de verdade em `.squad/config.yaml`, `.squad/memory.md` e `docs/adr/`, incompatível com a governança canônica do Forge em `.forge/`, baseline versionado, worktrees e gates do lifecycle SDD.

Recomendação: adotar a estratégia 2, "extração seletiva com perfis de capacidade", em três ondas. Ela reutiliza os conteúdos práticos de maior valor, preserva o modelo de dados e os controles deterministas do Forge, e evita reescrever a plataforma antes de provar valor com avaliações A/B.

## Escopo e evidências

Fonte analisada: `RAFAEL-SILVASOUZA/e-fast-ai`, diretório `.opencode/skills`, commit `ef2e885b917a1781b4410d7a44bbb32f1f1d8787` (2026-07-04). O diretório contém `squad` e especialistas para arquitetura, C#/.NET, Java, Node, Python, React, Angular, banco, segurança, testes de backend e frontend, Docker, documentação, code review e Git. O subdiretório `skill-creator` é uma exceção: traz licença Apache-2.0 atribuída à Anthropic; não foi encontrada uma licença de repositório que cubra claramente as demais skills. Antes de copiar texto substancial das skills de squad, validar proveniência e licença com o mantenedor; até então, usar apenas ideias reimplementadas de forma independente.

O Forge já contém os mecanismos que faltam ao repositório externo: fonte única em `.forge/`, change lifecycle, baseline e ADRs em `docs/product/adr/`, análise de impacto por grafo, worktrees, gates deterministas, agentes de arquitetura/revisão/engenharia, handoff, ledger e `/forge:skill-lifecycle` com avaliação A/B e holdout de triggering. Portanto, a lacuna não é orquestração nem persistência de estado; é a cobertura operacional orientada a stack e a tradução de requisitos transversais em checklists de mudança testáveis. A revisão independente também encontrou um pré-requisito interno: o adapter `agents-skills` declara/testa contagem fixa de quatro skills, enquanto o template atualmente contém dez. A instalação temporária projetou as dez e o smoke falhou; esse contrato deve ser corrigido antes de expandir o catálogo.

## O que absorver e o que não absorver

| Origem externa | Valor a absorver | Destino Forge | Decisão |
|---|---|---|---|
| `squad-backend-*` e `squad-frontend-*` | Defaults explícitos por stack, regras de fronteira, validação de entrada e anti-padrões de runtime | Perfis em `.forge/custom/capabilities/` e regras por stack | Absorver por adaptação, nunca como defaults universais |
| `squad-database` | Expand-migrate-contract, classificação de migrations seguras/perigosas e referência por engine | Rule de dados + checklist no design/verify | Alta prioridade |
| `squad-seguranca` | Threat prompts por demanda, teste IDOR, segredos, logs e dependências | Extensão do `security-reviewer` e do contrato de verify | Alta prioridade, com severidade proporcional ao risco |
| `squad-testes-*` | Contrato mínimo de testes, mocks na fronteira, estados de UI e anti-flakiness | Regras de teste + tarefas geradas | Alta prioridade |
| `squad-docs` | Matriz "mudança → documento/diagrama" e DER derivado de migrations | Archive/publish-docs e `c4-render` | Média prioridade |
| `squad-code-review` | Formato simples e hierárquico de parecer | View humana do `code-evaluator` | Média prioridade; não criar segundo gate |
| `squad-docker` | Diagnóstico operacional e healthchecks | `/forge:dev` e regras de Docker | Média prioridade, mas sem assumir Docker disponível |
| `skill-creator` | Disciplina de benchmark, comparação cega e otimização de description | Evoluir `/forge:skill-lifecycle` já existente | Baixa prioridade: o Forge já cobre o núcleo |
| `squad`, `.squad/config.yaml`, `.squad/memory.md` | Nenhum mecanismo novo que justifique uma fonte paralela | Não aplicável | Não absorver |
| `squad-git` | Convenções úteis, porém já cobertas por worktree, `/forge:ship` e regras do Forge | Não aplicável | Não absorver, salvo ajustes pontuais de texto |

## Estratégia 1 — Importação compatível do squad como pacote opcional

### Visão geral da abordagem

Esta opção encapsula as 16 skills externas como um pacote opcional do Forge, reescrevendo paths `.squad/*` para `.forge/*`, substituindo `docs/adr/` por `docs/product/adr/` e gerando aliases de comandos para acioná-las. A lógica é: mapear cada referência externa, converter sua persistência para o manifest e ledger do change, registrar cada skill no plugin e criar gates de compatibilidade para impedir qualquer escrita fora do modelo Forge.

### Principais vantagens

- Entrega rápida de ampla cobertura por stack e disciplina transversal.
- Mantém os textos especializados praticamente intactos, reduzindo trabalho editorial inicial.
- Permite uma experiência de entrada simples para times que querem pedir "use o squad".

### Principais desvantagens

- Alto risco de duplicação conceitual com os agentes, skills e comandos já existentes no Forge.
- Adaptar paths não resolve conflitos semânticos: o squad pressupõe fluxo obrigatório migration → código → testes → docs → review → commit, enquanto o Forge é adaptativo por escala e usa HITL, specs e waves.
- Gatilhos muito largos podem disputar execução com agentes e comandos existentes, elevando custo e comportamento não determinístico.
- Exige auditoria de licenciamento/proveniência antes de redistribuir conteúdo de terceiros no npm.

### O que ganharemos com essas melhorias

Ganharíamos velocidade de catálogo e uma superfície imediata de especialidades, ao custo de governança mais frágil. É adequada apenas como experimento local, isolado e não distribuído, depois de resolver licença e provar que os gatilhos não colidem.

## Estratégia 2 — Extração seletiva com perfis de capacidade do Forge (recomendada)

### Visão geral da abordagem

Esta opção transforma os melhores princípios externos em capacidades nativas e opt-in, sem importar a orquestradora. A lógica é: primeiro inventariar duplicações contra rules, agents e commands do Forge; depois transformar somente lacunas comprovadas em perfis de stack; por fim, acoplar esses perfis aos pontos determinísticos do lifecycle (design, task generation, implement, verify e archive), com evals A/B antes de torná-los padrão.

### Principais vantagens

- Preserva uma única fonte de verdade e o lifecycle SDD já validado.
- Evita presets tecnológicos em projetos brownfield: o detector do Forge propõe o perfil, mas o código existente e os ADRs continuam tendo precedência.
- Cada incremento pode ter schema, gate, teste de regressão e rollback independente.
- Concentra o ganho onde ele é concreto: migrations, segurança, estratégia de testes, documentação viva e diagnóstico de ambiente.

### Principais desvantagens

- Requer curadoria e redação própria, portanto leva mais tempo que copiar arquivos.
- A primeira versão não terá a sensação de "squad completo" do repositório externo.
- Perfis demais podem virar uma taxonomia rígida; por isso devem ser poucos, composáveis e opt-in.

### O que ganharemos com essas melhorias

O Forge passará a converter decisões de arquitetura e stack em critérios verificáveis de implementação, sem perder adaptabilidade. Em especial: migrations incompatíveis serão detectadas no design; endpoints que recebem recurso identificarão o teste de autorização/IDOR exigido; mudanças de UI terão estados mínimos de loading/erro/vazio; e o archive saberá quais documentos atualizar conforme o impacto real.

## Estratégia 3 — Plataforma de policies declarativas e gerador de specialists

### Visão geral da abordagem

Esta opção usa o conteúdo externo como insumo para um novo sistema declarativo: um `capability-profile.yaml` define stack, banco, frontend, runtime, compliance e nível de risco; um gerador materializa rules, prompts de agentes, checklists e gates específicos. A lógica é: definir o schema de capacidade; criar resolutor de precedência `baseline/ADR → custom → perfil → default`; gerar views para design, tasks e verify; e testar combinações de perfil por fixtures.

### Principais vantagens

- Escala melhor para muitas stacks e para ofertas white-label do Forge.
- Elimina duplicação futura entre skills, rules e agentes, porque a policy passa a ter uma origem declarativa.
- Permite controles regulatórios por domínio e risco sem codificar um projeto de referência no template.

### Principais desvantagens

- É uma mudança de plataforma, com risco de quebrar o contrato atual de adapters e update cirúrgico.
- O gerador pode esconder instruções importantes atrás de abstração e dificultar debugging do agente.
- Exige desenho de schema, precedência, versionamento, migração e uma matriz de compatibilidade antes de entregar valor funcional.

### O que ganharemos com essas melhorias

Ganharíamos uma base extensível para perfis de engenharia e compliance, útil quando houver demanda recorrente por combinações como Node + Postgres + PCI, Java + Oracle ou React + design system. É a melhor arquitetura de longo prazo, mas prematura sem evidência de uso repetido dos primeiros perfis.

## Decisão

A estratégia 2 oferece o melhor equilíbrio entre ganho, risco e tempo. Ela preserva os diferenciais do Forge — governança SDD, determinismo e multi-agente — e absorve o valor prático do repositório externo sem importar sua estrutura concorrente. A estratégia 3 fica registrada como evolução possível, condicionada a métricas de adoção e à repetição de pelo menos três perfis com composição semelhante. A estratégia 1 não deve seguir para distribuição.

## Plano de execução da estratégia recomendada

### Onda 0 — governança e baseline de evidência

1. Corrigir o contrato de contagem fixa do adapter `agents-skills` para inventariar skills dinamicamente, com regressão para o catálogo atual e para um catálogo estendido.
2. Registrar no ADR a decisão de não introduzir `.squad/` e a precedência de perfis: constitution → baseline/ADRs → customização do projeto → perfil → default.
3. Criar inventário rastreável de cada princípio externo com estado `duplicado`, `lacuna`, `conflitante` ou `descartado`; impedir que conteúdo substancial seja copiado até a checagem de licença/proveniência.
4. Definir métricas de sucesso: taxa de gates úteis, falsos positivos, tempo de verify, taxa de aprovação no primeiro round e adoção voluntária por perfil.
5. Criar fixtures greenfield e brownfield para C#/.NET relacional, Node/Postgres, Java relacional, Python e UI, sem mudar o template distribuído. A fixture .NET também cobre solução com múltiplos projetos, EF Core migrations, teste de integração e contrato HTTP.

### Onda 1 — quatro lacunas de alto valor

1. Criar uma rule de evolução segura de schema com os estágios expand → migrate/backfill → contract, exigência de rollback ou plano de reversão e checks por engine quando o runtime declarar banco relacional. Para .NET, incluir EF Core migrations, separação entre entidade de domínio e persistência quando exigida pela arquitetura, `CancellationToken`, nullable reference types e `ProblemDetails` como checks contextuais, não imposições universais.
2. Estender o contrato de design/tasks para declarar, quando aplicável, impacto em migration, compatibilidade de API, autorização por ownership e dados sensíveis em logs.
3. Estender as regras de testes com contrato mínimo orientado a mudança: domínio/invariantes, integração com recurso real quando houver persistência, IDOR para endpoint identificado por recurso e quatro estados de UI quando houver tela de dados.
4. Atualizar o `security-reviewer` e `code-evaluator` para tratar os novos critérios como sinais contextuais, nunca como grep absoluto que bloqueie projetos sem a tecnologia ou risco correspondente.
5. Criar gates determinísticos específicos apenas onde há sinal confiável, como migration destrutiva sem plano, endpoint mutável sem teste de autorização identificado e segredo/log sensível no diff; manter verificações semânticas nos reviewers.

### Onda 2 — perfis opt-in e documentação por impacto

1. Introduzir quatro perfis iniciais e compostos, priorizados nesta ordem: `backend-dotnet-relacional`, `backend-node-postgres`, `backend-java-relacional` e `backend-python-relacional`. C#/.NET é a linguagem principal e recebe a referência mais completa desde a primeira versão. Regras de UI ficam inicialmente transversais, pois o Forge já tem skill de auditoria visual. Cada perfil declara applicability, defaults não mandatórios, regras e comandos de verificação detectáveis.
2. Conectar o detector de stack do `forge doctor` ao perfil em modo sugestão; a ativação fica explícita no `FORGE.md` ou em customização do projeto.
3. Criar matriz de impacto `mudança → artefato` para que `/forge:archive` e `/forge:publish-docs` solicitem somente C4, DER, fluxo, glossário ou jornada efetivamente afetados.
4. Incorporar no `/forge:dev` apenas diagnósticos seguros de Docker: disponibilidade do daemon, healthcheck, estado de compose e logs limitados; não assumir Docker Desktop, não subir serviços sem pedido e não usar credenciais reais.

### Onda 3 — avaliação, rollout e decisão de produto

1. Para cada perfil, criar 6–10 cenários de avaliação: mudança simples, migration compatível, migration incompatível, endpoint com ownership, UI com estados assíncronos e brownfield que contraria o default.
2. Estender o eval de triggering com casos positivos e negativos, precision/recall, repetições e comparação cega com feedback humano; o holdout atual permanece, mas deixa de ser a única proteção contra sobreajuste.
3. Executar `/forge:skill-lifecycle eval` com e sem o perfil e comparar qualidade, duração, tokens e falsos positivos; usar holdout para alterar descriptions de triggering.
4. Rodar toda a suíte de gates, testes de fixtures e `npx pack` antes de publicar; validar também update cirúrgico em projeto existente para garantir que perfis e customizações não são sobrescritos.
5. Promover somente os perfis que superarem o baseline e não aumentarem materialmente falhas de compatibilidade; os demais permanecem experimentais ou são removidos.

## Edge cases e guardrails

- Brownfield vence: se código, ADR ou baseline divergir do perfil, o Forge deve detectar e explicar a divergência; jamais refatorar automaticamente para o preset.
- Multi-stack e monorepo: o perfil é resolvido por área afetada, não por repositório inteiro; uma migration Java e uma UI React não devem ativar regras da outra camada fora do diff.
- Migrations sem downtime: exigir expand-contract não significa bloquear correção de emergência; permitir exceção explícita, aprovada e registrada no manifest/ADR.
- Segurança proporcional: IDOR só é aplicável a recursos com ownership; endpoints públicos, administrativos ou de serviço precisam de modelos de autorização distintos, documentados no design.
- Docker indisponível: testes de integração não podem ser falsamente declarados verdes; registrar como não executados e indicar o gate pendente.
- Triggering: descriptions amplas são úteis para descoberta, mas não podem executar alterações; carregamento da skill deve ser barato e a ação destrutiva continua condicionada ao lifecycle e às aprovações.
- Atualização do Forge: qualquer novo perfil precisa respeitar `custom/` e o update preservador; não escrever em specs, baseline, ledger ou config de usuário durante instalação.
- Conflitos de regra: o conteúdo externo que exige `DECIMAL` para dinheiro não pode ser adotado como regra genérica porque conflita com a convenção Forge de inteiros em centavos; o perfil só adiciona uma alternativa se um ADR do projeto justificar precisão decimal.
- Monorepos e CI: inferência de stack, database e Docker deve ser por área afetada e serviço, com portas e recursos isolados; nunca iniciar Docker automaticamente nem presumir que uma base de testes compartilhada é segura em execução paralela.

## Critérios de aceite

1. Nenhum arquivo ou comando depende de `.squad/`, e não há segunda fonte de verdade para stack, memória, ADRs ou progresso.
2. Cada profile possui schema/validação, applicability explícita, precedência documentada, fixture greenfield e brownfield e teste de regressão.
3. Gates novos são determinísticos, contextualizados e reportam diagnóstico acionável; verificações probabilísticas continuam no reviewer.
4. O `forge update --dry-run` e o update real preservam `custom/`, specs, baseline e perfis configurados pelo projeto.
5. Evals A/B demonstram ganho mensurável ou o perfil não é promovido a padrão.
