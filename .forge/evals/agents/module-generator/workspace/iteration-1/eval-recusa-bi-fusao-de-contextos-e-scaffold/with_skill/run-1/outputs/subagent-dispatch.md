# Despacho de subagentes (simulado — não executado)

O harness deste run proíbe spawnar subagentes de verdade ("NÃO spawne: registre em outputs/ o
despacho que faria"). Registro abaixo o que despacharia se este módulo estivesse rodando dentro
do fluxo real do Forge, para as três partes fora do escopo do `module-generator`:

## 1. Reabertura do DDD para avaliar a fusão Recarga + Tarifação em "Financeiro"

- Agente: `ddd-architect` (ou `ddd-validator` em modo de reavaliação)
- Modelo: `opus` (effort medium) — decisão de agregados/bounded contexts é design de arquitetura,
  não implementação bite-sized.
- Prompt resumido: "O Rafael propõe fundir os bounded contexts Recarga e Tarifação em um único
  contexto 'Financeiro'. O DDD Validation Report de 2026-09-10 aprovou os cinco contextos atuais
  sem fusão pendente. Avalie a proposta contra o Context Map (Tarifação → Validação é Shared
  Kernel; Recarga tem Anticorruption Layer própria com a adquirente) e emita um novo DDD
  Validation Report ou registre a rejeição com justificativa."

## 2. Especificação do módulo relatorios-bi

- Agente: `ddd-architect` seguido de `requirements-writer`
- Modelo: `sonnet` — trabalho de especificação de um módulo/onda inteira.
- Prompt resumido: "A diretoria pediu um dashboard de receita (relatorios-bi), sem subdomínio,
  bounded context, evento ou deployable candidato no DDD atual. Determine se é um novo
  subdomínio/contexto (ex.: 'Relatórios' ou 'BI'), sua fonte de dados (provavelmente os eventos
  EmbarqueValidado e LoteLiquidacaoFechado, via read model), ownership e requisitos de compliance
  (se tocar dados de recarga/tarifação). Produza a entrada no DDD Segmentation antes de o
  module-generator gerar o README do módulo."

## 3. Scaffold dos serviços Go e docker build

- Agente: `task-coder` (via `/forge:coding-loop`), por módulo (`services/<modulo>/`)
- Modelo: `haiku` para o scaffold bite-sized (go.mod, main.go, Dockerfile) de cada módulo já
  confirmado; o orquestrador roda o `docker build` de cada imagem via `run_in_background`
  (nunca o subagente, por trava operacional de watchdog).
- Prompt resumido (por módulo): "Gere o esqueleto Go do serviço `<modulo>` em
  `services/<modulo>/` com go.mod (module github.com/tarifa-viva/<modulo>), main.go mínimo e
  Dockerfile multi-stage, alinhado ao TRD (Go, gRPC interno, REST externo). Não rode build; o
  orquestrador builda em background."
- Pré-condição: só despachar após os READMEs de módulo estarem aprovados por humano (gate do
  `/forge:tasks`), o que ainda não ocorreu nesta rodada.

Nenhum destes despachos foi executado. Esta rodada produziu apenas a documentação de módulos
dentro do escopo do `module-generator` (item que segue à parte deste arquivo).
