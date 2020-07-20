provider "aws" {
  region = "ap-south-1"
  profile = "nikhil"
}
resource "tls_private_key" "tlskey1" {
  algorithm   = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key1" {
  depends_on=[
	tls_private_key.tlskey1
  ]
  key_name   = "task3"
  public_key = "${tls_private_key.tlskey1.public_key_openssh}"
}

resource "local_file" "private-file1" {
  depends_on = [
     aws_key_pair.generated_key1
  ]

  content  = "${tls_private_key.tlskey1.private_key_pem}"
  filename = "task3.pem"

  provisioner "local-exec" {
       command= "chmod 400 task3.pem"
  }

}
resource "aws_security_group" "efsgroup" {
  depends_on = [
    local_file.private-file1
  ]

  name = "efsgroup"
  description = "Allow TLS inbound traffic"
  vpc_id = "vpc-80c2dfe8"
  ingress {
 	description = "SSH"
 	from_port = 22
 	to_port = 22
 	protocol = "tcp"
 	cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
 	description = "HTTP"
 	from_port = 80
 	to_port = 80
 	protocol = "tcp"
 	cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
 	description = "NFS"
 	from_port = 2049
 	to_port = 2049
 	protocol = "tcp"
 	cidr_blocks = [ "0.0.0.0/0" ]
  }
  egress {
 	from_port = 0
 	to_port = 0
 	protocol = "-1"
 	cidr_blocks = ["0.0.0.0/0"]
  } 	
  tags = {
  	Name = "efsgroup"
  }
}


resource "aws_instance" "web1" {

depends_on = [
     aws_security_group.efsgroup,
  ]
  count = "3"
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "task3"
  security_groups = [ "efsgroup" ]

  tags = {
     Name = "efsos"
  }

}

resource "aws_efs_file_system" "efstask" {
  depends_on = [
    aws_instance.web1,
  ]
  tags = {
    Name = "efstask"
  }
}

resource "aws_efs_access_point" "efsaccess" {
  depends_on = [
    aws_efs_file_system.efstask,
  ]
  file_system_id = "${aws_efs_file_system.efstask.id}"
}

resource "aws_efs_mount_target" "efsmount1" {
  depends_on = [
    aws_efs_access_point.efsaccess,
  ]
  file_system_id = "${aws_efs_file_system.efstask.id}"
  subnet_id      = "subnet-ed3259a1"
  security_groups = [ "${aws_security_group.efsgroup.id}" ]
  
}


resource "null_resource" "nullremote1"  {

  depends_on = [
     aws_efs_mount_target.efsmount1,
  ]

 provisioner "local-exec" {
      command= "echo [git] >> /root/terraform/efs/hosts"
  }


  provisioner "local-exec" {
      command= "echo ${aws_instance.web1[0].public_ip} ansible_ssh_private_key_file=/root/terraform/efs/task3.pem >> /root/terraform/efs/hosts"
  }

 provisioner "local-exec" {
      command= "echo [non-git] >> /root/terraform/efs/hosts"
  }

  provisioner "local-exec" {
      command= "echo ${aws_instance.web1[1].public_ip} ansible_ssh_private_key_file=/root/terraform/efs/task3.pem >> /root/terraform/efs/hosts"
  }
  provisioner "local-exec" {
      command= "echo ${aws_instance.web1[2].public_ip} ansible_ssh_private_key_file=/root/terraform/efs/task3.pem >> /root/terraform/efs/hosts"
  }


  provisioner "local-exec" {
       command= "echo source: ${aws_efs_mount_target.efsmount1.ip_address}:/ > /root/terraform/efs/var.yml"
  }

  provisioner "local-exec" {
       command= "ansible-playbook software.yml"
  }

  provisioner "local-exec" {
       command= "ansible-playbook mount.yml"
  }
  provisioner "local-exec" {
       command= "ansible-playbook remove.yml"
  }

  provisioner "local-exec" {
       command= "ansible-playbook git.yml"
  }
 /*provisioner "local-exec" {
      command= "firefox  ${aws_instance.web1.public_ip}"
  }*/
}


