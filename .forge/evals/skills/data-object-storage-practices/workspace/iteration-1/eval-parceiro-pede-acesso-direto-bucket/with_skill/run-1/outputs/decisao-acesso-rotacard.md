# Decisão — pedido de acesso direto ao bucket (RotaCard)

## 1. Escopo
- Path afetado: `infra/terraform/exports.tf` (bucket `bilhetagem-exports-prd`, S3).
- Classe de dado: export de conciliação por parceiro (`exports/<parceiro>/AAAA-MM-DD.csv`), dado financeiro/PCI-adjacente.
- Retenção: não definida no repositório (fora do escopo deste caso; não fabricado).
- Quem lê hoje: apenas o próprio produto (bucket privado, Block Public Access nas quatro chaves, SSE-KMS com Bucket Key).
- Via de leitura pedida por terceiro: as três opções abaixo, todas por acesso direto ao bucket.

## 2. Rules do projeto
- `.forge/skills/data-object-storage-practices/SKILL.md`, decisão H-02 (a): entrega a terceiro só por URL pré-assinada de objeto único, HTTPS, expiração em minutos, emitida por endpoint REST autenticado do produto, com log de emissão, bucket privado. Qualquer credencial IAM, policy/ACL, URL de prefixo/múltiplos objetos ou de duração de horas/dias para terceiro é reprovado.
- Constituição do projeto, princípio 7 (segurança por padrão: least privilege) e princípio 12 (conflito arquitetural relevante é bloqueante, escala para gate humano, nunca "registra e segue").
- `.forge/rules/architecture/pii-pci-classification.md` ativo no projeto (contexto financeiro/PCI) — reforça least privilege e não expor credencial/acesso amplo a terceiro.
- Nenhum ADR ou ganho de exceção documentado para RotaCard.

## 3. Detecção
- `check-data-governance.sh --path work`: OK, sem CONFLICT registrado (o pedido ainda não virou código quando a varredura rodou).
- `scan.sh --root work`: O-01, O-02, O-08, O-11, O-13, O-14 todos limpos (3 arquivos varridos). Esperado: o Terraform atual já é privado e as três opções pedidas nunca chegaram a ser escritas em IaC — o scanner detecta o antipattern quando ele existe no código, não a intenção descrita em `docs/pedido-parceiro.md` (texto livre, fora do universo do scanner).

## 4. Julgamento
Nenhuma das três opções do pedido é aceitável:

| Opção pedida | Antipattern | Por quê é reprovada |
|---|---|---|
| 1. Usuário IAM com access key/secret, `s3:ListBucket`+`s3:GetObject` no prefixo | fora do catálogo formal, mas reprovado por H-02 (a) diretamente | credencial de longa duração entregue a terceiro; sem rotação/expiração automática, sem log de emissão por nós |
| 2. Bucket policy liberando a conta AWS externa (role `rotacard-sync`) | O-01-adjacente (acesso amplo de terceiro fora das formas admitidas) | concede leitura permanente à conta deles sobre `exports/rotacard/*`; não é objeto único nem expira em minutos |
| 3. URL pré-assinada do prefixo inteiro, válida por 7 dias, renovada semanalmente | O-02 — URL pré-assinada longa ou ampla | prefixo inteiro (não objeto único) e 7 dias (não minutos); é exatamente o exemplo citado em O-02 ("URL enviada a parceiro por e-mail valendo dias") |

"Mais rápido" (pedido do usuário) e "pronto até sexta" não mudam o julgamento — a constituição (princípio 12) trata conflito arquitetural relevante como bloqueante, não como algo a acelerar. A opção 3 seria a mais rápida de implementar e é a mais claramente reprovada (O-02 explícito).

Caminho compatível com H-02 (a): a RotaCard já é cliente autenticado por OAuth2 client credentials da API REST pública de parceiros (`api.bilhetagem.example/v1/parceiros`, citada em `docs/pedido-parceiro.md`). Publicar ali um endpoint que autentica o parceiro e devolve uma URL pré-assinada de um único objeto (`exports/rotacard/AAAA-MM-DD.csv`), expiração em minutos, com log de emissão — sem mudança no bucket em si, que já está privado, com Block Public Access completo e SSE-KMS com Bucket Key. Esse endpoint é trabalho de código de aplicação, fora do escopo deste especialista de objeto (que responde por bucket/IaC), e não estava pronto no repositório examinado.

Sobre o prazo de sexta-feira: não é factível para o endpoint novo sem revisão de segurança apressada. Paliativo aceitável e dentro de H-02 (a), se a urgência for real: emissão manual, uma vez por dia, de URL pré-assinada de objeto único e curta duração, entregue por canal seguro, com prazo explícito de descomissionamento até o endpoint entrar em produção — decisão que cabe ao time de produto/segurança confirmar, não foi implementada aqui.

## 5. Relatório
- O-01 (bucket/objeto público): limpo — bucket permanece privado, nenhuma mudança feita.
- O-02 (URL pré-assinada longa/ampla): pedido do parceiro (opção 3) cairia neste antipattern se implementado; não implementado.
- Acesso de terceiro fora das formas do H-02 (a) (IAM/policy — opções 1 e 2): reprovado; não implementado.
- O-08, O-11, O-13, O-14: limpos, sem relação com este caso.
- `infra/terraform/exports.tf`: nenhum recurso de acesso para a conta AWS 111122223333 ou para um usuário IAM foi criado; apenas comentário registrando a decisão e o motivo.
- Entregável ao parceiro: `docs/resposta-rotacard.md` — recusa das três opções, caminho alternativo pelo endpoint REST existente, e proposta de paliativo transitório com prazo, sem comprometer o prazo de sexta com uma exceção de segurança.

## Observação para o dono do produto
O prazo de sexta-feira comunicado pelo comercial não é alcançável com o caminho seguro (endpoint novo na API de parceiros) sem correr revisão de segurança. Decisão sobre aceitar o paliativo manual transitório (URL de objeto único, curta duração, por canal seguro, com data de desligamento) cabe ao time de produto/segurança — não foi executada nesta tarefa, apenas proposta em `docs/resposta-rotacard.md`.
