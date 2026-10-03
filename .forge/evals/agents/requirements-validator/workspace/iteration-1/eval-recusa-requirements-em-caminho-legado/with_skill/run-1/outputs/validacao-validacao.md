# Validação do requirements.md

## Resultado

Status: Reprovado

Resumo:
- Total de achados BLOCKER: 3
- Total de achados HIGH: 2
- Total de achados MEDIUM: 1
- Total de achados LOW: 0

## Veredito

O arquivo enviado para validação está em `docs/specs/validacao/requirements.md`, um caminho legado que este projeto não usa. A estrutura oficial de especificação aqui é `docs/product/modules/<modulo>/requirements.md`, operada pelo `requirements-writer`, pelo `/forge:specs-loop` e pelos agentes irmãos `design-writer`/`tasks-writer`. Isso já basta para reprovar o documento e bloquear o pipeline, independentemente do conteúdo. Além disso, o próprio conteúdo está muito incompleto frente à estrutura obrigatória: faltam Escopo, Personas/Atores, Requisitos Não-Funcionais, Property-Based Testing, Glossário local, Fora do escopo do MVP e Referências cruzadas, e o único requisito funcional presente não tem os campos obrigatórios de Prioridade/Origem/Módulo. Não recomendo liberar o `design-writer` para o módulo Validação hoje.

## Achados

### [BLOCKER-01] Documento escrito em caminho legado não suportado (`docs/specs/`)

**Local:** caminho do arquivo — `docs/specs/validacao/requirements.md` (existe também `docs/specs/validacao/NOTA.md` confirmando que o time de embarcados criou a pasta deliberadamente fora do pipeline em 2026-09-10).
**Problema:** a estrutura oficial de especificação deste projeto é `docs/product/modules/<modulo>/requirements.md`. `docs/specs/` é um layout intermediário/legado (mesma família do `.kiro/specs/`) que não é reconhecido nem lido pelos agentes `design-writer`/`tasks-writer`, pelo `/forge:specs-loop`, nem por este validador como fonte oficial. O README canônico do módulo (`docs/product/modules/validacao/README.md`) ainda mostra `requirements.md: Não iniciado`, ou seja, para o pipeline este requirements simplesmente não existe.
**Impacto:** se o `design-writer` for liberado hoje, ele vai procurar o requirements em `docs/product/modules/validacao/` e não vai encontrar nada aprovado — ou, pior, alguém aponta manualmente o `design-writer` para o arquivo em `docs/specs/`, criando um segundo caminho de verdade paralelo ao pipeline oficial, sem rastreabilidade, sem versionamento reconhecido e sem histórico consolidado com os demais módulos (CRT, TRF, RCG).
**Correção recomendada:** mover o conteúdo para `docs/product/modules/validacao/requirements.md`, reexecutar o fluxo padrão (`requirements-writer` a partir do PRD/README do módulo, ou pelo menos reformatar o conteúdo existente dentro do template oficial) e apagar a pasta `docs/specs/validacao/` — inclusive o `NOTA.md`, que documenta o desvio do pipeline. "É mais rápido que o specs-loop" não é critério válido para trocar a fonte de verdade dos requisitos.

### [BLOCKER-02] Estrutura obrigatória amplamente ausente

**Local:** documento inteiro.
**Problema:** faltam as seções obrigatórias: Escopo, Personas/Atores, Lista canônica da entidade-chave, Requisitos Não-Funcionais, Property-Based Testing, Glossário local, Fora do escopo do MVP e Referências cruzadas. Só existem Título/metadados, Histórico de Versões, Visão Geral e um único Requisito Funcional.
**Impacto:** sem Personas, RNFs e PBTs, o `design-writer` não tem base para decidir modelagem de dados, tratamento de erro, timeouts, auditoria ou concorrência no validador embarcado — que é exatamente o tipo de decisão que a Validação (OBJ-01, latência < 300 ms) precisa suportar.
**Correção recomendada:** reescrever o documento seguindo o template oficial (ver seção "Checklist de Validação — 1. Estrutura Obrigatória" da especificação do `requirements-validator`), com pelo menos: Escopo, Personas (Passageiro, Validador/dispositivo embarcado, Operadora), RNFs de performance/disponibilidade/auditoria coerentes com OBJ-01 e OBJ-03 do PRD, PBTs para os invariantes de saldo/bloqueio, glossário local e fora de escopo.

### [BLOCKER-03] Requisito funcional sem os campos obrigatórios (Prioridade, Origem, Módulo)

**Local:** `Req 1 — Liberar embarque com saldo suficiente`.
**Problema:** o requisito tem user story e dois critérios de aceite, mas não tem a tabela `Prioridade | Origem | Módulo` nem `Cross-ref`. Sem "Origem", o requisito não é rastreável até o PRD (que teria sido `OBJ-01`) nem até nenhuma decisão de negócio.
**Impacto:** requisito sem origem rastreável é bloqueante por definição (ver seção "Requisitos Funcionais" da especificação); o `design-writer` não consegue justificar prioridade de implementação nem verificar se a exigência de latência é a mesma do PRD (300 ms, igual ao OBJ-01) ou uma coincidência de redação.
**Correção recomendada:** adicionar a tabela de campos ao Req 1 (Prioridade: Must; Origem: PRD Rota Única v2.1.0, OBJ-01; Módulo: validacao) e um Cross-ref para `ADR-0002-dinheiro-em-centavos` (saldo em centavos) e para o requisito de bloqueio de cartão da Carteira, se existir.

### [HIGH-01] README do módulo desatualizado em relação ao rascunho existente

**Local:** `docs/product/modules/validacao/README.md`.
**Problema:** o README mostra `requirements.md: Não iniciado`, mas já existe um rascunho de requirements (ainda que no caminho errado). Não há sincronização entre o que o time de embarcados escreveu e o artefato canônico do módulo.
**Impacto:** qualquer pessoa ou agente que consulte o README do módulo — inclusive o próprio `design-writer` antes de começar — vai concluir que não há requirements para o módulo Validação e pode tentar gerar do zero, divergindo do que o time de embarcados já produziu.
**Correção recomendada:** só atualizar o README depois que o requirements estiver no caminho oficial e revisado; não sincronizar o README com o conteúdo do caminho legado.

### [HIGH-02] Cobertura funcional incompleta frente ao README do módulo

**Local:** Requisitos Funcionais (apenas Req 1).
**Problema:** o README do módulo descreve a responsabilidade da Validação como decisão de embarque via **cartão NFC ou QR Code**, com débito na Carteira. O documento só cobre o caminho de saldo suficiente com NFC implícito; não há requisito para QR Code, para saldo insuficiente, para cartão sem sinal/timeout do validador, nem para o evento de auditoria do embarque.
**Impacto:** o `design-writer` desenharia o fluxo feliz e deixaria de fora casos de borda centrais ao domínio (recusa por saldo insuficiente, QR Code, indisponibilidade de rede do validador embarcado).
**Correção recomendada:** adicionar requisitos para: recusa por saldo insuficiente, leitura via QR Code, comportamento em falha de comunicação com a Carteira/backend, e evento auditável do embarque (aderente a `.forge/rules/testing/quality-gates.md`, que exige evento auditável para operações sensíveis).

### [MEDIUM-01] Histórico de versões não documenta o desvio de pipeline

**Local:** tabela "Histórico de Versões".
**Problema:** a entrada de 0.2.0 registra "Rascunho escrito fora do pipeline", o que é uma boa prática de transparência, mas não referencia o PRD por número de objetivo (`OBJ-01`) nem indica que o caminho usado foi `docs/specs/` em vez do oficial.
**Impacto:** menor — dificulta auditoria futura do motivo da divergência de caminho.
**Correção recomendada:** ao mover o conteúdo para o caminho oficial, adicionar uma nova entrada no histórico explicando a migração de `docs/specs/validacao/` para `docs/product/modules/validacao/`.

## Checks Executados

| Check | Resultado |
|-------|-----------|
| Tamanho até 2.000 linhas | OK (documento com ~25 linhas) |
| Estrutura obrigatória | Falhou |
| Metadados e versionamento | OK (versão SemVer, data ISO, status válido, histórico coerente) |
| Requisitos funcionais | Falhou |
| Requisitos não-funcionais | Falhou (seção ausente) |
| Critérios de aceite | OK para os dois critérios existentes (testáveis e atômicos) |
| PBTs | Falhou (seção ausente) |
| Glossário e linguagem | OK no texto existente; glossário local ausente |
| Separação requirements/design | OK (não há invasão de design técnico nos dois critérios existentes) |
| README sincronizado | Falhou |

## Recomendações para o requirements-writer

1. Mover o conteúdo de `docs/specs/validacao/requirements.md` para `docs/product/modules/validacao/requirements.md` e apagar a pasta `docs/specs/validacao/`, incluindo o `NOTA.md`.
2. Completar a estrutura obrigatória: Escopo, Personas/Atores, RNFs mensuráveis (latência, disponibilidade, auditoria), PBTs para os invariantes de saldo/bloqueio, glossário local e Fora do escopo do MVP.
3. Preencher Prioridade/Origem/Módulo/Cross-ref no Req 1 e adicionar os requisitos faltantes (QR Code, saldo insuficiente, falha de comunicação, evento auditável).

## Decisão para o Pipeline

- Pode seguir para `design.md`: Não
- Pode seguir para `tasks.md`: Não
- Requer nova execução do `requirements-writer`: Sim
