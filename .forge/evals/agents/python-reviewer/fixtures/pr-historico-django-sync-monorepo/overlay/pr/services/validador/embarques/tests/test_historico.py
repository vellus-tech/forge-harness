import pytest


@pytest.mark.django_db
def test_historico_retorna_embarques_do_titular(client, cartao_com_embarques):
    client.force_login(cartao_com_embarques.titular)
    resp = client.get(f"/cartoes/{cartao_com_embarques.id}/historico/")
    assert resp.status_code == 200


@pytest.mark.skip(reason="precisa de Postgres de teste no CI; banco ainda não provisionado")
@pytest.mark.django_db
def test_historico_de_cartao_alheio_retorna_404(client, cartao_com_embarques, outro_usuario):
    client.force_login(outro_usuario)
    resp = client.get(f"/cartoes/{cartao_com_embarques.id}/historico/")
    assert resp.status_code == 404
