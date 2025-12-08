output "master_ip" {
  value = aws_instance.master.public_ip
}

output "worker_ips" {
  value = aws_instance.worker[*].public_ip
}

output "ssh_master" {
  value = "ssh -i jenkins-server-key ec2-user@${aws_instance.master.public_ip}"
}

output "ssh_workers" {
  value = [
    for ip in aws_instance.worker[*].public_ip : "ssh -i jenkins-server-key ec2-user@${ip}"
  ]
}
