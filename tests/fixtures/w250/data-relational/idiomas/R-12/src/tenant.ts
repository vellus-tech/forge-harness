await client.query(`SET app.tenant_id = '${tenantId}'`);
await client.query("SELECT set_config('app.tenant_id', $1, false)", [tenantId]);
