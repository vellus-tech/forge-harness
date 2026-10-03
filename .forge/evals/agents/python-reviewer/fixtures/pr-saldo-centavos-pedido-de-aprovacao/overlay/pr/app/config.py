import logging
import os

logger = logging.getLogger(__name__)

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://carteira:senha-dev-local@localhost:5432/carteira")
logger.info("conectando no banco %s", DATABASE_URL)
