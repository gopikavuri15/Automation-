#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo 'Run this script with sudo.' >&2
  exit 1
fi

apt-get update
apt-get install -y ca-certificates curl fontconfig openjdk-21-jre
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | gpg --dearmor --yes -o /etc/apt/keyrings/jenkins.gpg
chmod 0644 /etc/apt/keyrings/jenkins.gpg
printf 'deb [signed-by=/etc/apt/keyrings/jenkins.gpg] https://pkg.jenkins.io/debian-stable binary/\n' > /etc/apt/sources.list.d/jenkins.list
apt-get update
apt-get install -y jenkins
systemctl enable --now jenkins
systemctl --no-pager --full status jenkins
printf '\nInitial admin password: sudo cat /var/lib/jenkins/secrets/initialAdminPassword\n'