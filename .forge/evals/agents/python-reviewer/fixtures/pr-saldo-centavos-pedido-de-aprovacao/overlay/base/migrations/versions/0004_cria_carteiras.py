"""cria carteiras"""
import sqlalchemy as sa
from alembic import op

revision = "0004"
down_revision = "0003"


def upgrade() -> None:
    op.create_table(
        "carteiras",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("usuario_id", sa.Integer, nullable=False, index=True),
        sa.Column("saldo", sa.Numeric(12, 2), nullable=True),
    )


def downgrade() -> None:
    op.drop_table("carteiras")
