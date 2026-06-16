---
name: update-changelog
description: Atualiza o CHANGELOG.md de um componente seguindo o formato Keep a Changelog.
arguments:
  - name: component
    description: "Caminho relativo do componente (ex: src/Server (atual), src/Domain (atual))"
    required: true
  - name: type
    description: Tipo da mudança (added, changed, deprecated, removed, fixed, security)
    required: true
  - name: description
    description: Descrição da mudança em pt-BR
    required: true
---

# /forge:update-changelog

Atualiza o `CHANGELOG.md` do componente especificado, adicionando a entrada na seção `[Unreleased]`.

## Passos a Executar

1. **Localizar CHANGELOG**
   - Verificar que `<component>/CHANGELOG.md` existe
   - Se não existir, criar com cabeçalho Keep a Changelog padrão (ver `/CHANGELOG.md` na raiz como referência)

2. **Validar `type`**
   - Aceitos: `added`, `changed`, `deprecated`, `removed`, `fixed`, `security`
   - Mapear para seções em português:
     - `added` → `### Adicionado`
     - `changed` → `### Alterado`
     - `deprecated` → `### Depreciado`
     - `removed` → `### Removido`
     - `fixed` → `### Corrigido`
     - `security` → `### Segurança`

3. **Localizar seção `[Unreleased]`**
   - Se não existir, criar no topo do arquivo (acima da primeira versão numerada)

4. **Localizar ou criar subseção** do tipo correto dentro de `[Unreleased]`

5. **Adicionar entrada** no formato `- <description>` na subseção

## Validações Pós-Execução

- [ ] Entrada adicionada na seção `[Unreleased]` do componente correto
- [ ] Seção do tipo correto usada
- [ ] Sem alteração em versões já liberadas
- [ ] Formato Keep a Changelog preservado
