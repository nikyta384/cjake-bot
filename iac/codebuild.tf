

data "aws_codestarconnections_connection" "github" {
  name = var.codestar_connection_name
}

resource "aws_codebuild_project" "build" {
  name         = "${var.project_prefix}-build"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_MEDIUM"
    image           = "aws/codebuild/standard:6.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
    environment_variable {
      name  = "ECR_REPO_URI"
      value = aws_ecr_repository.app.repository_url
    }
  }

  source {
    type      = "CODEPIPELINE"
  }
}
