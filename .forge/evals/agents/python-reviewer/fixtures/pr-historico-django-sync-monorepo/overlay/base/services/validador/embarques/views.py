from django.contrib.auth.decorators import login_required
from django.http import HttpRequest, JsonResponse
from django.shortcuts import get_object_or_404

from embarques.models import Embarque


@login_required
def detalhe_embarque(request: HttpRequest, embarque_id: int) -> JsonResponse:
    embarque = get_object_or_404(Embarque, pk=embarque_id, cartao__titular=request.user)
    return JsonResponse({"linha": embarque.linha, "tarifa_centavos": embarque.tarifa_centavos})
