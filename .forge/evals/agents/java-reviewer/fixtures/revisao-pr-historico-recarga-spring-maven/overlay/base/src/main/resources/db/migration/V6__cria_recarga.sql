CREATE TABLE recarga (
    id BIGSERIAL PRIMARY KEY,
    cartao_id BIGINT NOT NULL REFERENCES cartao(id),
    valor BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL,
    criada_em TIMESTAMPTZ NOT NULL DEFAULT now()
);
