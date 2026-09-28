const caixa = { w: 1, h: 2 };
const chaves = await redis.scan(cursor, { MATCH: 'tenant:1:*' });
