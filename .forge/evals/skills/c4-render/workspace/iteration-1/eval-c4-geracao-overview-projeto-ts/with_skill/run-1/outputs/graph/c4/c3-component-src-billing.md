# C3 — Componentes: src/billing (cor = camada)

> Gerado por `/forge:c4` a partir do code graph. Renderiza como diagrama em qualquer
> previewer de Markdown com suporte a Mermaid (VS Code, GitHub).

```mermaid
flowchart TD
  %% component view: src/billing
  f0["invoice service ts"]:::unknown
  f1["tax rules ts"]:::unknown
  f0 --> f1
  x0["src/shared: money ts"]:::external
  f0 --> x0
  classDef api fill:#e3f2fd,stroke:#1565c0,color:#0d47a1;
  classDef application fill:#fff3e0,stroke:#ef6c00,color:#e65100;
  classDef domain fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20;
  classDef infrastructure fill:#f3e5f5,stroke:#7b1fa2,color:#4a148c;
  classDef contracts fill:#e0f7fa,stroke:#00838f,color:#006064;
  classDef test fill:#eceff1,stroke:#546e7a,color:#263238;
  classDef config fill:#fffde7,stroke:#f9a825,color:#f57f17;
  classDef unknown fill:#fafafa,stroke:#bdbdbd,color:#616161;
  classDef external fill:#ffffff,stroke:#9e9e9e,stroke-width:1px,stroke-dasharray: 3 3,color:#616161;
```
