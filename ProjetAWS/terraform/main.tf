provider "aws" {
  region     = "eu-west-3"
}

resource "aws_instance" "app" {
  ami             = "ami-0359cb6c0c97c6607"
  instance_type   = "t2.micro"
  key_name        = "Linux_key"

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y docker docker-compose
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker ec2-user
              
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
