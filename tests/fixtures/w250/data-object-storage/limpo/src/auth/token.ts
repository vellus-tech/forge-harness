const token = jwt.sign(payload, segredo, { expiresIn: 3600 });
