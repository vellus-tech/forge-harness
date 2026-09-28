# C2 — Containers (cor = camada dominante)

> Gerado por `/forge:c4` a partir do code graph. Renderiza como diagrama em qualquer
> previewer de Markdown com suporte a Mermaid (VS Code, GitHub).

```mermaid
flowchart TD
  c0["src/billing (2)"]:::unknown
  c1["src/ledger (1)"]:::unknown
  c2["src/notifications (1)"]:::unknown
  c3["src/shared (1)"]:::unknown
  c0 --> c3
  c1 --> c3
  classDef api fill:#e3f2fd,stroke:#1565c0,color:#0d47a1;
  classDef application fill:#fff3e0,stroke:#ef6c00,color:#e65100;
  classDef domain fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20;
  classDef infrastructure fill:#f3e5f5,stroke:#7b1fa2,color:#4a148c;
  classDef contracts fill:#e0f7fa,stroke:#00838f,color:#006064;
  classDef test fill:#eceff1,stroke:#546e7a,color:#263238;
  classDef config fill:#fffde7,stroke:#f9a825,color:#f57f17;
  classDef unknown fill:#fafafa,stroke:#bdbdbd,color:#616161;
```
