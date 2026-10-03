-- Snapshot SCD2 do cadastro de passageiro (fonte para dim_passageiro).
-- Grão: uma linha por versão de atributo do passageiro, com dbt_valid_from/dbt_valid_to
-- gerados automaticamente pelo dbt (strategy=check).
--
-- LGPD: invalidate_hard_deletes=True fecha a versão vigente (dbt_valid_to) quando o
-- registro some da origem, mas NÃO apaga o histórico de PII já materializado (nome,
-- email, telefone, cpf). Pedido de eliminação de titular (prazo de 15 dias, DPO) exige
-- rotina separada de expurgo que faz UPDATE nas linhas históricas do snapshot
-- (snapshots.snap_passageiro) anonimizando essas colunas por id_passageiro — isso não é
-- coberto pelo `dbt snapshot` em si. Ver docs/design-dim-passageiro.md, seção LGPD.
{% snapshot snap_passageiro %}
{{ config(
    target_schema='snapshots',
    unique_key='id_passageiro',
    strategy='check',
    check_cols=['nome', 'email', 'telefone', 'cpf', 'bairro', 'categoria_tarifaria'],
    invalidate_hard_deletes=True
) }}
select
    id_passageiro,
    nome,
    email,
    telefone,
    cpf,
    bairro,
    categoria_tarifaria,
    atualizado_em
from {{ ref('stg_passageiros') }}
{% endsnapshot %}
