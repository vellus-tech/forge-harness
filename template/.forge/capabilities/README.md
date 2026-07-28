# Capability packs

Capability packs adicionam orientação técnica opt-in por stack sem substituir a governança do Forge. Ative um pack em `.forge/forge.yaml` sob `capabilities.active`; o `doctor` pode sugerir packs a partir do código detectado, mas nunca os ativa sozinho.

Precedência: constitution → baseline e ADRs → `custom/` do projeto → capability pack → default do template. Um pack é contexto de execução, não autorização para refatorar um brownfield nem para introduzir dependências. Cada pack declara aplicabilidade, conflitos e verificações; carregue somente o pack aplicável à área afetada.

Os packs distribuídos são: `backend-dotnet-relational`, `backend-node-postgres`, `backend-java-relational` e `backend-python-relational`. Regras transversais de segurança, testes e migrations ficam em `rules/` para não duplicar conhecimento em cada pack.
