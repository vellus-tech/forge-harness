"""valor da recarga passa a ser inteiro em centavos"""
import sqlalchemy as sa
from alembic import op

revision = "0002"
down_revision = "0001"


def upgrade() -> None:
    op.drop_column("recargas", "valor")
    op.add_column("recargas", sa.Column("valor_centavos", sa.BigInteger, nullable=False))


def downgrade() -> None:
    op.drop_column("recargas", "valor_centavos")
