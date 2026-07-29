# Capability packs

Capability packs adicionam orientação técnica opt-in por stack sem substituir a governança do Forge. Ative um pack em `.forge/forge.yaml` sob `capabilities.active`; o `doctor` pode sugerir packs a partir do código detectado, mas nunca os ativa sozinho.

Precedência: constitution → baseline e ADRs → `custom/` do projeto → capability pack → default do template. Um pack é contexto de execução, não autorização para refatorar um brownfield nem para introduzir dependências. Cada pack declara aplicabilidade, conflitos e verificações; carregue somente o pack aplicável à área afetada.

Os packs distribuídos são: `backend-dotnet-relational`, `backend-node-postgres`, `backend-java-relational` e `backend-python-relational`. Regras transversais de segurança, testes e migrations ficam em `rules/` para não duplicar conhecimento em cada pack.

**Não confundir com o `pack:` do frontmatter de rule.** São dois eixos distintos que por acaso compartilham a palavra. Um capability pack é um perfil de **stack** — orientação técnica sobre como escrever código naquele ecossistema — ativado por `capabilities.active` no `forge.yaml`. Já `pack: <nome>` no frontmatter de uma rule (ex.: `authz`, `pii-pci`) marca um rule-pack de **domínio**: um contrato normativo que só é obrigatório onde o domínio se aplica (ver `rules/README.md`). Um capability pack não ativa rule-pack algum, e vice-versa. A chave de ativação de rule-packs ainda não existe — enquanto não existir, a rule marcada vale como referência disponível, nunca como gate imposto (item `LDG-0003` no ledger do harness).
