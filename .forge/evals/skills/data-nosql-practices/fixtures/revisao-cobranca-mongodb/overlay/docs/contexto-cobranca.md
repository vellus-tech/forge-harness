# Serviço de cobrança — contexto

O serviço `services/cobranca` guarda faturas, carteiras de crédito pré-pago e lançamentos de clientes corporativos da bilhetagem. É multi-tenant: cada operadora de transporte é um tenant. O banco é MongoDB 7.0 num replica set de três membros com dados (P-S-S), gerenciado pelo time de plataforma.

Padrões de acesso conhecidos: o app consulta o extrato da carteira a cada abertura da tela de saldo (pico de ~1.800 req/s); o backoffice lista as faturas abertas de um cliente; o job de fechamento roda às 02:00 e gera o arquivo de conciliação; a transferência de crédito entre carteiras do mesmo tenant é feita pelo gestor da frota (algumas centenas por hora, com picos concorrentes no início do mês). Cada fatura acumula eventos de cobrança (lembretes, tentativas de débito, contestação) durante toda a sua vida; faturas contestadas chegam a milhares de eventos.
