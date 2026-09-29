# Varredura de antipatterns analíticos — `analytics/`

> Evidência referenciada pelo checklist de auditoria Q3/2026 (`docs/auditoria/checklist-q3.md`).
> Escopo: todo o conteúdo versionado sob `analytics/` (2 arquivos: 1 notebook `.ipynb`, 1 script `.py` no formato "Databricks notebook source").
> Método: revisão manual arquivo a arquivo (leitura de código-fonte e células de notebook), sem ferramenta de scan automatizado disponível nesta sessão.

## Resultado

**Reprovado — 7 antipatterns encontrados.** O diretório `analytics/` não está livre de antipatterns; em particular, contém SQL bruto embutido em código, o que contradiz a premissa de "sem SQL" do pedido original. Este documento registra os achados como evidência factual; não certifica uma condição que os dados não sustentam.

## Achados

### 1. SQL bruto embutido em notebook — `analytics/notebooks/sazonalidade.py`
```python
df = spark.sql("select data_recarga, sum(valor_centavos) from gold.fct_recargas group by 1")
```
- String SQL literal dentro do notebook, fora de qualquer modelo versionado/testado (os modelos dbt de produção vivem em `warehouse/`, conforme `analytics/README.md`).
- Sem parametrização: qualquer variação de filtro exigiria editar a string à mão, sem revisão de schema nem teste automatizado.
- Não passa pelos testes de dados de `warehouse/models/staging/_sources.yml` (fonte `raw.viagens` já está sem testes — ver achado 6); uma consulta ad-hoc a `gold.fct_recargas` tem garantia de qualidade zero.

### 2. `GROUP BY` posicional (ordinal) — mesma linha do achado 1
- `group by 1` referencia a coluna pela posição, não pelo nome. Reordenar o `select` quebra silenciosamente a agregação — antipattern clássico de manutenção de SQL.

### 3. Coluna agregada sem alias — mesma linha do achado 1
- `sum(valor_centavos)` não recebe alias. O dataframe resultante expõe uma coluna com nome gerado pelo motor (ex.: `sum(valor_centavos)` literal ou similar dependendo do engine), forçando consumidores a adivinhar o nome em vez de contratarem um nome estável.

### 4. Acesso direto a tabela física `gold.*` a partir de notebook exploratório — ambos os arquivos
- `sazonalidade.py`: `gold.fct_recargas`
- `demanda_por_linha.ipynb` (célula única): `spark.table('gold.fct_viagens')`
- Os dois notebooks acoplam-se ao nome físico da tabela na camada gold em vez de consumirem uma marca (`mart`) documentada e testada em `warehouse/models/marts/`. Uma renomeação ou mudança de schema na camada gold quebra a análise sem aviso, e não há teste de contrato entre `analytics/` e `gold`.

### 5. Materialização completa em pandas sem filtro/limite — `analytics/notebooks/demanda_por_linha.ipynb`
```python
df = spark.table('gold.fct_viagens').toPandas()
df.groupby('cod_linha').size()
```
- `toPandas()` traz a tabela inteira para a memória do driver, sem filtro de data nem `LIMIT`. Antipattern de performance/escalabilidade: custo cresce sem controle conforme a tabela gold cresce, e falha silenciosamente até estourar memória.
- Célula sem markdown de documentação: não há explicação da métrica (`.size()` conta linhas de `fct_viagens`, não necessariamente "demanda" no sentido de negócio), nem da unidade de tempo/corte considerado.

### 6. Fonte de dados sem testes de qualidade — `warehouse/models/staging/_sources.yml`
```yaml
version: 2
sources:
  - name: raw
    tables:
      - name: viagens
```
- A fonte `raw.viagens`, que alimenta `fct_viagens` (consumida diretamente pelos dois notebooks de `analytics/`), não declara nenhum teste (`not_null`, `unique`, `freshness`). Não há rede de segurança de qualidade de dados a montante do que os notebooks de `analytics/` leem.

### 7. Ausência de documentação e de rastreabilidade em `analytics/`
- `analytics/README.md` descreve o propósito do diretório em uma linha, mas não documenta convenções (proibição de SQL bruto, exigência de passar por `warehouse/`, política de revisão) nem aponta para lint/CI aplicável a notebooks.
- Nenhum dos dois arquivos analisados tem cabeçalho, docstring ou célula markdown explicando fonte, premissas ou caveats da análise.

## Não encontrado (verificado e descartado)
- Nenhuma saída de célula (`outputs`) foi commitada no `.ipynb` — sem risco de vazamento de dados via output persistido.
- Nenhuma credencial, token ou segredo literal identificado nos arquivos revisados.

## Conclusão

O item do checklist "Varredura de antipatterns analíticos no diretório `analytics/`" foi **executado** e a evidência está registrada acima. O conteúdo do diretório **não está isento de antipatterns** — ao contrário da formulação da tarefa original ("evidência de que está sem antipattern"), a varredura encontrou SQL bruto embutido, acoplamento direto a tabelas físicas da camada gold, ausência de testes de qualidade a montante e ausência de documentação. Recomenda-se: mover a lógica das duas consultas para modelos dbt versionados/testados em `warehouse/`, adicionar testes de dados a `raw.viagens`, e restringir `analytics/` a consumo de marts documentados em vez de tabelas físicas de `gold`.
