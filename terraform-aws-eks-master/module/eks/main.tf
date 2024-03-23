# IAM Role for EKS cluster (replace with your policy document)
resource "aws_iam_role" "cluster_role" {
  name = "eks-cluster-role-${var.environment}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


resource "aws_eks_cluster" "eks_cluster" {
    name            = var.cluster_name
    role_arn        = aws_iam_role.cluster_role.arn

    vpc_config {
        endpoint_private_access = false
        endpoint_public_access  = true
        public_access_cidrs     = ["0.0.0.0/0"]
        subnet_ids = var.subnet_id
  }
}


# IAM Role for Node controller (replace with your policy document)
resource "aws_iam_role" "node_role" {
  name = "eks-node-group-role-${var.environment}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "node_role_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "node_role_policy2" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
resource "aws_iam_role_policy_attachment" "node_role_policy3" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_eks_node_group" "eks_node" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "eks_private_nodes"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = var.subnet_id

  capacity_type  = "ON_DEMAND"
  instance_types = ["t3a.medium"]

  scaling_config {
    desired_size = 1
    max_size     = 10
    min_size     = 0
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "general"
  }

  depends_on = [ 
        aws_iam_role_policy_attachment.node_role_policy3,
        aws_iam_role_policy_attachment.node_role_policy2,
        aws_iam_role_policy_attachment.node_role_policy 
    ]

   lifecycle {
        ignore_changes = [scaling_config[0].desired_size]
    }

}

# Create Karpenter Controller for AutoScale

# IAM roles for service accounts to to grant access to internal service
data "tls_certificate" "eks_tls_certificate" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_oid_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_tls_certificate.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

data "aws_iam_policy_document" "karpenter_controller_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks_oid_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:karpenter:karpenter"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks_oid_provider.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "karpenter_controller_role" {
  name               = "karpenter-controller-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_assume_role_policy.json
}

resource "aws_iam_policy" "karpenter_controller_iam_policy" {
  name   = "KarpenterController-${var.environment}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "KarpenterCreateEC2",
      "Effect": "Allow",
      "Action": [
          "ssm:GetParameter",
          "iam:PassRole",
          "ec2:RunInstances",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateTags",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:DescribeSpotPriceHistory"
      ],
      "Resource": "*"
    },
    {
      "Sid": "KarpenterConditionalEC2Termination",
      "Effect": "Allow",
      "Action": "ec2:TerminateInstances",
      "Resource": "*",
      "Condition": {
          "StringLike": {
            "ec2:ResourceTag/Name": "*karpenter*"
          }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_iam_policy_attach" {
  role       = aws_iam_role.karpenter_controller_role.name
  policy_arn = aws_iam_policy.karpenter_controller_iam_policy.arn
}

resource "aws_iam_instance_profile" "karpenter_node_instance_profile" {
  name = "Karpenter-Node-InstanceProfile-${var.environment}"
  role = aws_iam_role.node_role.name
}

data "aws_eks_cluster_auth" "cluster-auth" {
  depends_on = [aws_eks_cluster.eks_cluster]
  name       = aws_eks_cluster.eks_cluster.name
}

# Create Karpetner controller
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.eks_cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster-auth.token

    # exec {
    #   api_version = "client.authentication.k8s.io/v1beta1"
    #   args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.eks_cluster.id]
    #   command     = "aws"
    # }
  }
}

resource "helm_release" "deploy_karpenter_controller" {
  namespace        = "karpenter"
  create_namespace = true

  name       = "karpenter"
  repository = "https://charts.karpenter.sh"
  chart      = "karpenter"
  version    = "v0.16.3"

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.karpenter_controller_role.arn
  }

  set {
    name  = "clusterName"
    value = aws_eks_cluster.eks_cluster.id
  }

  set {
    name  = "clusterEndpoint"
    value = aws_eks_cluster.eks_cluster.endpoint
  }

  set {
    name  = "aws.defaultInstanceProfile"
    value = aws_iam_instance_profile.karpenter_node_instance_profile.name
  }

  depends_on = [
    aws_eks_node_group.eks_node,
    aws_eks_cluster.eks_cluster
  ]
}
