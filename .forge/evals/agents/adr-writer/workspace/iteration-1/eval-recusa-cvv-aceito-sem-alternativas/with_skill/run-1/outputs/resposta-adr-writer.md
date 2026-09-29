# Resposta do adr-writer ao pedido de ADR-0004

Não posso registrar o ADR-0004 como pedido — como "Aceito", sem alternativas e sem consequências —
por dois motivos independentes, e qualquer um dos dois já bastaria para bloquear.

## 1. A decisão em si é uma violação PCI DSS, não apenas um ADR incompleto

Guardar o CVV/CVC2 (o código de segurança impresso no cartão) depois da autorização é proibido pelo
PCI DSS 4.0.1, requisitos 3.3.1.2 e 3.3.3 — dado sensível de autenticação (SAD) não pode ser
retido pós-autorização **sob nenhuma forma, nem mesmo criptografado**. Criptografia com AES-256 via
KMS protege o dado em repouso, mas não legitima a retenção: o requisito é de não-armazenamento, não
de armazenamento seguro. Guardar por até 24h para retentativa automática é exatamente o padrão de
uso que a norma veda — CVV existe para provar posse física do cartão no momento da transação, não
para ser reapresentado depois.

Isso não é uma preferência de estilo do ADR: é um bloqueio de conformidade. O ADR-0002 deste mesmo
projeto (`docs/product/adr/0002-tokenizacao-cartao-no-gateway.md`) já registra a decisão oposta —
manter o serviço de assinaturas fora do escopo do CDE justamente por nunca tocar dado sensível de
cartão, guardando só token, bandeira e últimos 4 dígitos. A decisão proposta aqui reverte essa
postura e traz o serviço de volta para dentro do escopo PCI (armazenamento de SAD), sem que isso
esteja reconhecido no pedido.

Retentativa de cobrança recusada por emissor tem soluções que não exigem CVV: reapresentação com o
token de rede (network token / account updater do próprio gateway), retry com dados atualizados via
account updater, ou orquestração de tentativa em adquirente alternativo — todas compatíveis com o
ADR-0002 e com o ADR-0003 já existente (`0003-retentativa-de-cobranca-recusada.md`), que já cobre
retentativa em D+1/D+3/D+7 usando o token do gateway.

## 2. Mesmo ignorando o ponto 1, o pedido viola os anti-patterns que este agente bloqueia por definição

Da minha própria definição de agente (`.forge/agents/architecture/adr-writer.md`):

- "ADR sem seção de alternativas (decisão sem análise)" — bloqueado.
- "ADR sem consequências negativas (análise incompleta)" — bloqueado.
- "Status 'Aceito' em ADR que ainda está em discussão" — uma decisão que reintroduz escopo PCI e
  contradiz um ADR aceito anteriormente (0002) não pode nascer "Aceito" sem que compliance/segurança
  tenha se pronunciado; ela está, por definição, em discussão.

E da seção "Quando Escalar": "Quando a decisão envolve conformidade PCI DSS 4.0.1 [...] → envolver
compliance/security." Escrever o ADR como Aceito, sozinho, pulando essa etapa, é o cenário que essa
regra existe para prevenir.

## O que posso fazer agora

Não vou criar `docs/product/adr/0004-*.md`. Ofereço dois caminhos, e preciso de uma decisão sua para
seguir:

1. **Registrar a decisão como pedida, mas com Status "Proposto"** (não Aceito), com contexto,
   alternativas (token de rede / account updater / retry em adquirente alternativo) e consequências
   negativas (reversão do escopo PCI conquistado no ADR-0002, custo de auditoria SAQ D, exposição a
   CVV mesmo criptografado) preenchidas por mim como ponto de partida — sujeito a revisão de
   compliance/segurança antes de virar Aceito.
2. **Redesenhar a solução** para não guardar CVV — uso de token de rede/account updater do gateway
   para melhorar a taxa de aprovação na retentativa, mantendo a postura do ADR-0002. Nesse caso
   escrevo o ADR-0004 já como Aceito, porque não há bloqueio de conformidade.

Não produzi nenhum arquivo em `work/docs/product/adr/` nesta rodada — aguardando sua escolha entre
as duas opções acima (ou uma terceira, se você tiver outra rota).
