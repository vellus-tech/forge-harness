"""cria tabela recargas"""
import sqlalchemy as sa
from alembic import op

revision = "0001"
down_revision = None


def upgrade() -> None:
    op.create_table(
        "recargas",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("usuario_id", sa.Integer, nullable=False),
        sa.Column("cartao_id", sa.String(20), nullable=False),
        sa.Column("valor", sa.Numeric(10, 2), nullable=False),
        sa.Column("status", sa.String(20), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("recargas")
