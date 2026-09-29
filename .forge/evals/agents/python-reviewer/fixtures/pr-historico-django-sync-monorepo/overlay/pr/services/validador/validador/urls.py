from django.urls import path

from embarques import views

urlpatterns = [
    path("embarques/<int:embarque_id>/", views.detalhe_embarque),
    path("cartoes/<int:cartao_id>/historico/", views.historico_cartao),
]
