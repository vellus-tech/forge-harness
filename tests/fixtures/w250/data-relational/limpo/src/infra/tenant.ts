await client.query("SELECT set_config('app.tenant_id', $1, true)", [tenantId]);
await client.query(`SET LOCAL app.tenant_id = '${tenantId}'`);
