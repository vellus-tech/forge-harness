# Segmentação DDD - Tarifa Aberta

| Subdomínio | Tipo | Bounded Context | Responsabilidade |
|---|---|---|---|
| Captura | Core | tap-capture | Receber os taps dos validadores e registrar viagens |
| Autorização | Core | fare-authorization | Agregar taps e cobrar na adquirente |
| Risco | Supporting | deny-list | Manter e distribuir a deny list |
| Consulta | Supporting | rider-history | Expor viagens ao passageiro |
| Conciliação | Supporting | settlement | Conciliar cobranças com a liquidação da adquirente |
