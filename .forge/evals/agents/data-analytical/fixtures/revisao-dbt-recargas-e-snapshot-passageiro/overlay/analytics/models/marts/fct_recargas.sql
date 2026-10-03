{{ config(materialized='table') }}

select * from {{ source('app', 'recargas') }}
