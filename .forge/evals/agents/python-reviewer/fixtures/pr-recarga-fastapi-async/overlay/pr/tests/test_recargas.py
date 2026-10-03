from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app


def test_criar_recarga_aprovada() -> None:
    with patch("app.recargas.router.requests.post") as post:
        post.return_value.json.return_value = {"status": "aprovada"}
        resp = TestClient(app).post(
            "/recargas",
            json={"cartao_id": "0001234567", "valor_centavos": 2000},
            headers={"Authorization": "Bearer 42.x"},
        )
    assert resp.json() == {"status": "aprovada"}
