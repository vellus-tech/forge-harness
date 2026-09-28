# TASK-03 — Formulário de recarga do cartão

## O que foi entregue

Formulário de recarga em `apps/web/portal-passageiro/src/features/recharge/RechargeForm.tsx`, consumindo `POST /v1/recargas` conforme `contracts/recargas.openapi.yaml`, com os arquivos:

- `src/features/recharge/RechargeForm.tsx` — componente do formulário.
- `src/features/recharge/RechargeForm.module.css` — estilos, usando os tokens de `@bilhetagem/ui`.
- `src/features/recharge/RechargeForm.test.tsx` — testes com Testing Library cobrindo os cinco requisitos.
- `src/services/rechargeService.ts` — chamada HTTP à API de recargas, reaproveitando o `httpClient` já existente.
- `src/lib/uuid.ts` — geração de `Idempotency-Key`, com fallback para ambientes sem `crypto.randomUUID`.

## Cobertura dos requisitos

- **REQ-RC-01**: botões de valor rápido (R$ 10, R$ 20, R$ 50) usando o `Button` de `@bilhetagem/ui`, mais um campo de outro valor aceitando de R$ 5,00 a R$ 500,00.
- **REQ-RC-02**: validação com Zod (`react-hook-form` + `zodResolver`) barra valores fora da faixa no próprio campo, sem disparar a mutation/API.
- **REQ-RC-03**: erro 422 da API (`LIMITE_DIARIO_EXCEDIDO`, `CARTAO_BLOQUEADO`) é capturado via `HttpError` e a `message` é exibida em `role="alert"`; como o formulário não é resetado no erro, o valor digitado permanece no campo.
- **REQ-RC-04**: o botão de envio fica `disabled`/`aria-busy` enquanto a mutation (`@tanstack/react-query`) está pendente, e a `Idempotency-Key` é fixa por tentativa (só é regenerada após sucesso), então clique duplicado no botão desabilitado não gera nova chamada.
- **REQ-RC-05**: em caso de 201, a tela troca para uma confirmação mostrando o `status` retornado (`CONFIRMED` → "Confirmada", `PENDING_PAYMENT` → "Pagamento pendente"), com opção de iniciar uma nova recarga.

## Decisões e trade-offs

- **react-hook-form + zod**: já eram dependências do `package.json` do portal, então segui o padrão em vez de introduzir uma lib de validação nova.
- **Seleção de valor rápido vs. outro valor são mutuamente exclusivas**: escolher um valor rápido limpa o campo de outro valor e vice-versa, evitando ambiguidade sobre qual valor é enviado. Alternativa descartada: permitir os dois preenchidos e priorizar um — mais confuso para o usuário e mais difícil de testar.
- **Idempotency-Key gerada no cliente por tentativa**: alinhado ao contrato (header obrigatório). Ela só é trocada após sucesso; erros de negócio (422) mantêm a mesma chave para a "nova tentativa" ser, na prática, a mesma tentativa até o usuário mudar o valor e reenviar. Não tratei explicitamente o caso 409 (chave já usada com payload diferente) com uma mensagem dedicada — cai no fallback genérico de erro. Isso é um ponto que merece revisão se o produto quiser uma mensagem específica para colisão de idempotência.
- **Erros de rede/genéricos**: qualquer falha que não seja `HttpError` 422 cai numa mensagem genérica ("Não foi possível concluir a recarga. Tente novamente."), já que a API só documenta 201/409/422.

## O que não foi feito

- Não rodei `pnpm install` / `vitest run` neste ambiente (execução de testes e instalação de dependências estavam fora do escopo autorizado desta entrega). Os testes foram escritos seguindo exatamente os padrões já usados em `HistoryPage.test.tsx` (mesma forma de `QueryClientProvider`, `vi.spyOn` no módulo de serviço), então a expectativa é que rodem sem ajuste, mas isso não foi verificado por execução real — fica como pendência de verificação antes do merge.
- Não marquei o checkbox de TASK-03 em `docs/product/modules/recarga/tasks.md` — deixei essa atualização de tracker para quem fizer a integração/checkpoint formal do módulo.
