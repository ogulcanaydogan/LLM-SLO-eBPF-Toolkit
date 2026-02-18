output "instance_id" {
  description = "EC2 instance ID for the ephemeral runner host"
  value       = aws_instance.runner.id
}

output "instance_private_ip" {
  description = "Private IP address of the runner host"
  value       = aws_instance.runner.private_ip
}

output "ssm_start_session" {
  description = "Command to open an SSM shell session"
  value       = "aws ssm start-session --target ${aws_instance.runner.id} --region ${var.aws_region}"
}

output "validation_runner_labels" {
  description = "Expected runner labels in GitHub"
  value       = ["self-hosted", "linux", "ebpf"]
}

output "validation_gh_command" {
  description = "GitHub API command to verify runner status"
  value       = "gh api repos/${var.github_repository}/actions/runners --jq '.runners[] | {name,status,labels:[.labels[].name]}'"
}
