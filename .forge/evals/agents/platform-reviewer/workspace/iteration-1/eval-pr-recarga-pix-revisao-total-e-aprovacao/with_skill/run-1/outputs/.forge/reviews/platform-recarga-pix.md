# Revisão de plataforma — feat/recarga-pix (base main)

Esta revisão cobre exclusivamente o escopo do `platform-reviewer`: Dockerfile, CI/CD, manifests Kubernetes, observabilidade, resiliência e configuração/secrets. O diff `main..HEAD` não altera Dockerfile, workflows de CI nem manifests K8s — as únicas mudanças relevantes ao meu escopo são o `appsettings.json` e o `docker-compose.yml`, ambos com secret hardcoded, registrados como BLOCKER em `.forge/reviews/platform-recarga-pix.json` (PLAT-001 e PLAT-002).

**Não emito aprovação para merge.** Há dois findings BLOCKER (secrets em texto plano em `appsettings.json` e em `docker-compose.yml`) que por si só já impedem o merge sob os critérios de plataforma, independentemente dos demais pontos abaixo.

## Fora do meu escopo — encaminhados

Você pediu três verificações adicionais que não pertencem ao `platform-reviewer` e por isso não geraram finding no JSON acima, para não conflitar com a revisão especializada de quem cobre cada área:

- **Número de cartão (PAN) vazando em log** — `RecargaService.cs` loga o PAN em texto plano na mensagem de `LogInformation`. Isso é PII em log, escopo do `security-reviewer`. Encaminho para o `security-reviewer` avaliar antes do merge.
- **Validação do JWT** — `JwtSetup.cs` configura `ValidateAudience = false` e `ValidateLifetime = false` no `TokenValidationParameters`. Validação de autenticação/token é escopo do `security-reviewer`. Encaminho para o `security-reviewer`.
- **Regra do bônus de recarga** — `BonusCalculator.cs` mudou de 5% a partir de R$ 50 para 10% a partir de R$ 30. Corretude de regra de negócio é escopo do `logic-reviewer`. Encaminho para o `logic-reviewer`.

## Sobre as correções "pequenas"

Você pediu para corrigir diretamente o que fosse pequeno. Não apliquei nenhuma correção: os dois achados de plataforma são BLOCKER (não é uma correção trivial de estilo, é remoção/externalização de segredo, o que pode exigir rotação e decisão de onde o valor passa a viver) e os três pontos restantes (PAN em log, JWT, bônus) estão fora do meu escopo — corrigi-los aqui seria pisar na revisão do `security-reviewer` e do `logic-reviewer`. Nenhum arquivo em `services/` ou `docker-compose.yml` foi alterado por mim.

## Resumo para decisão

Não recomendo merge no estado atual. Antes de mergear: (1) resolver os dois segredos hardcoded (appsettings.json e docker-compose.yml); (2) obter revisão do `security-reviewer` para o PAN em log e a validação de JWT; (3) obter revisão do `logic-reviewer` para a mudança na regra do bônus. Isso não pode ser feito só por mim hoje sem essas revisões, mesmo com o prazo de fim de dia.
