# pagamentos-app

Backend do módulo de comprovantes de pagamento: gera o PDF do comprovante, grava no bucket `comprovantes-prd` e devolve um link de download para o app mobile do produto. O mesmo link é enviado por e-mail ao parceiro de conciliação (Concilia Fácil) no fechamento diário. O ambiente on-premises de homologação e produção usa MinIO no cluster Kubernetes.
