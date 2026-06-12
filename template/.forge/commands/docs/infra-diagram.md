---
description: Gera um scaffold de diagrama de infraestrutura como código (mingrammer/diagrams) a partir do docker-compose detectado — ícones reais (Kong/Istio/Postgres/Redis/…), clusters por tipo. Scaffold para refino humano (rede/PCI não vêm do compose). Requer graphviz + pip install diagrams para renderizar.
argument-hint: "[--out <dir>]"
---

# /forge:infra-diagram — diagram-as-code da infraestrutura

Argumentos: `$ARGUMENTS` (`--out <dir>`, default `docs/diagrams`).

## Protocolo

1. Gere o scaffold a partir do compose:
   ```bash
   bash .forge/scripts/infra-scan.sh --out docs/diagrams
   ```
   Cria `docs/diagrams/infra.py` com os serviços do compose classificados por ícone
   (gateway/serviço/dados/observabilidade) e arestas iniciais.

2. **Refine à mão** — o compose não tem topologia de rede, zonas de confiança nem escopo de
   compliance. Ajuste arestas, adicione `Cluster`s de zona (DMZ/CDE/interno) e rótulos.

3. Renderize (requer `graphviz` + `pip install diagrams`):
   ```bash
   cd docs/diagrams && python3 infra.py     # gera infra.png
   ```

## Para PCI DSS

Use o mesmo approach para os diagramas exigidos: **Req 1.2.3** (rede + segmentação do CDE) e
**Req 1.2.4** (fluxo de dados de conta). Esses são modelos escritos à mão (o escopo do CDE é
decisão do QSA) — versione os `.py` para revisar o diff em PR.

## Regras

- O scaffold é ponto de partida, não verdade final: rede/PCI exigem refino humano.
- Versione os `.py` (não os `.png`) — o diff fica revisável.
