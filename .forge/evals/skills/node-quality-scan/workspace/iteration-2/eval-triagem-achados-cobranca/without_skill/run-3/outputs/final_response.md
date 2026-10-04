Triagem feita e salva em `<RUN>/outputs/triagem-cobranca.md`. Nenhum código foi alterado.

Só um achado é defeito de verdade e bloqueia o release: a query de `marcarPaga` em `src/infra/PgCobrancaRepository.ts` interpola o `id` na SQL (`WHERE id = '${id}'`). O `id` vem de `req.params.id` numa rota sem autenticação, então é SQL injection explorável. A correção é usar `$1` com `[id]`, que já é o padrão do `buscar` no mesmo arquivo. No mesmo método, vale tratar também o `rowCount` zero, que hoje responde 204 mesmo sem linha atualizada, e checar `status = 'aberta'`, para não pagar cobrança cancelada.

Os outros quatro achados podem ficar como estão. O pool do pg é um singleton correto, com ressalva de falta de listener de erro. O `readFileSync` acontece uma vez no boot, com falha rápida; o que merece ajuste é o `as never` e o fallback de `TLS_CERT_PATH` para o certificado de dev, que é defeito de configuração de severidade média. A interface `CobrancaRepository` é a porta do domínio e tem duas implementações, a Pg e o fake de teste, embora o fake não esteja em uso. O `.then` em `lembrete.ts` não é defeito de execução, mas a função chamada `agendarLembrete` executa na hora e loga "lembrete enviado" sem enviar nada, e não encontrei chamador.

Achado fora do scan: `buscar` devolve `valor_centavos` enquanto o tipo `Cobranca` declara `valorCentavos`, então o `GET /cobrancas/:id` entrega um contrato diferente do declarado. Recomendo corrigir com alias na consulta, antes de sexta.

Não rodei typecheck nem testes, porque não há `node_modules` e a rodada não tem rede. As conclusões são de leitura do código e precisam de confirmação com teste de regressão antes da correção.
