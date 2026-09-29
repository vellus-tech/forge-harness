# Módulo: tokenizacao-cartao

- **Bounded Context (DDD):** Recarga (adapter dedicado)
- **Tipo:** Adapter

## Responsabilidade

Único ponto do sistema que recebe PAN do app do passageiro. Tokeniza o cartão e autoriza a
recarga junto à adquirente; devolve apenas o token para o módulo `recarga`. Superfície de maior
sensibilidade PCI DSS do domínio — nenhum outro módulo deve receber ou logar PAN.

## Dependências

Consumido por `recarga`. Não expõe nem consome eventos de domínio diretamente — é um adapter de
borda para a adquirente.
