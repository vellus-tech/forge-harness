out, err := svc.Scan(&dynamodb.ScanInput{TableName: aws.String("pedidos")})
