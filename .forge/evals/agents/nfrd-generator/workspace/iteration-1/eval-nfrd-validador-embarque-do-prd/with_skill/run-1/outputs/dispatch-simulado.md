# Despacho de subagente simulado (NÃO executado)

A especificação do `nfrd-generator` (§3 — Delegação a `adr-writer`) instrui: "você mesmo não cria o ADR" — apenas registra a sugestão para o orquestrador invocar `adr-writer` depois. Sob as regras desta execução ("se o artefato mandar spawnar subagentes, NÃO spawne: registre em outputs/ o despacho que faria"), este arquivo registra o despacho que o orquestrador faria a seguir, sem executá-lo.

## Despacho 1

- **Agente:** `adr-writer`
- **Modelo sugerido:** sonnet (execução de design de ADR único, não é ADR de agregado nem review crítico que justificasse opus)
- **Prompt resumido:** "Crie o ADR `estrategia-dr-backend-liquidacao` em `docs/product/adr/`, cobrindo RTO/RPO do backend de liquidação do Validador de Embarque Contactless. Origem: NFR-RES-02 do `docs/product/frd-nfrd/nfrd.md`. Contexto: queda de 6 h do backend em 2025 (notas de discovery) causou perda estimada de R$ 180 mil; SLA contratual de 99,5%/mês (R-04 do PRD) com multa. Severidade Alta — bloqueante para arquitetura antes da reunião com SRE/AppSec."

## Despacho 2

- **Agente:** `adr-writer`
- **Modelo sugerido:** sonnet
- **Prompt resumido:** "Crie o ADR `padrao-idempotencia-envio-lotes` em `docs/product/adr/`, definindo o mecanismo de idempotência para reenvio de lotes de validação após reconexão offline (até 72 h) e para submissão de cobrança à adquirente. Origem: NFR-INT-01 do `docs/product/frd-nfrd/nfrd.md`. Severidade Alta — risco de cobrança/crédito duplicado."

## Despacho 3

- **Agente:** `adr-writer`
- **Modelo sugerido:** sonnet
- **Prompt resumido:** "Crie o ADR `padrao-trilha-auditoria-imutavel` em `docs/product/adr/`, definindo o padrão de trilha append-only aplicável à lista de restrição (e potencialmente a outras entidades sensíveis). Origem: NFR-AUD-01 do `docs/product/frd-nfrd/nfrd.md`. Severidade Média — antes do release, não bloqueante para a reunião de arquitetura."

## Despacho 4 (validação, não delegação da §3)

- **Agente:** `frd-nfrd-validator` (citado no diretório de specifications como par natural do `nfrd-generator`)
- **Modelo sugerido:** sonnet
- **Prompt resumido:** "Valide `docs/product/frd-nfrd/nfrd.md` contra `docs/product/prd/prd.md`: confira cobertura de todas as 14 categorias, rastreabilidade completa PRD→NFRD, ausência de meta não verificável e ausência de requisito funcional disfarçado de NFR."

Nenhum destes despachos foi executado nesta run — apenas registrado, conforme mandato.
