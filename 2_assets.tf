# === EC2 Instance A ===
resource "aws_instance" "lab_ec2_a" {
  ami                         = "ami-084a7d336e816906b"  # Replace with valid AMI
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.lab_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.lab_public_sg.id]
  key_name                    = "lab"
  associate_public_ip_address = false  # disable auto-assigned public IP

  tags = {
    Name = "lab-ec2-a"
  }
}

# === Elastic IP for EC2 A ===
resource "aws_eip" "lab_eip_a" {
  instance = aws_instance.lab_ec2_a.id

  tags = {
    Name = "lab-eip-a"
  }
}

# === EC2 Instance B ===
resource "aws_instance" "lab_ec2_b" {
  ami                         = "ami-084a7d336e816906b"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.lab_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.lab_public_sg.id]
  key_name                    = "lab"
  associate_public_ip_address = true

  tags = {
    Name = "lab-ec2-b"
  }
}

# === Random suffix for unique S3 name ===
resource "random_id" "unique_suffix" {
  byte_length = 4
}

# === Private S3 Bucket ===
resource "aws_s3_bucket" "lab_bucket" {
  bucket = "lab-bucket-${random_id.unique_suffix.hex}"

  tags = {
    Name = "lab-bucket"
  }

  force_destroy = true  # Allows bucket to be destroyed even if non-empty
}

