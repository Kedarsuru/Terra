terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = "ap-south-1"
  # Don’t set access_key or secret_key here — let Terraform pick from environment / Jenkins / IAM role
}

# --- VPC and Networking ---

data "aws_availability_zones" "azs" {}

resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "eks-simple-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = { Name = "eks-simple-igw" }
}

# Public subnets
resource "aws_subnet" "public0" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = data.aws_availability_zones.azs.names[0]
  map_public_ip_on_launch = true
  tags = { Name = "eks-public0" }
}
resource "aws_subnet" "public1" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.azs.names[1]
  map_public_ip_on_launch = true
  tags = { Name = "eks-public1" }
}
resource "aws_subnet" "public2" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.azs.names[2]
  map_public_ip_on_launch = true
  tags = { Name = "eks-public2" }
}

# Private subnets
resource "aws_subnet" "private0" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = data.aws_availability_zones.azs.names[0]
  tags = { Name = "eks-private0" }
}
resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = data.aws_availability_zones.azs.names[1]
  tags = { Name = "eks-private1" }
}
resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = data.aws_availability_zones.azs.names[2]
  tags = { Name = "eks-private2" }
}

# Route table for public subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = { Name = "eks-public-rt" }
}
resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}
resource "aws_route_table_association" "pub_assoc0" {
  subnet_id      = aws_subnet.public0.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "pub_assoc1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "pub_assoc2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public_rt.id
}

# NAT Gateway for private subnets
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = { Name = "eks-nat-eip" }
}
resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public0.id
  tags = { Name = "eks-nat-gw" }
}

# Route tables for private subnets
resource "aws_route_table" "private_rt0" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = { Name = "eks-priv-rt0" }
}
resource "aws_route" "priv0_default" {
  route_table_id         = aws_route_table.private_rt0.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.natgw.id
}
resource "aws_route_table_association" "priv_assoc0" {
  subnet_id      = aws_subnet.private0.id
  route_table_id = aws_route_table.private_rt0.id
}

resource "aws_route_table" "private_rt1" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = { Name = "eks-priv-rt1" }
}
resource "aws_route" "priv1_default" {
  route_table_id         = aws_route_table.private_rt1.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.natgw.id
}
resource "aws_route_table_association" "priv_assoc1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private_rt1.id
}

resource "aws_route_table" "private_rt2" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = { Name = "eks-priv-rt2" }
}
resource "aws_route" "priv2_default" {
  route_table_id         = aws_route_table.private_rt2.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.natgw.id
}
resource "aws_route_table_association" "priv_assoc2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private_rt2.id
}

# --- IAM roles ---

resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-simple-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "cluster_attach1" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_iam_role_policy_attachment" "cluster_attach2" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

resource "aws_iam_role" "eks_node_role" {
  name = "eks-simple-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "node_attach1" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "node_attach2" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "node_attach3" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# --- EKS cluster and node group ---

resource "aws_eks_cluster" "eks" {
  name    = "simple-eks-cluster"
  version = "1.31"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.private0.id,
      aws_subnet.private1.id,
      aws_subnet.private2.id
    ]
    endpoint_public_access = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_attach1,
    aws_iam_role_policy_attachment.cluster_attach2
  ]

  tags = {
    Name = "simple-eks-cluster"
  }
}

resource "aws_eks_node_group" "ng" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "simple-eks-nodegroup"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids = [
    aws_subnet.private0.id,
    aws_subnet.private1.id,
    aws_subnet.private2.id
  ]

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 3
  }

  instance_types = ["t3.medium"]

  depends_on = [
    aws_eks_cluster.eks,
    aws_iam_role_policy_attachment.node_attach1,
    aws_iam_role_policy_attachment.node_attach2,
    aws_iam_role_policy_attachment.node_attach3
  ]

  tags = {
    Name = "simple-eks-node"
  }
}

# --- Outputs ---

output "cluster_name" {
  value = aws_eks_cluster.eks.name
}
output "cluster_endpoint" {
  value = aws_eks_cluster.eks.endpoint
}
output "node_role_arn" {
  value = aws_iam_role.eks_node_role.arn
}

