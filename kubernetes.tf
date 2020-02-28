variable "cluster_name" {
  default = "terraform-eks-demo"
  # type = string
}

# This data source is included for ease of sample architecture deployment
# and can be swapped out as necessary.
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "eks_demo" {
  cidr_block = "10.0.0.0/16"

  tags = {
    "Name" = "terraform-eks-demo-node"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "eks_demo" {
  count = 2
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block = "10.0.${count.index}.0/24"
  vpc_id = aws_vpc.eks_demo.id

  tags = {
    "Name" = "terraform-eks-demo-node"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_internet_gateway" "eks_demo" {
  vpc_id = aws_vpc.eks_demo.id

  tags = {
    Name = "terraform-eks-demo"
  }
}

resource "aws_route_table" "eks_demo" {
  vpc_id = aws_vpc.eks_demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_demo.id
  }
}

resource "aws_route_table_association" "eks_demo" {
  count = 2
  subnet_id = aws_subnet.eks_demo[count.index].id
  route_table_id = aws_route_table.eks_demo.id
}


resource "aws_iam_role" "eks_demo_node" {
  name = "terraform-eks-demo-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks_demo_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role = aws_iam_role.eks_demo_node.name
}

resource "aws_iam_role_policy_attachment" "eks_demo_cluster_AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role = aws_iam_role.eks_demo_node.name
}

resource "aws_security_group" "eks_demo_cluster" {
  name = "terraform-eks-demo-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id = aws_vpc.eks_demo.id

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-eks-demo"
  }
}

# OPTIONAL: Allow inbound traffic from your local workstation external IP
#           to the Kubernetes. You will need to replace A.B.C.D below with
#           your real IP. Services like icanhazip.com can help you find this.
resource "aws_security_group_rule" "eks_demo_cluster_ingress_workstation_https" {
  cidr_blocks = ["173.75.220.105/32"]
  description = "Allow workstation to communicate with the cluster API Server"
  from_port = 443
  protocol = "tcp"
  security_group_id = aws_security_group.eks_demo_cluster.id
  to_port = 443
  type = "ingress"
}

resource "aws_eks_cluster" "eks_demo" {
  name = var.cluster_name
  role_arn = aws_iam_role.eks_demo_node.arn

  vpc_config {
    security_group_ids = ["${aws_security_group.eks_demo_cluster.id}"]
    subnet_ids = flatten(["${aws_subnet.eks_demo.*.id}"])
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_demo_cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_demo_cluster_AmazonEKSServicePolicy,
  ]
}
