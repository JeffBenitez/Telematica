terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "mi_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    name = "mi_vpc"
  }
}

resource "aws_subnet" "mi_subred" {
  vpc_id                  = aws_vpc.mi_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "mi_tabla" {
  vpc_id = aws_vpc.mi_vpc.id
  tags = {
    name = "tabla_enrutamiento"
  }
}

resource "aws_route_table_association" "mi_tabla_association" {
  subnet_id      = aws_subnet.mi_subred.id
  route_table_id = aws_route_table.mi_tabla.id
}

resource "aws_internet_gateway" "mi_gateway" {
  vpc_id = aws_vpc.mi_vpc.id
  tags = {
    name = "mi_gateway"
  }
}

resource "aws_security_group" "Grup_seg" {
  name        = "grupo_seg"
  description = "reglas de seguridad"
  vpc_id      = aws_vpc.mi_vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["10.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["10.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"] # Fixing the typo here
  }
}

resource "tls_private_key" "Tele-Key" {
  algorithm = "RSA"
}

resource "aws_key_pair" "Tele-key" {
  key_name   = "Tele-Key"
  public_key = tls_private_key.Tele-Key.public_key_openssh
}

resource "aws_instance" "app_server" {
  associate_public_ip_address = true
  ami                         = "ami-0230bd60aa48260c6"
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.Tele-key.key_name
  subnet_id                   = aws_subnet.mi_subred.id
  vpc_security_group_ids      = [aws_security_group.Grup_seg.id]

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",              # Actualizar paquetes
      "sudo yum install -y httpd",      # Instalar Apache
      "sudo systemctl start httpd",     # Iniciar Apache
      "sudo systemctl enable httpd"     # Habilitar Apache para que se inicie en el arranque
    
    ]
    

    connection {
      type        = "ssh"
      user        = "ec2-user"  # Usuario predeterminado para Amazon Linux 2
      private_key = file("LlaveT.pem")  # Ruta hacia la llave privada para acceder a la instancia
      host        = self.public_ip   # Utiliza self.public_ip para obtener la IP pública de la instancia
    }
  }
  provisioner "file" {
    source      = "/telem/index.html"  # Ruta local del archivo HTML
    destination = "/var/www/html/index.html"          # Ruta en la instancia EC2
    }
}



