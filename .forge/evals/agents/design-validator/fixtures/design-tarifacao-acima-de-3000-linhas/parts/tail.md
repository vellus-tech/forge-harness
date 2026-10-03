
## Schema / Modelo de Persistência

```sql
CREATE TABLE tabela_tarifa (
  linha_id UUID PRIMARY KEY,
  valor_tarifa FLOAT NOT NULL,
  vigencia_inicio DATE NOT NULL
);
```

## Testes

- Testes unitários do cálculo.

## Referências

- `docs/product/modules/tarifacao/requirements.md`
