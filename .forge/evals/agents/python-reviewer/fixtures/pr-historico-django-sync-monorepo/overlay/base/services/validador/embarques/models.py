from django.contrib.auth.models import User
from django.db import models


class Cartao(models.Model):
    numero = models.CharField(max_length=20, unique=True)
    titular = models.ForeignKey(User, on_delete=models.PROTECT, related_name="cartoes")


class Embarque(models.Model):
    cartao = models.ForeignKey(Cartao, on_delete=models.PROTECT, related_name="embarques")
    linha = models.CharField(max_length=10)
    tarifa_centavos = models.BigIntegerField()
    ocorrido_em = models.DateTimeField()
