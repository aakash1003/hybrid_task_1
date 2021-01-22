# Terraform_with_AWS
# Problem Statement
## Have to create/launch Application using Terraform
1. Create the key and security group which allow the port 80.

2. Launch EC2 instance.

3. In this Ec2 instance use the key and security group which we have created in step 1.

4. Launch one Volume (EBS) and mount that volume into /var/www/html

5. Developer have uploded the code into github repo also the repo has some images.

6. Copy the github repo code into /var/www/html

7. Create S3 bucket, and copy/deploy the images from github repo into the s3 bucket and change the permission to public readable.

8. Create a Cloudfront using s3 bucket(which contains images) and use the Cloudfront URL to update in code in /var/www/html


## Solution for this problem is:
Initial steps:
* Create the repository from where developer will push the code.

* Configure the hooks so that whenever the developer commit the code it will automaically puch the code to github.

Step 1: Creating the key and security group:
* key-pair:
```
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

```
![key pair](https://github.com/aakash1003/terraform_with_AWS/blob/master/img-1.PNG)

* security-group:
```
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
```

![security group](https://github.com/aakash1003/terraform_with_AWS/blob/master/img-2.PNG)
![security group](https://github.com/aakash1003/terraform_with_AWS/blob/master/img-3.PNG)

## Step 2 and 3: Launcing the EC2 with the key and security group made in step 1:
```
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
```

![aws instance](https://github.com/aakash1003/terraform_with_AWS/blob/master/img-4.PNG)


## Step 4,5 and 6: Launch one volume(EBS) mount it and copy the github code into /var/www/html/:
```
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

```

![ebs volume](https://github.com/aakash1003/terraform_with_AWS/blob/master/img-5.PNG)

## Step 7: Create S3 bucket, and copy/deploy the images from github repo into the s3 bucket and change the permission to public readable.
```
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

```

![s3 bucket](https://github.com/aakash1003/terraform_with_AWS/blob/master/img-6.PNG)

## Step 8: Create a Cloudfront using s3 bucket(which contains images) and use the Cloudfront URL to update in code in /var/www/html
```
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

```

![cloudfront distribution](https://github.com/aakash1003/terraform_with_AWS/blob/master/img-7.PNG)





## Step 9: Create a snapshot (backup) of EBS volume created
```
resource "aws_ebs_snapshot" "snapshot1" {
  volume_id = aws_ebs_volume.esb1.id


  tags = {
    Name = "snap1"
  }
}

```
## After putting these code in onc file of .tf extension run this file
For this you have to install the terraform

* Then aws configure

* Then, terraform inti

* Then, terraform plan or terraform

* Finally run the file terraform apply -auto-approve

* If want to destroy the environment terraform destroy -auto-approve

![final output](https://github.com/aakash1003/terraform_with_AWS/blob/master/img-8.PNG)


