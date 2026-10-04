## Qualidade (node-quality-scan)

Não há evidência a colar. O node-quality-scan não foi executado.

Motivos verificados no projeto `servico-conciliacao` (commit bf49e39, branch main):

- O projeto é Python (`pyproject.toml`, FastAPI, pytest/ruff), não Node.
- Não existe `.forge/skills/` e nem `skills/node-quality-scan/scripts/scan.sh` no repositório. A única menção ao skill está no `PROFILE.md` do perfil `backend-node-postgres`, que não se aplica a este projeto.
- Não há script `.forge/scripts/node-baseline.sh` de execução aplicável, e nenhum template de checklist de PR foi encontrado no repositório.

Para obter a evidência, é preciso primeiro decidir qual gate de qualidade vale para este projeto (ruff e pytest são os candidatos naturais) ou instalar o perfil correto.
