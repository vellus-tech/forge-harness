from django.urls import path

from embarques import views

urlpatterns = [
    path("embarques/<int:embarque_id>/", views.detalhe_embarque),
]
