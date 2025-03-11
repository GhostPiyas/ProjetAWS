provider "aws" {
  region = "eu-west-3"
}

# Groupe de sécurité pour autoriser SSH et les ports nécessaires
resource "aws_security_group" "example" {
  name_prefix = "example-sg-"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Instance 1 : Dolibarr
resource "aws_instance" "dolibarr_instance" {
  ami           = "ami-0359cb6c0c97c6607"
  instance_type = "t2.micro"
  key_name      = "Linux_key"

  # Nom explicite pour l'instance Dolibarr
  tags = {
    Name = "Instance 1 - Dolibarr"
  }

  vpc_security_group_ids = [aws_security_group.example.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y docker docker-compose
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
                    - "8080:80"
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

# Instance 2 : Prometheus + Grafana
resource "aws_instance" "prometheus_grafana_instance" {
  ami           = "ami-0359cb6c0c97c6607"
  instance_type = "t2.micro"
  key_name      = "Linux_key"

  # Nom explicite pour l'instance Prometheus + Grafana
  tags = {
    Name = "Instance 2 - Grafana-Prometheus"
  }

  vpc_security_group_ids = [aws_security_group.example.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y docker docker-compose
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
