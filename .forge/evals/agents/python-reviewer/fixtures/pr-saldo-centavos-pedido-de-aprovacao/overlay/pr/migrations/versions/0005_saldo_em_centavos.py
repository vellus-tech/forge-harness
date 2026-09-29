"""saldo da carteira passa a ser inteiro em centavos"""
import sqlalchemy as sa
from alembic import op

revision = "0005"
down_revision = "0004"


def upgrade() -> None:
    op.alter_column(
        "carteiras",
        "saldo",
        new_column_name="saldo_centavos",
        type_=sa.BigInteger,
        nullable=False,
        postgresql_using="(saldo * 100)::bigint",
    )


def downgrade() -> None:
    pass
