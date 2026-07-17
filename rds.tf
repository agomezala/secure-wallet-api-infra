resource "aws_db_subnet_group" "main" {
  name       = "wallet-db-subnet-group"
  subnet_ids = [for az in module.network_az : az.data_subnet_id]

  tags = { Name = "wallet-db-subnet-group" }
}

resource "aws_db_instance" "postgres" {
  identifier     = "wallet-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 20
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "walletdb"
  username = "walletadmin"
  password = var.rds_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = false
  publicly_accessible = false
  skip_final_snapshot = true

  backup_retention_period = 1
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  tags = { Name = "wallet-db" }
}
