-- Histórico (SCD2) só do atributo de negócio rastreado: categoria_tarifaria.
-- Dado pessoal (nome, email, telefone, cpf, bairro) NÃO entra aqui (A-16): fica em
-- stg_passageiros, tabela SCD1 mutável e elimimável, ligada por id_passageiro quando
-- necessário. Detalhe da decisão em docs/design-dim-passageiro.md.
{% snapshot snap_passageiro %}
{{ config(
    target_schema='snapshots',
    unique_key='id_passageiro',
    strategy='timestamp',
    updated_at='atualizado_em',
    hard_deletes='invalidate'
) }}
select id_passageiro, categoria_tarifaria, atualizado_em
from {{ ref('stg_passageiros') }}
{% endsnapshot %}
