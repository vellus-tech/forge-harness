import jwt from "jsonwebtoken";

export function refreshToken(sub: string, key: string) {
  return jwt.sign({ sub, typ: "refresh" }, key, { algorithm: "RS256", expiresIn: 86400 });
}
