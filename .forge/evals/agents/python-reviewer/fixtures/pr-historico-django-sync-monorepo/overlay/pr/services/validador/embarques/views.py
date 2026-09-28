from typing import Any

from django.contrib.auth.decorators import login_required
from django.http import HttpRequest, JsonResponse
from django.shortcuts import get_object_or_404

from embarques.models import Embarque


@login_required
def detalhe_embarque(request: HttpRequest, embarque_id: int) -> JsonResponse:
    embarque = get_object_or_404(Embarque, pk=embarque_id, cartao__titular=request.user)
    return JsonResponse({"linha": embarque.linha, "tarifa_centavos": embarque.tarifa_centavos})


def _serializar(embarque: Any) -> dict:  # type: ignore[no-untyped-def]
    return {"linha": embarque.linha, "tarifa_centavos": embarque.tarifa_centavos, "ocorrido_em": embarque.ocorrido_em.isoformat()}


@login_required
def historico_cartao(request: HttpRequest, cartao_id: int) -> JsonResponse:
    embarques = Embarque.objects.filter(cartao_id=cartao_id).order_by("-ocorrido_em")[:50]
    return JsonResponse({"embarques": [_serializar(e) for e in embarques]})
