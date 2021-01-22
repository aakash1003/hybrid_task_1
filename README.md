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
resource "tls_private_key" "taskkey" {
 algorithm = "RSA"
 rsa_bits = 4096
}

resource "aws_key_pair" "key" {
 key_name = "task1key"
 public_key = "${tls_private_key.taskkey.public_key_openssh}"
 depends_on = [
    tls_private_key.taskkey
    ]
}

resource "local_file" "key1" {
 content = "${tls_private_key.taskkey.private_key_pem}"
 filename = "task1key.pem"
  depends_on = [
    aws_key_pair.key
   ]
}
```
