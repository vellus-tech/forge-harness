# Transcript — eval-revisao-armazenamento-comprovantes-pre-pr / without_skill / run-1

## Contexto de execução
Caso de eval `without_skill`: nenhuma skill, agente ou material de `.forge/evals` foi lido. A tarefa foi resolvida só com conhecimento próprio sobre S3/IAM, presigned URLs e Kubernetes/MinIO.

## Passos

1. Registrado o instante inicial em `.t0` (`date +%s`).
2. Criado `work/` e rodado o `setup.sh` da fixture `revisao-armazenamento-comprovantes-pre-pr`, que materializou um repositório git com `infra/storage/comprovantes.tf`, `src/comprovantes/{gravar.ts,emitir-link.ts}`, `deploy/k8s/minio.yaml` e o scaffold `.forge/`/`.claude/` (não tocado nesta revisão).
3. Listados os arquivos sob `infra/`, `src/comprovantes/`, `deploy/` e lido o conteúdo de cada um dos quatro arquivos-alvo (`comprovantes.tf`, `emitir-link.ts`, `gravar.ts`, `minio.yaml`).
4. Feita varredura por segredos/credenciais literais no diretório de trabalho (`grep` por `MINIO`/`ACCESS_KEY`/`SECRET`) — nada encontrado nos arquivos revisados.
5. Análise linha a linha dos quatro arquivos contra o pedido do usuário: o app mobile baixa o PDF por um link gerado pelo backend, e o mesmo link é enviado por e-mail ao parceiro de conciliação no fechamento diário. Isso levantou o achado central: um único link pré-assinado de 7 dias sendo reaproveitado para um canal de baixo controle (e-mail).
6. Identificados os achados, em ordem de severidade:
   - Bloqueio de acesso público do bucket S3 desativado nos quatro controles (`infra/storage/comprovantes.tf`) — crítico.
   - Link pré-assinado de 7 dias compartilhado entre app e e-mail ao parceiro (`emitir-link.ts`) — alto, com nota sobre possível limite real de validade caso as credenciais do `S3Client` sejam temporárias (STS).
   - `StatefulSet` do MinIO sem `volumeClaimTemplates` (perda de dado em restart), imagem `latest`, sem `resources`/`securityContext`/probes/`Service` (`deploy/k8s/minio.yaml`) — alto.
   - Chave de objeto previsível (`comprovantes/${transacaoId}.pdf`) em `gravar.ts` — médio.
   - Chave KMS sem `enable_key_rotation` — médio.
   - Ausência de bucket policy negando tráfego não-TLS — médio.
   - Inconsistência entre Terraform (AWS S3) e manifesto k8s (MinIO próprio), sem documentação de qual é a fonte de verdade por ambiente — baixo, sinalizado para esclarecimento, não corrigido (decisão de arquitetura, não bug pontual).
   - Ausência de política de retenção/lifecycle — baixo, sinalizado como decisão de produto/compliance pendente, sem correção de código proposta.
7. Escritos os achados detalhados em `outputs/review.md`, com a lógica de cada um e o porquê da severidade atribuída.
8. Escritas as correções prontas para aplicar em `outputs/correcoes/`:
   - `comprovantes.tf` — bloqueio público corrigido para `true` nos quatro campos, bucket policy nova negando `aws:SecureTransport = false`, `enable_key_rotation = true` na chave KMS.
   - `emitir-link.ts` — separada a função original em duas (`emitirLinkComprovanteApp`, validade 15 min; `emitirLinkComprovanteParceiro`, validade 4h, gerada no momento do envio do fechamento). **Nota**: essa separação muda a assinatura pública do módulo — os pontos de chamada (rota do app, job de fechamento diário) precisam ser atualizados para chamar a função correta; esses pontos não estavam no escopo de arquivos fornecido, então não foram localizados/alterados.
   - `gravar.ts` — chave de objeto passa a incluir um `randomUUID()` além do `transacaoId`, como defesa em profundidade contra enumeração.
   - `minio.yaml` — adicionado `volumeClaimTemplates`, imagem fixada em uma tag de release, `securityContext` non-root, `resources`, probes de liveness/readiness e um `Service` headless associado.
9. Conferido o tamanho de `work/` (5,4 MB) — abaixo do limite de 20 MB, não é necessário apagar.
10. Gravado o instante final e `timing.json`.

## Limitações desta rodada
- Não foi possível localizar os pontos de chamada de `emitirLinkComprovante` (rota da API do app, job do fechamento diário) porque não estavam no escopo de arquivos indicado pelo usuário (`infra/storage/comprovantes.tf`, `src/comprovantes/`, `deploy/k8s/`); a correção proposta para `emitir-link.ts` exige uma segunda passada para atualizar quem chama essas funções.
- Não há neste eval nenhum arquivo de política IAM (role/policy anexada ao serviço que grava/lê o bucket) — a revisão de permissão fica limitada ao que a bucket policy e o public access block cobrem; se existir uma IAM role/policy do serviço em outro lugar do repositório, ela não foi revisada aqui.
- Este é o caso `without_skill`: nenhum material de `.forge/skills`, `.forge/agents`, `plugin/` ou `.forge/evals` foi consultado, por definição do protocolo do eval.
