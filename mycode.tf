
provider "aws" {
  region = "ap-south-1"
  profile = "aakash"
}



resource "tls_private_key" "key1" {
 algorithm = "RSA"
 rsa_bits = 4096
}
resource "local_file" "key2" {
 content = "${tls_private_key.key1.private_key_pem}"
 filename = "task1_key.pem"
 file_permission = 0400
}
resource "aws_key_pair" "key3" {
 key_name = "task1_key"
 public_key = "${tls_private_key.key1.public_key_openssh}"
}



resource "aws_security_group" "terraSG" {
  name        = "terraSG"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-0591a26d"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraSG"
  }
}

resource "aws_instance" "web" {

depends_on = [
    aws_security_group.terraSG,
  ]

  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "task1_key"
  security_groups = [ "terraSG" ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.key1.private_key_pem}"
    host     = "${aws_instance.web.public_ip}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "AkOS1"
  }

}


resource "aws_ebs_volume" "esb1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1
  tags = {
    Name = "ebs-vol-1"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.esb1.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach = true
}

output "myos_ip" {
  value = aws_instance.web.public_ip
}


resource "null_resource" "nulllocal2"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.web.public_ip} > publicip.txt"
  	}
}

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.key1.private_key_pem}"
    host     = "${aws_instance.web.public_ip}"
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/aakash1003/terraform_prac.git /var/www/html/",
     "sudo su << EOF",
            "echo \"${aws_cloudfront_distribution.s3_distribution.domain_name}\" >> /var/www/html/path.txt",
            "EOF",
     "sudo systemctl restart httpd"
    ]
  }
}


resource "null_resource" "nulllocal1"  {


depends_on = [
    null_resource.nullremote3,
  ]

	provisioner "local-exec" {
	    command = "start chrome  ${aws_instance.web.public_ip}"
  	}
}


resource "aws_s3_bucket" "bucket-01" {
  bucket = "terra-test-bucket"
  acl    = "public-read"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

resource "null_resource" "images_repo" {
  provisioner "local-exec" {
    command = "git clone https://github.com/aakash1003/my_images.git my_images"
  }
  provisioner "local-exec"{ 
  when        =   destroy
        command     =   "rm -rf my_images"
    }
}

resource "aws_s3_bucket_object" "web-object1" {
  bucket = "${aws_s3_bucket.bucket-01.bucket}"
  key    = "ak.jpg"
  source = "my_images/ak.jpg"
  acl    = "public-read"
}


resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket-01.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.bucket-01.id
 
     custom_origin_config {
            http_port = 80
            https_port = 443
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
        }
  }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.bucket-01.id
forwarded_values {
      query_string = false
cookies {
        forward = "none"
      }
    }
   viewer_protocol_policy = "allow-all"
  }
 price_class = "PriceClass_200"
restrictions {
        geo_restriction {
        restriction_type = "none"
        }
    }
 viewer_certificate {
    cloudfront_default_certificate = true
  }
 
}


