# Parecer — revisão crítica do catálogo de módulos (Passe Urbano)

Escopo revisado: `docs/product/modules/{cadastro-passageiro,recarga,tarifacao,notificacoes}/README.md` contra `docs/product/ddd/` (segmentação, context-map, subdomínios), `docs/product/trd/trd.md` e `docs/product/data-model/data-model.md`, com apoio de `frd.md`, `nfrd.md` e `adr/0001`.

## Veredito

Não libere a implementação ainda. Há uma divergência de ownership de dado não resolvida entre dois módulos que precisa de decisão de arquitetura antes de codificar. Os demais pontos foram corrigidos direto nos READMEs por serem ajustes seguros, derivados dos próprios insumos.

## Achados que exigem decisão humana (não corrigidos)

### 1. Ownership de `cartoes_transporte` em conflito entre dois módulos — BLOQUEANTE

- `docs/product/data-model/data-model.md` já sinaliza a tabela como não resolvida: "a definir... cadastro-passageiro emite o cartão; recarga credita o saldo — ownership em discussão".
- Antes da correção, os dois módulos assumiam posse simultânea do mesmo agregado: `cadastro-passageiro/README.md` listava `cartoes_transporte (dono)` e `recarga/README.md` também listava `cartoes_transporte (dono do saldo; recarga grava o saldo diretamente)`.
- Duas bounded contexts reivindicando o mesmo dado quebra o princípio de que todo agregado tem exatamente um dono em DDD, e o `context-map/relations.md` já resolve a intenção architectural: a relação `recarga → cadastro-passageiro` é um ACL sobre o comando gRPC `CreditarSaldo`, isto é, recarga deveria *chamar* cadastro-passageiro, não escrever direto na tabela.
- Corrigi apenas a parte que já tinha resposta inequívoca nos insumos: removi de `recarga/README.md` a frase "recarga grava o saldo diretamente", que contradizia a própria seção de Dependências do mesmo documento e o context-map. Recarga passa a declarar que não é dona de `cartoes_transporte` e que credita saldo via `CreditarSaldo` (ACL).
- O que falta decidir, e não decidi por você: se `cadastro-passageiro` é de fato a única dona de `cartoes_transporte` (consistente com o restante da documentação após o ajuste) ou se a intenção original era outra (ex.: saldo em tabela própria de `recarga`, com `cadastro-passageiro` dono só do cadastro do cartão). Enquanto isso não for resolvido e `data-model.md` atualizado para sair de "a definir", não seria seguro implementar o fluxo de crédito de saldo — ele toca a fronteira de posse de dado que ainda está em aberto.

### 2. `data-model.md` desatualizado em relação ao catálogo de módulos (apontar, não corrigi — fora do escopo dos READMEs de módulo)

Depois do ajuste acima, a leitura consistente entre os módulos é "cadastro-passageiro é dono de `cartoes_transporte`", mas `data-model.md` continua com a linha "a definir / ownership em discussão". Alguém precisa atualizar esse arquivo (ou confirmar que a discussão segue aberta e então desfazer minha correção em `recarga/README.md`, se a decisão final for outra).

## Ajustes seguros aplicados (derivados diretamente dos insumos)

Todos em `docs/product/modules/recarga/README.md`:

1. **Ownership de `cartoes_transporte`** — ver achado 1 acima: troquei a reivindicação de posse e o mecanismo ("grava direto") por "não é dono — atualiza via `CreditarSaldo` (ACL)", alinhando com a própria seção de Dependências do documento e com `context-map/relations.md`.
2. **RF-04 ausente do corpo do documento** — RF-04 ("recarga: consultar a tarifa vigente para calcular a quantidade de passagens exibida ao passageiro") já estava nos Cross-refs e na lista de Dependências (`tarifacao`, OHS/PL `TarifaVigente`), mas não aparecia nem na "Responsabilidade" nem no diagrama de sequência — a chamada a tarifacao estava documentada como dependência mas nunca usada na narrativa do fluxo. Adicionei a chamada à Responsabilidade e um passo `recarga->>tarifacao: TarifaVigente.Obter(linha)` no diagrama de sequência, antes da cobrança.
3. **RNF-03 (latência p95 < 10s) sem cross-ref** — a NFRD atribui esse requisito de latência ao fluxo de recarga, mas o módulo recarga não o citava em nenhum lugar (nem nos Cross-refs, nem na seção de Compliance). Adicionei uma linha em Compliance e o RNF-03 aos Cross-refs.

Os outros três módulos (`cadastro-passageiro`, `tarifacao`, `notificacoes`) foram conferidos linha a linha contra `ddd-segmentation.md`, `context-map/relations.md` (os 4 relacionamentos permitidos batem exatamente com os diagramas de cada módulo, sem relação extra ou faltante), `frd.md`/`nfrd.md` (RF/RNF citados batem com os atribuídos a cada bounded context) e `trd.md` (deployables e stack). Não encontrei divergência neles — não foram alterados.

## Checklist de conformidade verificada (sem achados)

- Tipo de subdomínio por módulo (Core/Supporting/Generic) idêntico em `modules/README.md` e `ddd-segmentation.md`.
- Os 4 relacionamentos do context-map (recarga→tarifacao OHS/PL, recarga→cadastro-passageiro ACL, notificacoes→recarga PL, notificacoes→cadastro-passageiro Conformist) — presentes e só eles — em cada README de módulo e em cada diagrama mermaid.
- ADR-0001 (gRPC interno / REST externo / RabbitMQ para eventos assíncronos): recarga expõe REST para o app do passageiro (correto, é superfície externa) e publica em RabbitMQ; cadastro-passageiro e tarifacao expõem apenas gRPC (correto, é malha interna); notificacoes consome RabbitMQ e chama gRPC. Nenhum módulo expõe gRPC a terceiro externo.
- Escopo PCI DSS: RNF-01 diz que só recarga toca token de cartão — os quatro módulos concordam (recarga em escopo, os outros três explicitamente fora).
- Escopo LGPD: RNF-02 atribui PII a cadastro-passageiro e notificacoes com a mesma base legal (art. 7º, V) — os dois módulos citam a base legal corretamente; tarifacao e recarga corretamente se declaram fora de escopo de PII.
- Deployables de cada módulo batem 1:1 com a tabela de `trd.md`.
- Cross-refs de RF/RNF de cada módulo batem com a atribuição em `frd.md`/`nfrd.md`, exceto o RNF-03 ausente em recarga, já corrigido.

## Arquivos alterados

- `docs/product/modules/recarga/README.md`
