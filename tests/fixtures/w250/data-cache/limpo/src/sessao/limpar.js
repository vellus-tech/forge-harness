for await (const k of redis.scanIterator({ MATCH: "sessao:*", COUNT: 100 })) { await redis.unlink(k); }
