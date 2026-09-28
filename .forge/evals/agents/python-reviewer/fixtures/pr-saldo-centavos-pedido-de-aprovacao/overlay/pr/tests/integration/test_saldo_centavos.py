import os

import pytest

pytestmark = pytest.mark.skipif(not os.getenv("DOCKER_HOST"), reason="sem Docker no runner: Postgres via testcontainers indisponível")


def test_migration_converte_saldo_existente(postgres_migrado) -> None:
    ...


def test_saldo_nulo_legado_nao_quebra_migration(postgres_migrado) -> None:
    ...
