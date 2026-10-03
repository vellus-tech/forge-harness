# Relatório — TASK-04: recarga avulsa ponta a ponta

## Resumo do que foi alterado

Implementado o `POST /recargas` (recarga avulsa) ponta a ponta: contrato OpenAPI primeiro
(DD-004), migration de idempotência, rota + repositório com validação de faixa e idempotência
por constraint de banco (REQ-02, REQ-03, DD-001, DD-002), e o formulário `NovaRecargaForm` no
portal usando o client tipado existente (DD-003), com estados de envio, erro e sucesso
acessíveis (REQ-04). Tracker `docs/product/modules/recargas/tasks.md` atualizado para `[X]`.

## Arquivos alterados

- `contracts/openapi/api-recarga.yaml` — novo path `POST /recargas` (header `Idempotency-Key`
  obrigatório, corpo `{ cartaoId, valorCentavos }`, respostas 201/200/400), versão bump para
  1.3.0.
- `services/api-recarga/migrations/002_add_idempotency_key.sql` — nova coluna
  `idempotency_key UUID` + `UNIQUE` constraint em `recargas` (nullable para não quebrar linhas
  históricas; toda recarga nova passa a exigi-la na camada de aplicação).
- `services/api-recarga/src/recargas/repository.ts` — `RecargaRepository.create()`: `INSERT ...
  ON CONFLICT (idempotency_key) DO NOTHING RETURNING ...`; se zero linhas voltarem, `SELECT` pela
  mesma chave. Unicidade resolvida inteiramente pelo banco, sem checagem em memória (DD-002).
- `services/api-recarga/src/recargas/routes.ts` — `POST /recargas`: guarda cedo por header
  ausente (`MISSING_IDEMPOTENCY_KEY`), depois por corpo fora da faixa (`INVALID_BODY`), faixa
  100–50000 centavos como constantes nomeadas; `201` quando `created`, `200` quando idempotente.
- `services/api-recarga/src/recargas/routes.test.ts` — testes acrescentados: header ausente,
  valor abaixo/acima da faixa, criação (201) e reenvio idempotente (200, REQ-03), preservando o
  teste pré-existente do GET.
- `apps/web/portal-recarga/src/api/client.ts` — `criarRecarga(cartaoId, valorCentavos,
  idempotencyKey)`, único ponto de chamada HTTP para a criação (DD-003).
- `apps/web/portal-recarga/src/components/NovaRecargaForm.tsx` — novo componente: parsing de
  valor em reais (vírgula ou ponto) para centavos, validação de faixa antes de chamar a API,
  UUID de idempotência gerado uma vez por tentativa e preservado entre reenvios da mesma
  solicitação (`useRef`, renovado só após sucesso), estados `idle/submitting/error/success`,
  input e botão desabilitados durante o envio, erro em `role="alert"` associado via
  `aria-describedby`, sucesso em `role="status"`.
- `apps/web/portal-recarga/src/components/NovaRecargaForm.test.tsx` — testes acrescentados
  (ver seção seguinte).
- `docs/product/modules/recargas/tasks.md` — TASK-04 marcada `[X]`.

## Testes executados

Nenhum. O ambiente deste run é um eval isolado cujas regras operacionais proíbem explicitamente
a execução de suíte de testes (`npm test`, `run-all.sh`) e qualquer build/instalação de
dependências — logo nada foi rodado de fato, por restrição do harness, não por omissão da
disciplina de TDD. O código foi escrito seguindo o ciclo vermelho→verde mentalmente (teste
descrito antes da implementação correspondente), mas isso não substitui execução real.

## Testes recomendados

Backend (`services/api-recarga`, `npm test` → Vitest):
- `routes.test.ts` completo, incluindo os 5 novos casos de `POST /recargas`.
- Um teste de integração real contra Postgres (não coberto aqui, pois o repositório é mockado
  nos testes de rota) validando que dois `INSERT` concorrentes com a mesma `idempotency_key`
  resultam em uma única linha — a garantia de fato depende do `ON CONFLICT` rodando contra um
  banco real, não apenas do mock.

Frontend (`apps/web/portal-recarga`, `npm test` → Vitest + Testing Library):
- `NovaRecargaForm.test.tsx` completo, incluindo o caso de reenvio com a mesma
  `Idempotency-Key`.
- Teste de acessibilidade adicional (ex.: `jest-axe`/`vitest-axe`, se o projeto adotar) não foi
  adicionado por não haver essa dependência already instalada — ver Pendências.

## Riscos conhecidos

- **Gap pré-existente de configuração do frontend:** `apps/web/portal-recarga` não tem
  `tsconfig.json` nem `vite.config.ts`/`vitest.config.ts` no fixture (confirmado antes desta
  mudança — `HistoricoRecargas.tsx` já não tinha teste correspondente). Isso significa que o
  script `"lint": "tsc --noEmit"` do pacote não tem projeto TypeScript configurado, e o ambiente
  de teste (`jsdom`) do novo `NovaRecargaForm.test.tsx` depende só da diretiva
  `// @vitest-environment jsdom` no topo do arquivo — funciona por arquivo, mas não é o ideal
  para o pacote inteiro. Não corrigi isso por estar fora do escopo direto da TASK-04 (afeta o
  app inteiro, não só a feature); registro aqui em vez de expandir a mudança.
- `crypto.randomUUID()` é usado tanto no client quanto no formulário: presume Node 19+/browsers
  modernos. Se o projeto precisar suportar runtime mais antigo, precisa de polyfill — não
  verificado aqui por falta de `engines` declarado em `package.json`.
- A migration 002 deixa `idempotency_key` nullable para não quebrar linhas históricas da
  migration 001; se o projeto tiver processo de backfill/NOT NULL futuro, é uma migration
  adicional, não coberta aqui (fora do escopo da TASK).

## Pendências

- Rodar `npm test` em `services/api-recarga` e em `apps/web/portal-recarga` (não executados
  nesta sessão — ver "Testes executados").
- Rodar `npm run lint` (`tsc --noEmit`) nos dois pacotes; o do frontend pode expor a ausência de
  `tsconfig.json` mencionada em Riscos.
- Decidir se o gap de `tsconfig.json`/config de teste do `apps/web/portal-recarga` vira uma TASK
  própria (é pré-existente, não introduzido por esta mudança).
- Aplicar a migration 002 num Postgres real e confirmar o comportamento de concorrência do
  `ON CONFLICT` sob carga (não simulável apenas com o repositório mockado nos testes).
