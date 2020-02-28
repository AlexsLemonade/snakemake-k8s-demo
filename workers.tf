resource "aws_security_group" "eks_demo_node" {
  name = "terraform-eks-demo-node"
  description = "Security group for all nodes in the cluster"
  vpc_id = aws_vpc.eks_demo.id

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "terraform-eks-demo-node"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# resource "aws_security_group_rule" "eks_demo_cluster_ingress_node" {
#   source_security_group_id = aws_security_group.eks_demo_node.id
#   description = "Allow worker node to communicate with the cluster API Server"
#   from_port = 443
#   protocol = "tcp"
#   security_group_id = aws_security_group.eks_demo_cluster.id
#   to_port = 443
#   type = "ingress"
# }

resource "aws_security_group_rule" "eks_demo_ssh" {
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["173.75.220.105/32"]
  security_group_id = aws_security_group.eks_demo_node.id
}

resource "aws_security_group_rule" "eks_demo_node_ingress_self" {
  description = "Allow node to communicate with each other"
  from_port = 0
  protocol = "-1"
  security_group_id = aws_security_group.eks_demo_node.id
  source_security_group_id = aws_security_group.eks_demo_node.id
  to_port = 65535
  type = "ingress"
}

resource "aws_security_group_rule" "eks_demo_node_ingress_cluster" {
  description = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port = 1025
  protocol = "tcp"
  security_group_id = aws_security_group.eks_demo_node.id
  source_security_group_id = aws_security_group.eks_demo_cluster.id
  to_port = 65535
  type = "ingress"
 }

resource "aws_security_group_rule" "eks_demo_cluster_ingress_node_https" {
  description = "Allow pods to communicate with the cluster API Server"
  from_port = 443
  protocol = "tcp"
  security_group_id = aws_security_group.eks_demo_cluster.id
  source_security_group_id = aws_security_group.eks_demo_node.id
  to_port = 443
  type = "ingress"
}

data "aws_ami" "eks_demo_worker" {
   filter {
     name = "name"
     values = ["amazon-eks-node-${aws_eks_cluster.eks_demo.version}-v*"]
   }

   most_recent = true
   owners = ["602401143452"] # Amazon EKS AMI Account ID
 }


 # This data source is included for ease of sample architecture deployment
# and can be swapped out as necessary.
data "aws_region" "current" {
}

# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# We implement a Terraform local here to simplify Base64 encoding this
# information into the AutoScaling Launch Configuration.
# More information: https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html
locals {
  eks_demo_node_userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.eks_demo.endpoint}' --b64-cluster-ca '${aws_eks_cluster.eks_demo.certificate_authority[0].data}' '${var.cluster_name}'
USERDATA

}

resource "aws_iam_instance_profile" "eks_demo_node" {
  name = "eks-demo-profile"
  role = aws_iam_role.eks_demo_node.name
}

resource "aws_key_pair" "eks_demo_key" {
  key_name = "eks-demo-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDG1WFcvLLyLK7jZfhYnNBfbVwm259du2ig4tYcicA1d8d8I43LcWg2WYpd7EfNFH8LnJMDg632NcnQ0qzrpUG4zLGTcYufXm1Fm97J285iabzlUxfgSpbk5Ee1ioNCmqtPxEgy5lrt2xw0p3Rnbn0NvSKzwGU82/k/NCbxeKbaRpHLjz9TTcAdcZLugV7Syr8W+zWBqlCIMyC4ce4t8s/ecGbyacmRPdPqC9jUBC0guLHeQmlinINJIr+wMihxJ0B5Zcyokf4wXlQBPPcB89oO9L81nlApY6aK5JJrhkSN8M5+YOkdk6Xi4SZuJD5SLWbilKGPiCNiLPAnPw7m7Ual"
}

resource "aws_launch_configuration" "eks_demo" {
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.eks_demo_node.name
  image_id = data.aws_ami.eks_demo_worker.id
  instance_type = "m4.large"
  name_prefix = "terraform-eks-demo"
  security_groups = [aws_security_group.eks_demo_node.id]
  user_data_base64 = base64encode(local.eks_demo_node_userdata)
  key_name = aws_key_pair.eks_demo_key.key_name

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "eks_demo" {
  desired_capacity = 2
  launch_configuration = aws_launch_configuration.eks_demo.id
  max_size = 2
  min_size = 1
  name = "terraform-eks-demo"
  vpc_zone_identifier = flatten([aws_subnet.eks_demo.*.id])

  tag {
    key = "Name"
    value = "terraform-eks-demo"
    propagate_at_launch = true
  }

  tag {
    key = "kubernetes.io/cluster/${var.cluster_name}"
    value = "owned"
    propagate_at_launch = true
  }
}

locals {
  config_map_aws_auth = <<CONFIGMAPAWSAUTH


apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.eks_demo_node.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH

}

output "config_map_aws_auth" {
  value = local.config_map_aws_auth
}
