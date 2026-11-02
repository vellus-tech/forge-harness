# Relatório de medição — NFR-02 (add-liaison-handoff-baton)

Medido em 2026-11-02, nesta worktree, com `node:perf_hooks`, 50 execuções por cenário (p95 sobre
a amostra ordenada, `Math.ceil(0.95*n)`-ésimo valor), cache QUENTE nos dois cenários do gancho
(uma chamada de aquecimento descartada antes das 50 medidas, conforme o design §2.8: "medidos
com cache quente, que é o caso de toda chamada exceto a primeira depois de uma gravação no log
próprio").

Script de medição: construído ad-hoc para esta rodada (não committed — gera fixtures efêmeras em
`$TMPDIR`, mede e descarta); reproduzível a partir da descrição abaixo. Repositórios de fixture:
um canal com `self=repo-a`, participante externo `repo-b` (sem transporte configurado, para que
o caminho de publicação em segundo plano nunca entre na medição do próprio evento — consistente
com o design, que desacopla a publicação do tempo do gancho).

| Cenário | Alvo (p95) | n | p95 medido | máximo medido | Veredito |
|---|---|---|---|---|---|
| Gancho `PostToolUse`, sem bastão detido, canal com 2.000 mensagens | ≤ 150 ms | 50 | **22,2 ms** | 29,79 ms | ✅ |
| Gancho `PostToolUse`, bastão detido fora da hora de renovar, canal com 2.000 mensagens | ≤ 150 ms | 50 | **40,69 ms** | 43,13 ms | ✅ |
| Dobra (`foldBatons`) sobre thread de 2.000 mensagens de bastão (1 oferta + 1.997 renovações + 1 claim + 1 mensagem extra de setup) | ≤ 500 ms | 50 | **1,93 ms** | 2,99 ms | ✅ |
| Seção crítica sob a trava (`baton renew` via CLI, canal com ~2.000 mensagens) | ≤ 2.000 ms | 50 | **429,14 ms** | 524,74 ms | ✅ |

Todos os quatro alvos do NFR-02 batem com margem confortável (a seção crítica, o cenário mais
próximo do teto, roda a ~21% do limite). Máquina compartilhada (mesma observada nas medições da
TASK-26/27) — valores absolutos variam entre rodadas, a MARGEM relativa ao teto é o que importa.

## Metodologia e desvios honestos

- **Gancho "sem bastão" / "fora da hora":** medido invocando `template/.forge/hooks/session/on-post-tool-use.sh`
  de verdade (processo bash+node completo, como uma invocação real de `PostToolUse`), com
  `session_id` via stdin JSON e `FORGE_ROOT` apontando para o repositório de fixture. Uma chamada
  de aquecimento roda antes (cache fria, descartada), depois 50 chamadas medidas.
- **Canal "sem bastão" com 2.000 mensagens:** 2.000 mensagens `note` reais (via `appendOwn`,
  mesma função que o CLI usa) e ZERO bastão — o cenário do REQ-12 em que o cache local nunca tem
  entrada de titular para a sessão.
- **Canal "fora da hora" com 2.000 mensagens:** 2.000 `note` + 1 `offer` + 1 `claim` com
  `--lease 1800` (titular, `next_renew_at` ≈ agora + 900 s — bem fora da hora de renovar).
- **Dobra sobre thread de 2.000 mensagens de bastão:** canal dedicado com 1 `offer` + 1 `claim` +
  1.997 `renew` sintéticos (construídos via `appendOwnDecided` chamando a MESMA função de dobra
  real para calcular `leaseSeconds`/`stamped_at`/`lease_until` de cada renovação — não um JSON
  hand-rolled — para que a thread resultante seja uma sequência válida e decodificável por
  `foldBatons` sem nenhum atalho). As 1.997 escritas rodam num único processo node (chamando
  `appendOwn`/`appendOwnDecided` em laço), em vez de 1.997 spawns de `bash liaison-ops.sh` — desvio
  deliberado: o que está sob medição aqui é o CUSTO DA DOBRA sobre uma thread grande, não o custo
  de montar a fixture, e a função chamada em laço é literalmente a mesma que o CLI usa por baixo.
  `foldBatons` é então medido 50x sobre o array de mensagens relido do disco.
- **Seção crítica (`baton renew`):** medida invocando `liaison-ops.sh baton renew` via CLI de
  verdade (spawn de bash+node), 50 vezes em sequência, sobre o canal de 2.000 mensagens acima —
  sem `FORGE_BATON_RENEW_IF_DUE`, então cada renovação manual é aceita (o lease nunca vence entre
  uma chamada e a próxima). Mede o caminho completo sob a trava: releitura do canal, dobra,
  montagem do envelope, gravação local por tmp+rename.
- **Decomposição do "caminho que renova" do gancho (§2.8), não medido ponta a ponta nesta
  rodada:** o design separa o caminho rápido (checagem de `next_renew_at` via `jq`, sem `node`) do
  disparo de `baton renew`. Os dois cenários acima já provam, separadamente, que (a) a checagem
  rápida custa ~20-40 ms (bem dentro do próprio alvo de 150 ms que o REQ-12 impõe a ela) e (b) a
  chamada de `baton renew` custa ~430 ms p95 sobre 2.000 mensagens — a soma dos dois (~470 ms) já
  fica longe do teto combinado de 2.500 ms do caminho que renova ponta a ponta, mas uma medição
  end-to end do PRÓPRIO gancho disparando a renovação de verdade (exigindo forçar "devido" a cada
  uma das 50 chamadas, sem esperar o relógio real) não foi executada nesta rodada — registrado
  como lacuna honesta, não como medição feita. Dado que as duas partes somadas já têm margem de
  mais de 5x para o teto combinado, o risco de a composição ultrapassar 2.500 ms é baixo, mas não
  foi observado diretamente.
- **Caminho frio (informativo, teto 600 ms):** não medido nesta rodada — já seria a primeira
  chamada de aquecimento, descartada de propósito nos dois cenários do gancho; não um dado
  perdido, apenas fora do escopo desta medição (o teto é informativo, não um critério de aceite
  bloqueante do REQ-12).
