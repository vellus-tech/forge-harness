# Escalação para o comitê de arquitetura de segunda — conflito de retenção de `validacoes`

**Origem:** validação do `docs/product/trd/trd.md` antes do comitê.
**Natureza:** conflito entre dois insumos aprovados, não um erro de redação — não resolvido unilateralmente nesta revisão.

## O conflito

- `NFRD-RET-01` (NFRD, aprovado): validações de embarque retidas por **5 anos** para auditoria das operadoras.
- `docs/product/data-model/data-model.md` (revisado pelo time de dados em 2026-09-18, já implementado): `validacoes` com expurgo automático mensal em **24 meses**.

O TRD v0.1 já documentava os 24 meses (herdados do Data Model) na seção 10, mas mantinha o NFRD-RET-01 apontado para essa mesma seção na matriz de rastreabilidade (seção 20) sem qualquer nota — ou seja, o documento passava a impressão de conformidade onde há uma contradição de fundo.

## Por que isto não é ajuste editorial

Escolher um dos dois textos para "alinhar o TRD" esconderia a decisão real: reduzir retenção de 5 anos para 24 meses é abrir mão de dado necessário para auditoria de compensação entre operadoras (risco de disputa comercial sem evidência); estender de 24 meses para 5 anos tem custo de armazenamento e pode exigir remodelar o expurgo automático que o time de dados já entregou. Nenhuma das duas é decisão de engenharia de documento — é decisão de produto/compliance.

## Caminhos propostos ao comitê

1. Estender a retenção de `validacoes` para 5 anos (avaliar custo de armazenamento e impacto no expurgo automático já implementado).
2. Rebaixar formalmente `NFRD-RET-01` para 24 meses, com aval explícito de quem responde pela auditoria das operadoras.
3. Reter agregados necessários à auditoria por 5 anos numa estrutura separada, mantendo o detalhe transacional em 24 meses.

## Estado do TRD entregue

A seção 10 do TRD foi mantida descrevendo o comportamento **hoje implementado** (24 meses), com nota explícita do conflito, e a seção 22 (Pontos a Validar) registra o bloqueio para decisão do comitê. A matriz de rastreabilidade (seção 20) marca `NFRD-RET-01` como "conflito aberto" em vez de simplesmente apontar para a seção 10 como se estivesse satisfeito.
