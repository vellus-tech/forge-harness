resource "aws_elasticache_replication_group" "tarifa_cache" {
  replication_group_id       = "tarifa-cache"
  description                = "Cache do tarifa-api"
  engine                     = "redis"
  node_type                  = "cache.t4g.medium"
  num_cache_clusters         = 2
  port                       = 6379
  transit_encryption_enabled = true
  security_group_ids         = [aws_security_group.tarifa_cache.id]
}

resource "aws_security_group" "tarifa_cache" {
  name   = "tarifa-cache"
  vpc_id = var.vpc_id

  ingress {
    description = "acesso ao redis"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
