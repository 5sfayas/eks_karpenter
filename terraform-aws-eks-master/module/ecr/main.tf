resource "aws_ecr_repository" "foo" {
  name                 = "${var.cluster_name}-test-1-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}