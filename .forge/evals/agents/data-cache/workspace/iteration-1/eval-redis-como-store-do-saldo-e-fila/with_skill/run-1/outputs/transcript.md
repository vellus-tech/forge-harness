# Transcript — eval redis-como-store-do-saldo-e-fila (with_skill, run-1)

## Contexto do caso

Prompt do usuário: "Quero tirar o saldo da carteira (services/carteira) do Postgres e deixar só no Redis, com AOF everysec e réplica, porque o débito na catraca precisa ser sub-milissegundo. E aproveitar o mesmo Redis como fila das validações das catracas com LPUSH/BRPOP. Me passa a configuração do Redis e o desenho das chaves para isso."

Papel assumido: agente `data-cache` (definição em `template/.forge/agents/data/data-cache.md`), com a skill `data-cache-practices` carregada (variante with_skill do eval).

## Passo 1 — Rules e decisões do projeto (protocolo, item 1)

Li, dentro da fixture (`work/`):
- `.forge/product/current/adr/ADR-0003-saldo-da-carteira-no-postgresql.md` — decisão aceita: saldo e extrato ficam no PostgreSQL do serviço carteira, débito transacional, cache (se houver) é cópia derivada e nunca decide débito.
- `.forge/rules/data/data-cache.md` — "Nunca fonte de verdade — todo dado em cache deve ser derivável/recuperável da fonte primária"; namespace de tenant obrigatório; TTL explícito; classes proibidas (segredo, PAN/CVV/track data, PII sem máscara).
- `.forge/rules/data/data-governance.md` — matriz de store: "Cache/performance, dado derivável e descartável → Redis/Memcache (nunca fonte de verdade)"; isolamento por tenant obrigatório por store.
- `services/carteira/README.md` — confirma que hoje o saldo está no PostgreSQL por força do ADR-0003.

## Passo 2 — Conflito relevante para (protocolo, item 2)

O pedido do usuário (mover o saldo para o Redis como store primário, com AOF everysec e réplica, para o Redis decidir o débito) diverge diretamente do ADR-0003 e das duas rules em decisão relevante: estratégia de persistência do dinheiro do passageiro. Isso é conflito bloqueante pela `conflict-handling.md` (citada no protocolo do agente) — não é divergência de estilo. Decisão: parar a recomendação da parte de armazenamento primário e devolver o bloco `CONFLITO`, sem entregar a configuração de Redis para o saldo.

## Passo 3 — Dado sensível (protocolo, item 3)

Comando executado:

```
cd work && bash .forge/scripts/check-data-governance.sh --path services/carteira
```

Saída:

```
OK data-governance/universo — 1 arquivo(s) examinado(s) (services/carteira)
OK data-governance (1 .md, 0 código, no divergence)
```

Interpretação: universo pequeno (só o README.md do serviço, sem código na fixture) — não há `data-classification.json` no projeto; nenhum `CONFLICT` nem `FAIL` emitido, então não há achado de PAN/PII bloqueante detectado por este verificador. Isso não substitui a checklist manual (T-01/T-04) feita na resposta.

## Passo 4 — Varredura (protocolo, item 4)

Comando executado:

```
bash template/.forge/skills/data-cache-practices/scripts/scan.sh --root work/services/carteira
```

Saída:

```
INFO data-cache-practices motor=rg raizes=1 universo=codigo iac
NADA-EXAMINADO — nenhum arquivo do universo da skill (codigo iac) sob as raízes; isto não é aprovação
ARQUIVOS-VARRIDOS 0
```

Exit 3 (NADA-EXAMINADO): a fixture não tem código, só o README do serviço. Conforme o protocolo, isso não é "limpo" — é ausência de universo examinável. Não há achado estático de antipattern nesta execução porque não há código a examinar; a avaliação do pedido em si (não do código existente) segue pelo catálogo `references/antipatterns.md` da skill.

## Passo 5 — Julgamento (protocolo, item 5)

Sem `FOUND` do scanner (nada examinado), o julgamento recai sobre o próprio pedido, comparado ao catálogo:
- **C-07 — Cache como fonte da verdade**: o pedido é exatamente esse padrão (Redis com AOF/réplica decidindo o débito). Catálogo: "o pedido que insiste em Redis como primário vira CONFLITO". Confirma a decisão do passo 2.
- **C-13 — Cache e estado durável na mesma instância com eviction**: usar a mesma instância de cache como fila (LPUSH/BRPOP) mistura estado durável (a fila) com dado descartável por eviction. Catálogo: "fila é do especialista de mensageria" — fora do escopo do `data-cache`.

## Passo 6 — Resposta

Escrevi a resposta final em `outputs/resposta.md`: bloco `CONFLITO` completo (decisão, posição A com ADR-0003 e as duas rules por caminho, posição B com o pedido, precedência, opções, registro), a recusa a entregar `appendonly`/`appendfsync everysec`/`save`/desenho de chave de saldo como solução, o encaminhamento da fila ao `data-streaming` citando C-13, o encaminhamento da escolha do store durável ao orquestrador/`data-engineer` (ou aos especialistas `data-relational`/`data-nosql`), e a parte que é do `data-cache`: cache de leitura do saldo com TTL curto, namespace `tenant:{id}:`, invalidação pós-commit, sem decidir débito.

Nenhum arquivo da fixture (`work/`) foi criado, editado ou removido — só leitura e os dois comandos permitidos pelo hook (`check-data-governance.sh`, `scan.sh`). Nenhum `approvals.yaml` nem ADR foi gravado; quem registra a decisão humana é a sessão principal, não este agente.

## Verificação final

```
cd work && git status --porcelain
```

Esperado (e checado no fechamento do run): saída vazia — árvore da fixture intacta.
