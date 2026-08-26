output "github_actions_role_arn" {
  description = "ARN a usar en el workflow de GitHub Actions (permissions: id-token: write + role-to-assume)"
  value       = aws_iam_role.github_actions.arn
}
