-- service.sql loga o PAN em texto claro dentro de um comentário de chamada de
-- log embutida (ex.: proc/trigger que delega a uma rotina de log) — REQ-12a
-- deve reprovar, mesmo com o bloco de governance ausente, porque REQ-12 é
-- sempre enforce (extensão REQ-06 para .sql).
-- log.Printf("processing card %s", "4111111111111111")
CREATE OR REPLACE FUNCTION log_payment() RETURNS trigger AS $$
BEGIN
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
