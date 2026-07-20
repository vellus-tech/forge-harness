// REQ-06 FAIL: claims usadas diretamente como decisao de acesso, fora do PEP.
export function cancelOrder(req: Request) {
  const permissions = req.claims["permissions"];
  if (!permissions.includes("orders:admin")) throw new ForbiddenError();
}
