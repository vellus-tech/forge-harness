# ADR-0018 — Notificações push via Firebase Cloud Messaging com fila dedicada

Status: Aceito

Todo push sai pela fila `notificacoes.push` e é entregue pelo FCM; nenhum módulo chama o FCM diretamente.
