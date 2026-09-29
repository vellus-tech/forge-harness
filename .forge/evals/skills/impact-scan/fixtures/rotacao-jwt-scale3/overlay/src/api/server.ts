import { getMe } from './routes/users';
import { pay } from './routes/payments';
export const routes = { '/me': getMe, '/pay': pay };
