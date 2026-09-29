import { logger } from '../../shared/logger';

export async function query(sql: string, params: unknown[]) {
  logger.info('sql', { sql, params: params.length });
  return [] as unknown[];
}
