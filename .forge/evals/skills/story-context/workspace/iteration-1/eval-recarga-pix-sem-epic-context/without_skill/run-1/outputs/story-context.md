# Contexto — STORY-03 — Conciliação diária com o extrato do PSP

> Epic: `2026-09-recarga-pix` · Depende de: STORY-02 (status atual: in-progress, ainda não concluída) · Status desta story: todo

## Objetivo desta story

Conciliar toda recarga confirmada contra o extrato do PSP em D+1 e registrar as divergências encontradas. Isso cobre REQ-03 do épico ("Toda recarga confirmada é conciliada contra o extrato do PSP em D+1").

## Tasks desta story

- [ ] TASK-07 — Job de conciliação diária com extrato CNAB do PSP (`src/conciliacao/job.ts`)
- [ ] TASK-08 — Relatório de divergências `recharge_divergence` (`src/conciliacao/divergencias.ts`; depende de TASK-07)

## Critério de aceite explícito da story

- Recarga presente no ledger e ausente no extrato vira divergência.

## Fora de escopo desta story

- Estorno automático de divergências — isso é STORY-04, não implemente aqui.

## Regras do épico que esta story NÃO PODE quebrar

Estas regras não estão na STORY-03 isoladamente, mas vêm do proposal/requirements/design do épico inteiro e do que já foi implementado nas stories anteriores. Ignorá-las quebra contrato com o resto do sistema, mesmo que os testes locais desta story passem.

1. **Horário e timezone fixos do job.** O design do épico (§4) fixa o agendamento às 06h15 America/Sao_Paulo. Não implemente com outro horário nem com UTC "cru" sem conversão — isso desalinha com o extrato do PSP, que fecha nesse fuso.

2. **Fonte do extrato é CNAB, não JSON/REST do PSP.** O design (§4) especifica que o job baixa o extrato em formato CNAB. Não assuma um endpoint de API de extrato: a implementação de parsing deve tratar layout CNAB (posicional, largura fixa), não um payload estruturado.

3. **A tabela-fonte é `recharge_ledger`, particionada por mês, retenção de 400 dias.** O design (§2) define que cada linha do ledger guarda txid, valor em centavos, CPF, status e o payload bruto assinado do webhook. A conciliação compara contra ESSA tabela (criada na STORY-01, TASK-01) — não crie uma tabela paralela nem leia de outro lugar. Valor está em **centavos**, não em reais; comparar com o extrato exige converter/alinhar unidades corretamente.

4. **Só recarga CONFIRMADA entra na conciliação.** REQ-02 do épico é explícito: o saldo só é creditado depois que o PSP confirma a liquidação via webhook. Isso significa que o `status` relevante no ledger para efeitos de conciliação é o de recargas já confirmadas/creditadas (produzido pela STORY-02, TASK-05/TASK-06) — não confunda com recargas que só geraram QR code (STORY-01) e nunca foram pagas. Uma recarga pendente de confirmação não é "divergência"; é simplesmente ainda não liquidada.

5. **Idempotência por txid é uma invariante do sistema inteiro, não só do webhook.** O design (§3) estabelece que reentrega do mesmo txid nunca gera novo crédito. O job de conciliação (TASK-07) e o relatório de divergências (TASK-08) devem preservar essa invariante ao gravar registros: rodar o job duas vezes para o mesmo D+1 (reprocessamento, retry de job) não pode duplicar linhas em `recharge_divergence` nem contar a mesma divergência mais de uma vez. Trate o par (txid, data de referência) como chave natural de idempotência do job, no mesmo espírito da idempotência por txid do webhook.

6. **`recharge_divergence` é uma tabela nova, ainda não migrada.** Não existe migration para ela no repositório (só existe `db/migrations/0012_recharge_ledger.sql`, da STORY-01). TASK-07/TASK-08 precisam incluir a migration dessa tabela antes de gravar nela — isso não está explícito na STORY-03, mas é pré-requisito implícito de design.

7. **Limite diário por CPF (REQ-09) não é responsabilidade desta story, mas pode aparecer no extrato.** O épico tem uma regra de negócio de teto de R$ 500,00/CPF/dia na emissão do QR code (implementada na STORY-04, TASK-09, ainda não feita). A conciliação não deve reimplementar nem validar esse limite — apenas concilie o que está no ledger contra o extrato, sem julgar se a recarga deveria ter sido permitida.

8. **Nunca chame o serviço `saldo` a partir do job de conciliação.** O crédito no cartão é feito exclusivamente pelo fluxo webhook → gRPC interno para o serviço `saldo` (design §1, REQ-02, implementado/a implementar em STORY-02 TASK-06). A conciliação é read-only sobre ledger + extrato e grava divergências; ela não credita, não estorna e não chama o serviço `saldo` via gRPC. Estorno de recarga liquidada e não creditada é escopo exclusivo da STORY-04 (TASK-10), não desta story.

9. **Segredos do PSP (download do extrato, credenciais CNAB) seguem o mesmo padrão de cofre com rotação do épico.** O design (§3) já estabelece que a chave HMAC do webhook vem do cofre de segredos com rotação a cada 90 dias. Qualquer credencial nova que o job de download do extrato precise (usuário/senha ou chave de acesso ao SFTP/API do PSP) deve seguir o mesmo padrão de cofre — nunca literal em código ou config versionado.

10. **Comunicação externa é REST ou arquivo/mensageria, nunca gRPC.** Regra de arquitetura do projeto (fora do épico, mas vale para qualquer integração com o PSP, que é terceiro): o download do extrato do PSP é HTTP/SFTP ou arquivo, não gRPC. gRPC é reservado para comunicação interna entre serviços (ex.: recarga → saldo).

## O que já existe implementado (para não reinventar)

- `src/recarga/webhook-signature.ts` — validação HMAC-SHA256 já implementada (TASK-04, concluída). A conciliação não mexe nisso, é só contexto de que a STORY-02 já garante integridade dos webhooks que alimentam o ledger.
- Migration `db/migrations/0012_recharge_ledger.sql` — schema do ledger já existe (TASK-01, concluída).

## Dependência de story ainda não concluída

STORY-02 (webhook idempotente + crédito via gRPC) está **in-progress**, não concluída — TASK-05 e TASK-06 ainda estão abertas. Isso significa que, no momento em que esta story for implementada, pode não haver ainda recargas com status "confirmada/creditada" de verdade no ambiente de desenvolvimento. Vale construir a conciliação (TASK-07/TASK-08) de forma independente e testável com dados sintéticos de ledger, sem depender de rodar o fluxo end-to-end do webhook.

## Fontes usadas para montar este contexto

`.forge/specs/active/2026-09-recarga-pix/proposal.md`, `requirements.md` (REQ-02, REQ-03, REQ-09), `design.md` (§1–§4), `manifest.yaml`, `tasks.md`, `stories/STORY-01.md`, `stories/STORY-02.md`, `stories/STORY-03.md`, `stories/STORY-04.md`, e `src/recarga/webhook-signature.ts`.
