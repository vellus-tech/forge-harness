# Transcript — eval revisao-cache-cobranca-java-cpf-na-chave / with_skill / run-1

## Bootstrap do harness (workflow orquestrador)
1. `cd .../worktrees/evals-100 && pwd && git branch --show-current` → confirmado `evals-100` / `chore/evals-skills-agentes`, conforme esperado.
2. `date +%s > .../run-1/.t0` — instante inicial gravado.
3. `mkdir -p .../run-1/work` e `bash .../fixtures/revisao-cache-cobranca-java-cpf-na-chave/setup.sh .../run-1/work` — fixture materializada: repositório git com `.forge/`, `CLAUDE.md`, `docs/servicos/cobranca.md` e `services/cobranca/src/main/java/br/com/exemplo/cobranca/CobrancaCache.java`.

## Papel assumido
Agente `data-cache` (`.forge/agents/data/data-cache.md` do template, lido em `template/.forge/` conforme instruído) — especialista consultivo, sem `Write`/`Edit`/`Agent`; devolve recomendação em texto.

## Passos do protocolo (`data-cache.md`, ordem fixa)

1. **Rules e decisões do projeto.** Li, dentro de `work/.forge/rules/`: `data/data-cache.md`, `data/data-governance.md`, `architecture/pii-pci-classification.md`. Não há ADRs no baseline (`product/current/adr/` só tem `.gitkeep`) e não há `data-classification.schema.json` no projeto.
2. **Conflito relevante.** Nenhum conflito entre skill e rule/ADR do projeto — a skill deriva diretamente da `data-cache.md`/`data-governance.md` deste projeto, sem divergência. Não houve necessidade do bloco `CONFLITO`.
3. **Dado sensível.**
   ```
   bash .forge/scripts/check-data-governance.sh --path services/cobranca
   ```
   Resultado: `FAIL data-governance/universo-vazio — 0 arquivo(s) examinado(s)`. Interpretação pela linha (conforme o protocolo do agente): o verificador só lê `.go/.kt/.ts/.rego/.py/.md`, e o projeto é Java — "não verificado por ele", não "aprovado" e não "conflito". Fiquei com o detector da skill e a revisão manual para a parte de PII/PAN.
4. **Varredura.**
   ```
   bash .forge/skills/data-cache-practices/scripts/scan.sh --root services/cobranca
   ```
   (script lido de `template/.forge/skills/data-cache-practices/scripts/scan.sh`, já que a cópia em `work/.forge/skills/` veio vazia no fixture — usei a fonte do template conforme autorizado pela tarefa, mesma versão que o agente referenciaria em produção.)
   Resultado: `FOUND C-02` (linha 22, set sem TTL), `FOUND C-08` (linha 11, Caffeine sem expiração); `OK` para C-09, C-10, C-11, C-15, C-16, C-17. `ARQUIVOS-VARRIDOS 1`.
5. **Julgamento.** Li `CobrancaCache.java` linha a linha e cruzei com `references/antipatterns.md` (lido de `template/.forge/skills/data-cache-practices/references/`):
   - C-02 e C-08 confirmados como achados reais (não falso-positivo) — não há `EXPIRE`/`Duration` em linha adjacente, nem `expireAfterWrite` no builder Caffeine.
   - Identifiquei um achado que o scanner não cobre (não é estático, chave é montada em runtime): CPF em texto claro na chave (`"tenant:" + tenant + ":titular:" + cpf"`, linha 21) — mapeado para **T-04** do catálogo (chave com dado pessoal exposta a SLOWLOG/MONITOR/APM/SIEM).
   - Levantei um risco de LGPD adicional sobre o valor cacheado (PII sem mascaramento no `Titular` serializado) — sinalizado como "não verificado por ferramenta" porque `Titular.java` está fora do path revisado e o gate de governança não rodou sobre Java.
   - Levantei uma pergunta de desenho que preciso ter confirmada (C-07 / C-01): `guardarTitular` não escreve em PostgreSQL neste arquivo — não dá para confirmar pela revisão isolada se este método é chamado depois do commit na origem (correto) ou se é o único ponto de escrita do titular (viraria `CONFLITO` com a `data-governance.md`, cache como fonte da verdade). Não resolvo isso sozinho: registrei como pergunta de confirmação em vez de aprovar ou reprovar às cegas.
   - Confirmei que o namespace multi-tenant (`tenant:{id}:...`) está presente e correto — não é achado.
6. **Resposta.** Escrita em `outputs/recomendacao.md`, com marca de evidência, id do catálogo, `arquivo:linha` para os achados do scanner, e separação entre achados fechados e ponto a confirmar. Não consultei o context7 porque não há afirmação de versão/default de produto (Caffeine/Redis) na recomendação que dependesse disso — os achados são de padrão de uso, não de versão de API.

## Decisões de escopo desta execução (regras do prompt computado)
- Não rodei `git commit`/`push`/`checkout`/`stash`, `npm test`, `docker`, `ledger-ops.sh`, `liaison-ops.sh` nem `gh` de escrita.
- Não spawnei subagentes (o protocolo do agente não pede — é execução direta de um especialista consultivo).
- Escrevi apenas dentro do diretório de trabalho designado (`run-1/work` para a fixture, `run-1/outputs` para os entregáveis).
- Nenhum segredo literal foi usado ou registrado.

## Entregáveis
- `outputs/recomendacao.md` — resposta ao usuário (revisão de LGPD e consistência do `CobrancaCache`).
- `outputs/transcript.md` — este arquivo.
