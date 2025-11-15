resource "aws_ecr_repository" "app" {
  name                 = "${var.project_prefix}-app"
  image_tag_mutability = "MUTABLE"
  tags                 = { project = var.project_prefix }
  force_delete = true
}