# Registro de despacho (simulado — subagentes não spawnados)

O artefato do agente `adr-writer` (`template/.forge/agents/architecture/adr-writer.md`) não
instrui o spawn de subagentes — é um agente de execução direta (Read/Write/Edit/Glob/Grep,
model: opus). Nenhum despacho real ou simulado foi necessário para completar esta tarefa: toda
a análise (checklist de numeração, completude, qualidade, referências) e a escrita do ADR foram
feitas nesta própria run, seguindo o agente à risca.

Se a tarefa exigisse investigação paralela (ex.: sondar múltiplos módulos para achar decisões
correlatas ao ADR-0102 em outros repositórios), o despacho que eu faria seria:

- **Agente:** `general-purpose` (ou um subagente de busca dedicado)
- **Modelo:** `haiku` (busca bite-sized, escopo claro — grep por referências a ADR-0102 fora de
  `docs/product/adr/`)
- **Prompt resumido:** "Busque referências ao ADR-0102 (antifraude síncrono) em código e docs
  fora de docs/product/adr/, e reporte caminho + linha de cada ocorrência."

Não executado nesta run porque não foi necessário — não há referências ao ADR-0102 fora do
diretório de ADRs neste fixture.
