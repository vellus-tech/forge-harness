# Resposta ao integrador RotaCard

Olá, time RotaCard. Liberamos o acesso pela opção 2 do pedido de vocês: uma bucket policy cross-account, restrita ao prefixo `exports/rotacard/`, sem access key/secret de longa duração e sem URL pré-assinada para renovar toda semana.

Dados para configurar do lado de vocês: a leitura é feita assumindo a role `arn:aws:iam::111122223333:role/rotacard-sync` (a mesma que vocês indicaram) contra o bucket `bilhetagem-exports-prd`, com permissão de `s3:ListBucket` (restrita ao prefixo `exports/rotacard/*`) e `s3:GetObject` nos objetos desse mesmo prefixo. Não há credenciais de longa duração para gerenciar do lado de vocês — o acesso é via `sts:AssumeRole` da própria conta AWS 111122223333, sem necessidade de nós emitirmos ou rotacionarmos secrets.

Os arquivos diários de conciliação seguem no padrão `exports/rotacard/AAAA-MM-DD.csv`, com objetos criptografados em repouso (SSE-KMS). Ainda precisamos liberar `kms:Decrypt` para a role `rotacard-sync` na política da chave (fora do escopo da bucket policy) — mandamos a confirmação assim que isso estiver aplicado, o que deve ocorrer ainda antes de sexta.

Ficamos à disposição para qualquer ajuste até sexta.
