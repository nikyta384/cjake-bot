# IAM roles/policies for CodeBuild & CodePipeline & ECS Task Execution minimally required
resource "aws_iam_role" "codebuild_role" {
  name               = "${var.project_prefix}-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
}


data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}


resource "aws_iam_role_policy_attachment" "codebuild_policy_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}


# allow CodeBuild to create logs and interact with ECR & S3
resource "aws_iam_role_policy_attachment" "codebuild_cloudwatch" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}


resource "aws_iam_role" "codepipeline_role" {
  name               = "${var.project_prefix}-codepipeline-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume.json
}


data "aws_iam_policy_document" "codepipeline_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}


# attach managed policies as needed (minimal example)
resource "aws_iam_role_policy_attachment" "codepipeline_attach_s3" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}


# ECS task execution role for pulling images from ECR
resource "aws_iam_role" "ecs_task_exec" {
  name               = "${var.project_prefix}-ecs-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}


data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}


resource "aws_iam_role_policy_attachment" "ecs_task_exec_policy_attach" {
  role       = aws_iam_role.ecs_task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "codedeploy_role" {
  name               = "${var.project_prefix}-codedeploy-role"
  assume_role_policy = data.aws_iam_policy_document.codedeploy_assume.json
}

data "aws_iam_policy_document" "codedeploy_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "codedeploy_attach" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

resource "aws_iam_policy" "codepipeline_codestar_connection" {
  name        = "${var.project_prefix}-codepipeline-codestar-connection"
  description = "Allow CodePipeline to use the CodeStar connection"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "codestar-connections:UseConnection"
        ]
        Resource = data.aws_codestarconnections_connection.github.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codepipeline_codestar_attach" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_codestar_connection.arn
}

resource "aws_iam_policy" "codepipeline_codebuild" {
  name        = "${var.project_prefix}-codepipeline-codebuild"
  description = "Allow CodePipeline to start CodeBuild projects"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codebuild:*",
        ]
        Resource = aws_codebuild_project.build.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codepipeline_codebuild_attach" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_codebuild.arn
}

resource "aws_iam_policy" "codebuild_s3_access" {
  name        = "${var.project_prefix}-codebuild-s3-access"
  description = "Allow CodeBuild to access pipeline S3 artifacts"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = "${aws_s3_bucket.artifact_store.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_s3_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_s3_access.arn
}

resource "aws_iam_role_policy_attachment" "codepipeline_ecs_full_access" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}


resource "aws_iam_role_policy" "ecs_secret_access" {
  name = "${var.project_prefix}-ecs-secret-access"
  role = aws_iam_role.ecs_task_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Resource = [
          aws_secretsmanager_secret.openai.arn,
          aws_secretsmanager_secret.bot_token.arn,
          aws_secretsmanager_secret.tg_api_id.arn,
          aws_secretsmanager_secret.tg_api_hash.arn,
          aws_secretsmanager_secret.tg_archive_pass.arn
        ]
      }
    ]
  })
}
