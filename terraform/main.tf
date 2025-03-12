provider "aws" {
  region = "eu-west-3"
}

# ====================
# Groupe de sécurité
# ====================
resource "aws_security_group" "example" {
  name_prefix = "example-sg-"

  # Autoriser SSH (port 22)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Autoriser l'accès à Dolibarr (port 8181)
  ingress {
    from_port   = 8181
    to_port     = 8181
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Autoriser l'accès à Prometheus (port 9090)
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Autoriser l'accès à Grafana (port 3000)
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Autoriser tout le trafic sortant
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ====================
# Réutilisation du rôle IAM existant
# ====================
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = "ec2_instance_role" # Réutilisation du rôle IAM existant
}

# ====================
# RDS pour Dolibarr
# ====================
resource "aws_db_instance" "dolibarr_db" {
  allocated_storage    = 20
  engine               = "mariadb"
  engine_version       = "10.5"
  instance_class       = "db.t3.micro"
  db_name              = "dolibarrdb"
  username             = "dolibarr_user"
  password             = "dolibarr_password"
  publicly_accessible  = true
  skip_final_snapshot  = true

  tags = {
    Name = "Dolibarr-Database"
  }
}

# ====================
# Instance 1 : Dolibarr
# ====================
resource "aws_instance" "dolibarr_instance" {
  ami           = "ami-0359cb6c0c97c6607"
  instance_type = "t2.micro"
  key_name      = "Linux_key"

  tags = {
    Name = "Instance 1 - Dolibarr"
  }

  vpc_security_group_ids = [aws_security_group.example.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              if command -v yum > /dev/null; then
                sudo yum update -y
                sudo yum install -y docker docker-compose
              elif command -v apt > /dev/null; then
                sudo apt-get update -y
                sudo apt-get install -y docker.io docker-compose
              else
                echo "No suitable package manager found." >&2
                exit 1
              fi

              sudo systemctl start docker
              sudo systemctl enable docker

              mkdir -p /home/ec2-user/dolibarr
              cd /home/ec2-user/dolibarr
              echo 'version: "3.8"
              services:
                db:
                  image: mariadb:10.5
                  container_name: dolibarr-db
                  restart: always
                  environment:
                    MYSQL_ROOT_PASSWORD: rootpassword
                    MYSQL_DATABASE: dolibarr
                    MYSQL_USER: dolibarr_user
                    MYSQL_PASSWORD: dolibarr_password
                  volumes:
                    - db_data:/var/lib/mysql
                
                dolibarr:
                  image: tuxgasy/dolibarr
                  container_name: dolibarr-app
                  restart: always
                  ports:
                    - "8181:80"
                  environment:
                    DOLI_DB_HOST: db
                    DOLI_DB_USER: dolibarr_user
                    DOLI_DB_PASSWORD: dolibarr_password
                    DOLI_DB_NAME: dolibarr
                  depends_on:
                    - db
              
              volumes:
                db_data:' > docker-compose.yml
              
              docker-compose up -d
              EOF
}

# ====================
# Instance 2 : Prometheus + Grafana
# ====================
resource "aws_instance" "prometheus_grafana_instance" {
  ami           = "ami-0359cb6c0c97c6607"
  instance_type = "t2.micro"
  key_name      = "Linux_key"

  tags = {
    Name = "Instance 2 - Grafana-Prometheus"
  }

  vpc_security_group_ids = [aws_security_group.example.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              if command -v yum > /dev/null; then
                sudo yum update -y
                sudo yum install -y docker docker-compose
              elif command -v apt > /dev/null; then
                sudo apt-get update -y
                sudo apt-get install -y docker.io docker-compose
              else
                echo "No suitable package manager found." >&2
                exit 1
              fi

              sudo systemctl start docker
              sudo systemctl enable docker

              mkdir -p /home/ec2-user/prometheus
              cd /home/ec2-user/prometheus
              echo 'version: "3.8"
              services:
                prometheus:
                  image: prom/prometheus
                  container_name: prometheus
                  restart: always
                  ports:
                    - "9090:9090"
                  volumes:
                    - ./prometheus.yml:/etc/prometheus/prometheus.yml
                
                grafana:
                  image: grafana/grafana
                  container_name: grafana
                  restart: always
                  ports:
                    - "3000:3000"
                  environment:
                    GF_SECURITY_ADMIN_USER: admin
                    GF_SECURITY_ADMIN_PASSWORD: admin
                  depends_on:
                    - prometheus
              volumes:
                grafana_data:' > docker-compose.yml
              
              docker-compose up -d
              EOF
}
