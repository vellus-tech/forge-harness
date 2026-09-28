await redis.set(`tenant:${t}:tarifa:${id}`, JSON.stringify(v));
