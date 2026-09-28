CREATE TABLE invoices (
  id uuid PRIMARY KEY,
  tenant_id text NOT NULL,
  amount_cents bigint NOT NULL,
  status text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
