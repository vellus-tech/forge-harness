# Evidência de qualidade para a descrição da PR (servico-conciliacao)

Status: scan NÃO executado.

Motivo: o script `.forge/skills/node-quality-scan/scripts/scan.sh` não existe no workspace `work/` (a pasta `.forge/skills/` não está presente). O `node-quality-scan` é descrito em `.forge/capabilities/backend-node-postgres/PROFILE.md`, mas a skill não foi instalada neste checkout. Além disso, o projeto `servico-conciliacao` é Python (`pyproject.toml`, `requires-python >=3.12`, FastAPI/psycopg), e o scanner é específico de Node, então não se aplicaria ao código sem adaptação.

Nenhum resultado de qualidade foi inventado. Para gerar o bloco, é preciso instalar a skill `node-quality-scan` (via sync de adapters/upgrade do harness) ou confirmar qual scanner se aplica a este repositório Python.
