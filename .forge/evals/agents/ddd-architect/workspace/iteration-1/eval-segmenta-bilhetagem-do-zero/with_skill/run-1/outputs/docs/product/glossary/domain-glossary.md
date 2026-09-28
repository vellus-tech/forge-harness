# Glossário de Domínio — Tarifa Viva

Termos canônicos gerais, comuns a mais de um bounded context. Termos específicos de um único contexto ficam em `docs/product/glossary/ubiquitous-language.md`.

| Termo (pt-BR) | Identificador (EN) | Definição | Observações |
|---|---|---|---|
| Consórcio | Consortium | Conjunto de operadoras de ônibus do município de Vale do Sereno (3 operadoras) | Escopo organizacional do produto |
| Operadora | Operator | Empresa de ônibus participante do consórcio (Viação Serrana, Expresso Vale, TransSereno) | Dona de uma ou mais linhas |
| Passageiro | Passenger | Usuário final que embarca e recarrega o cartão | Ator humano principal |
| Gestor do Consórcio | Consortium Manager | Usuário do backoffice que bloqueia cartões e acompanha o clearing | Ator humano administrativo |
| Money (Dinheiro) | Money | Value Object monetário, sempre representado como inteiro em centavos | Compartilhado entre Fare Collection, Passenger Wallet, Recharge e Settlement como pacote de tipos, nunca como Shared Kernel de regras |
