# Proposal — validacao-qrcode-embarque

## 2. Escopo

Validador embarcado aceita QR Code dinâmico assinado (Ed25519) gerado pelo app do passageiro, com expiração de 60 s e debitando a tarifa no saldo pré-pago. Muda a capability `embarque` do baseline (novo meio de acesso ao lado do cartão).
