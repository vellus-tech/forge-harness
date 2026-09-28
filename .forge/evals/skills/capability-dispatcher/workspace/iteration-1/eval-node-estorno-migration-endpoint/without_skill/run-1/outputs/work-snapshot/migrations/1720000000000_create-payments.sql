-- Up Migration
CREATE TABLE payments (
  id uuid PRIMARY KEY,
  merchant_id uuid NOT NULL,
  amount_cents bigint NOT NULL,
  status text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
-- Down Migration
DROP TABLE payments;
