# Resposta que seria dada ao usuário (simulação, eval with_skill)

Gerei o mapa C4 do pagamentos-core a partir do grafo de código (determinístico, sem
reler o repositório inteiro). Está tudo em `.forge/graph/`:

- `.forge/graph/overview.html` — abra este arquivo no navegador para navegar entre
  Contexto (C1), Containers (C2) e Componentes (C3) dos quatro módulos
  (billing, ledger, notifications, shared).
- `.forge/graph/c4/c1-context.md` — visão de contexto do sistema.
- `.forge/graph/c4/c2-container.md` — os quatro containers (um por módulo em `src/`),
  coloridos pela camada dominante, com a dependência billing/ledger → shared.
- `.forge/graph/c4/c3-component-*.md` — um diagrama de componentes por módulo
  (billing, ledger, notifications, shared), mostrando os arquivos internos e as
  dependências entre eles (incluindo a saída externa `src/shared: money ts`).

Para a reunião de quinta com a adquirência, o `overview.html` é o mais prático: dá
para clicar e trocar de nível (contexto → container → componente) sem precisar
colar Mermaid em lugar nenhum.

Observação de curadoria: o grafo ainda não tem atores externos reais (ex.: o
adquirente, o gateway de pagamento) nem system boundary explícito — isso é
curadoria humana sobre os `.mmd`/`.md` gerados, não algo que o gerador inventa
sozinho. Se quiser, dá para eu adicionar esses atores manualmente antes da
reunião, respeitando a convenção de labels (sem pontos, sem em-dash).
