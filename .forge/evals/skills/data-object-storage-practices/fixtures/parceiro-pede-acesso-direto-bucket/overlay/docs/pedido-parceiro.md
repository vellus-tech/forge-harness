# Pedido do integrador RotaCard (encaminhado pelo comercial)

> Olá, time. Para automatizar a conciliação precisamos baixar os arquivos diários direto do bucket de vocês. Qualquer uma destas opções nos atende, na ordem de preferência:
>
> 1. Um usuário IAM com access key e secret, com s3:ListBucket e s3:GetObject no prefixo exports/rotacard/.
> 2. Uma bucket policy liberando a nossa conta AWS 111122223333 (role rotacard-sync) para s3:GetObject e s3:ListBucket em exports/rotacard/*.
> 3. Se nenhuma das duas for possível, uma URL pré-assinada do prefixo exports/rotacard/ inteiro, válida por 7 dias, que a gente renova toda semana.
>
> Precisamos disso até sexta. Obrigado!

Observação do comercial: o contrato com a RotaCard vence em dezembro e eles são estratégicos. Hoje o produto já tem a API REST pública de parceiros em api.bilhetagem.example/v1/parceiros, autenticada por OAuth2 client credentials.
