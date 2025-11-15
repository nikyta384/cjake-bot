variable "aws_region" {
  type    = string
  default = "eu-north-1"
}
variable "aws_region_subnet" {
  type    = string
  default = "eu-north-1a"
}
variable "project_prefix" {
  type    = string
  default = "cjake"
}
variable "github_owner" {
  type    = string
  default = "nikyta384"
}
variable "github_repo" {
  type    = string
  default = "cjake-bot"
}
variable "github_branch" {
  type    = string
  default = "main"
}
variable "codestar_connection_name" {
  type    = string
  default = "nikyta384-github"
}
variable "openai_api_key" {
  description = "Your OpenAI API key"
  type        = string
  sensitive   = true
}

variable "bot_token" {
  description = "Your Telegram bot token"
  type        = string
  sensitive   = true
}

variable "tg_api_id" {
  description = "Your Telegram api id"
  type        = string
  sensitive   = true
}

variable "tg_api_hash" {
  description = "Your Telegram api hash"
  type        = string
  sensitive   = true
}

variable "tg_archive_pass" {
  description = "Your Telegram session archuve password"
  type        = string
  sensitive   = true
}