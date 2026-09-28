{% snapshot snap_passageiro %}
{{ config(
    target_schema='snapshots',
    unique_key='id_passageiro',
    strategy='check',
    check_cols=['nome', 'email', 'telefone', 'cpf', 'bairro', 'categoria_tarifaria'],
    invalidate_hard_deletes=True
) }}
select id_passageiro, nome, email, telefone, cpf, bairro, categoria_tarifaria, atualizado_em
from {{ ref('stg_passageiros') }}
{% endsnapshot %}
