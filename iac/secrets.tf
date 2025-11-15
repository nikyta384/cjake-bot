resource "aws_secretsmanager_secret" "openai" {
  name = "${var.project_prefix}-openai-api-key"
  recovery_window_in_days = 0 # This enables immediate deletion
}

resource "aws_secretsmanager_secret_version" "openai_version" {
  secret_id     = aws_secretsmanager_secret.openai.id
  secret_string = var.openai_api_key
}


resource "aws_secretsmanager_secret" "bot_token" {
  name = "${var.project_prefix}-bot-token"
  recovery_window_in_days = 0 # This enables immediate deletion
}

resource "aws_secretsmanager_secret_version" "bot_token_version" {
  secret_id     = aws_secretsmanager_secret.bot_token.id
  secret_string = var.bot_token
}


resource "aws_secretsmanager_secret" "tg_api_id" {
  name = "${var.project_prefix}-tg-api-id"
  recovery_window_in_days = 0 # This enables immediate deletion
}

resource "aws_secretsmanager_secret_version" "tg_api_id_version" {
  secret_id     = aws_secretsmanager_secret.tg_api_id.id
  secret_string = var.tg_api_id
}

resource "aws_secretsmanager_secret" "tg_api_hash" {
  name = "${var.project_prefix}-tg-api-hash"
  recovery_window_in_days = 0 # This enables immediate deletion
}

resource "aws_secretsmanager_secret_version" "tg_api_hash_version" {
  secret_id     = aws_secretsmanager_secret.tg_api_hash.id
  secret_string = var.tg_api_hash
}

resource "aws_secretsmanager_secret" "tg_archive_pass" {
  name = "${var.project_prefix}-tg-archive-pass"
  recovery_window_in_days = 0 # This enables immediate deletion
}

resource "aws_secretsmanager_secret_version" "tg_archive_pass_version" {
  secret_id     = aws_secretsmanager_secret.tg_archive_pass.id
  secret_string = var.tg_archive_pass
}