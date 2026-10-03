import express from 'express';
import { listRefunds, registerApproval } from './refunds.js';

const app = express();
app.use(express.json());

app.get('/v1/estornos', async (req, res) => {
  res.json(await listRefunds(req.query.status));
});

app.post('/v1/estornos/:id/approval', async (req, res) => {
  res.status(202).json(await registerApproval(req.params.id, req.body.approverId));
});

app.listen(process.env.PORT ?? 3001);
