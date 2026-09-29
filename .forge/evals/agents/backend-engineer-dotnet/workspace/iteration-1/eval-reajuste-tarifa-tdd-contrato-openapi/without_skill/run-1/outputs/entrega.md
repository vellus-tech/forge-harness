# Entrega — TASK-03: Reajuste de tarifa por percentual

## O que foi feito

Implementado o reajuste de tarifa por percentual no `tarifa-service`, cobrindo REQ-004, DD-001 e
DD-002 do módulo tarifa, seguindo TDD (Red → Green):

1. **Domain** (`TarifaLinha.Reajustar(int percentualBp)`): calcula o novo valor em centavos a
   partir do valor atual e do percentual em pontos-base (1 bp = 0,01%), usando aritmética inteira
   (`long numerador = valorCentavos * (10000 + percentualBp)`, dividido por 10000) e arredondando
   uma única vez, no final, pelo critério half-even (bancário). Rejeita percentuais fora da faixa
   1–5000 bp com `ArgumentOutOfRangeException`.
2. **Application** (`ReajustarTarifaHandler`): busca a linha no repositório, valida a faixa do
   percentual antes de tocar o agregado (para responder 422 sem depender do fluxo de exceção do
   Domain), aplica o reajuste e persiste. Retorna um resultado tipado (`Sucesso`,
   `LinhaNaoEncontrada`, `PercentualInvalido`) para o endpoint mapear no HTTP.
3. **Api** (`POST /v1/tarifas/{linhaId}/reajustes`): recebe `{ "percentualBp": int }`, responde
   `200` com `{ "linhaId", "valorAnteriorCentavos", "valorNovoCentavos" }`, `404` (ProblemDetails)
   se a linha não existir e `422` (ProblemDetails) se o percentual estiver fora da faixa.
4. **Contrato** (`contracts/openapi/tarifa-service.yaml`): endpoint novo documentado com os
   schemas `ReajusteRequest` e `ReajusteResponse`, versão bumped para `0.2.0` — é a partir deste
   arquivo que o time de bilhetagem gera o client.
5. **Docs**: `CHANGELOG.md` do serviço atualizado; `docs/product/modules/tarifa/tasks.md` com
   TASK-03 marcada `[X]`.

## Decisões e trade-offs

- **Half-even só na etapa final, sobre inteiros.** A alternativa óbvia seria usar `decimal` para o
  cálculo intermediário — mas DD-001 proíbe ponto flutuante/decimal guardando ou calculando
  dinheiro em Domain. A divisão `numerador / 10000` com verificação manual de resto (`resto * 2`
  comparado ao denominador, com desempate para o quociente par) reproduz o comportamento de
  `MidpointRounding.ToEven` inteiramente em `long`, sem intermediários fracionários.
- **Validação de faixa duplicada (Application + Domain).** O Domain valida e lança exceção (é a
  fonte de verdade, cobre qualquer chamador futuro); a Application repete a mesma checagem antes
  de invocar `Reajustar`, para poder responder 422 via um resultado tipado em vez de capturar
  exceção do Domain como controle de fluxo HTTP. É uma pequena duplicação deliberada — a
  alternativa (capturar `ArgumentOutOfRangeException` na API) acopla o contrato HTTP ao tipo de
  exceção interna do Domain.
- **Não critiquei `TarifaLinha.Reajustar` retornando uma tupla** em vez de void + leitura de
  `ValorCentavos` depois, porque o teste Red pede explicitamente a tarifa anterior *e* a nova no
  mesmo retorno (é o que o handler e a resposta HTTP precisam), e retornar as duas evita uma
  segunda leitura de estado mutável logo após a chamada.

## Como validar

```
cd services/tarifa-service
dotnet build   # Compilação com êxito, 0 erro(s)
dotnet test    # 8 testes aprovados, 0 com falha
```

Os 3 exemplos do `tasks.md` estão cobertos em
`tests/Tarifa.UnitTests/TarifaLinhaTests.cs`:

- 430 centavos, 1250 bp → 483,75 → **484** (arredonda para cima).
- 420 centavos, 1250 bp → 472,50 → **472** (empate, half-even para o par).
- 5001 bp → rejeitado com `ArgumentOutOfRangeException`.

## Para o time de bilhetagem

O contrato em `contracts/openapi/tarifa-service.yaml` já reflete o endpoint novo
(`POST /v1/tarifas/{linhaId}/reajustes`) com os schemas `ReajusteRequest` e `ReajusteResponse` —
pronto para gerar o client a partir dele.

## Não fiz (fora do escopo desta task)

- Não adicionei testes de integração HTTP (`WebApplicationFactory`) para o endpoint novo — o
  serviço não tinha esse tipo de teste antes desta mudança, e a task pede TDD no nível do
  agregado (`TarifaLinha`), que está coberto. Sinalizo como possível próximo passo, não como
  pendência da TASK-03.
- Não toquei em autenticação/autorização do endpoint — não havia nada no requirements.md/design.md
  sobre isso e o endpoint de consulta existente também não tem.
