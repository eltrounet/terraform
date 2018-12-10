#################################
#################################
# Variables 
#################################

variable "aws_access_key" {
	default = "AKIAICYXSM75QR6BM7JA"}

variable "aws_secret_key" {
	default = "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"}

variable "private_key_path" {
	default = "./terraform_learn.pem"

}

variable "key_name" {
	default = "terraform_learn"
}

variable "network_address_space" {
	default = "10.1.0.0/16"
}

variable "subnet1_address_space" {
	default = "10.1.0.0/24"
}

variable "subnet2_address_space" {
	default = "10.1.1.0/24"
}



#################################
# Data
#################################

data "aws_availability_zones" "available" {}


#################################
# Providers
#################################

provider "aws"{
	access_key = "${var.aws_access_key}"
	secret_key = "${var.aws_secret_key}"
	region = "us-west-2"
}

#################################
# Ressources
#################################

# Networking #

resource "aws_vpc" "vpc" {
	cidr_block = "${var.network_address_space}"
	enable_dns_hostnames = "true"
}

resource "aws_internet_gateway" "igw" {
	vpc_id = "${aws_vpc.vpc.id}" # but I have not defined the ID. Will it works ?
}

resource "aws_subnet" "subnet1" {
	cidr_block = "${var.subnet1_address_space}"
	vpc_id = "${aws_vpc.vpc.id}"
	map_public_ip_on_launch = "true" # Why? What is the use of that?
	availability_zone = "${data.aws_availability_zones.available.names[0]}"
}

resource "aws_subnet" "subnet2" {
	cidr_block = "${var.subnet2_address_space}"
	vpc_id = "${aws_vpc.vpc.id}"
	map_public_ip_on_launch = "true"
	availability_zone = "${data.aws_availability_zones.available.names[1]}"
}

# Routing #

resource "aws_route_table" "rtb" {
	vpc_id = "${aws_vpc.vpc.id}"

	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = "${aws_internet_gateway.igw.id}"
	}
}


resource "aws_route_table_association" "rta-subnet1" {
	route_table_id = "${aws_route_table.rtb.id}"
	subnet_id = "${aws_subnet.subnet1.id}"
}

resource "aws_route_table_association" "rta-subnet2" {
	route_table_id = "${aws_route_table.rtb.id}"
	subnet_id = "${aws_subnet.subnet2.id}"
}


# Security Groups #

# Nginx security group

resource "aws_security_group" "nginx-sg" {
	name = "nginx-sg"
	vpc_id = "${aws_vpc.vpc.id}"

	# SSH access from anywhere
	ingress {
		from_port = 22
		protocol = "tcp"
		to_port = 22
		cidr_blocks = ["0.0.0.0/0"] ## NOT IN THE PRODUCTION ENVIRONNEMENT
	}

	# HTTP access from everywhere

	ingress {
		from_port = 80
		protocol = "tcp"
		to_port = 80
		cidr_blocks = ["0.0.0.0/0"]
	}

	# outbound internet access

	egress {
		from_port = 0
		protocol = "-1"
		to_port = 0
		cidr_blocks = ["0.0.0.0/0"]
	}
}



# Instances #
resource "aws_instance" "nginx1"{
	ami = "ami-01bbe152bf19d0289"
	instance_type = "t2.micro"
	key_name = "${var.key_name}"
	subnet_id = "${aws_subnet.subnet1.id}"
	vpc_security_group_ids = ["${aws_security_group.nginx-sg.id}"]

	connection {
		user	="ec2-user"
		private_key = "${file(var.private_key_path)}"
	}

	provisioner "remote-exec"{

		inline = [
			"sudo yum install epel-release",
			"sudo yum install nginx -y",
			"sudo service nginx start",
			"echo '<html><head><title>Blue Team Server</title></head></html>'"
		]
	}

}



#################################
# Output
#################################

output "aws_instance_public_dns"{
	
	value = "${aws_instance.nginx1.public_dns}"

}

