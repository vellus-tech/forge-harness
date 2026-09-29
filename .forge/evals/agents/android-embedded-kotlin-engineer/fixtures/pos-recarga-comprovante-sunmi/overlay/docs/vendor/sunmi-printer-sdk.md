# Sunmi — SDK de impressora térmica (printerlibrary 1.0.23)

Dependência: `com.sunmi:printerlibrary:1.0.23` (já declarada em `libs.versions.toml` como `sunmi-printer`, ainda não usada).

Conexão: `InnerPrinterManager.getInstance().bindService(context, callback)`; o callback entrega um `SunmiPrinterService` em `onConnected` e sinaliza `onDisconnected`.

Métodos usados:

- `printerInit(callback)`
- `printText(text: String, callback)`
- `lineWrap(n: Int, callback)`
- `updatePrinterState(): Int` — estado atual da impressora.

Códigos de `updatePrinterState()`:

| Código | Significado |
|---|---|
| 1 | Normal |
| 2 | Em preparação |
| 3 | Erro de comunicação |
| 4 | Sem papel |
| 5 | Superaquecimento |
| 6 | Tampa aberta |
| 7 | Erro de corte |

Todas as chamadas são assíncronas via AIDL; nunca chamar na main thread. Largura útil: 32 colunas em fonte padrão.
