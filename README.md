# DevOps Monitoring and Automation Tool

A small, interview-ready delivery and monitoring project for Ubuntu on AWS EC2. GitHub is the source of truth, Jenkins checks out/builds/tests/deploys the application, Nginx serves it on HTTP, and Prometheus plus Node Exporter feed host metrics to Grafana.

Every component runs directly on Ubuntu and is managed with systemd. The application uses Node.js built-ins only, so there are no application packages to fetch during the build.

## Architecture

```text
Developer -> GitHub -> Jenkins (same EC2 host)
                          | checkout / build / test
                          | publish release / restart / health check
                          v
                    Ubuntu EC2
                      | Nginx :80 -> app :3001 (loopback)
                      | Node Exporter :9100 (loopback scrape)
                      | Prometheus :9090
                      | Grafana :3000 -> Prometheus
```

Jenkins deploys locally to `/opt/devops-monitoring` on its Ubuntu agent. The release directory is replaced via an atomic `current` symlink update, then the `devops-app` systemd service restarts. Prometheus scrapes Node Exporter on the same host. Grafana's provisioned data source and dashboard are ready after services start.

## Repository structure

```text
.
├── .gitignore
├── Jenkinsfile
├── README.md
├── app/
│   ├── package.json
│   ├── package-lock.json
│   ├── public/
│   │   └── index.html
│   ├── scripts/
│   │   └── build.js
│   ├── src/
│   │   └── server.js
│   └── test/
│       └── server.test.js
├── config/
│   ├── grafana/
│   │   ├── dashboards/
│   │   │   └── node-exporter.json
│   │   └── provisioning/
│   │       ├── dashboards/
│   │       │   └── dashboard.yml
│   │       └── datasources/
│   │           └── prometheus.yml
│   ├── nginx/
│   │   └── devops-app
│   ├── prometheus/
│   │   └── prometheus.yml
│   └── systemd/
│       ├── devops-app.service
│       ├── node-exporter.service
│       └── prometheus.service
└── scripts/
  ├── deploy-app.sh
  ├── health-check.sh
  ├── install-app-service.sh
  ├── install-grafana.sh
  ├── install-jenkins.sh
  ├── install-node-exporter.sh
  ├── install-nodejs.sh
  └── install-prometheus.sh
```

## Prerequisites

- AWS account and an Ubuntu 22.04/24.04 EC2 instance, 2 vCPU and 4 GiB RAM recommended for the full stack.
- An SSH key and a GitHub repository containing this project.
- A DNS name pointing at the instance is recommended for TLS termination; this sample serves HTTP only.
- An administrator account with `sudo` access for initial installation.
- Jenkins and the application run on the same EC2 host in this simple deployment model.

### EC2 security group

Create inbound rules with source ranges restricted to your own IP or trusted network wherever possible:

| Port | Protocol | Purpose | Suggested source |
| --- | --- | --- | --- |
| 22 | TCP | SSH administration | Your public IP `/32` |
| 80 | TCP | Nginx application | Public users or trusted range |
| 8080 | TCP | Jenkins UI and webhook | Your public IP `/32` or GitHub webhook ranges |
| 9090 | TCP | Prometheus UI | Your public IP `/32` only |
| 3000 | TCP | Grafana UI | Your public IP `/32` or trusted network |

Node Exporter port `9100` and application port `3001` are bound to loopback and do not need public ingress rules. Do not expose them broadly. For a real deployment, keep monitoring and Jenkins interfaces private or place them behind VPN/SSM and TLS-capable reverse proxies.

## Installation

SSH to the instance and install the base utilities:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg git nginx
```

Clone the repository (replace the URL with your own):

```bash
git clone https://github.com/OWNER/REPOSITORY.git
cd REPOSITORY
```

Install Node.js 20, Jenkins, and the application systemd unit:

```bash
sudo bash scripts/install-nodejs.sh
sudo bash scripts/install-jenkins.sh
sudo bash scripts/install-app-service.sh
```

Install and enable the monitoring stack:

```bash
sudo bash scripts/install-node-exporter.sh
sudo bash scripts/install-prometheus.sh
sudo bash scripts/install-grafana.sh
```

Install the Nginx site and deploy the first release:

```bash
sudo install -m 0644 config/nginx/devops-app /etc/nginx/sites-available/devops-app
sudo ln -sfn /etc/nginx/sites-available/devops-app /etc/nginx/sites-enabled/devops-app
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

The installers enable their corresponding services. Jenkins makes the first application release when you run the pipeline after completing Jenkins configuration below. Check monitoring service status and endpoints:

```bash
systemctl --no-pager --full status jenkins nginx node-exporter prometheus grafana-server
curl -fsS http://127.0.0.1:9090/-/ready
curl -fsS http://127.0.0.1:9100/metrics | head
```

After the first successful Jenkins run, verify the application with `curl -fsS http://127.0.0.1/health` and `systemctl status devops-app`.

## Jenkins configuration

1. Open `http://EC2_PUBLIC_IP:8080` from an allowed IP. Retrieve the initial password with `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`, complete the setup wizard, and install suggested plugins including Pipeline and Git.
2. Create a Pipeline job and select **Pipeline script from SCM**. Set SCM to Git, enter the repository URL and credentials if private, and set the script path to `Jenkinsfile`.
3. Give the `jenkins` account permission to restart only this application service:

   ```bash
   echo 'jenkins ALL=(root) NOPASSWD: /usr/bin/systemctl restart devops-app.service' | sudo tee /etc/sudoers.d/jenkins-devops-app
   sudo chmod 0440 /etc/sudoers.d/jenkins-devops-app
   sudo visudo -cf /etc/sudoers.d/jenkins-devops-app
   ```

4. Ensure the Jenkins user can write application releases and read the checkout. The application installer creates `/opt/devops-monitoring/releases` with the `jenkins` account as owner. Jenkins checks out the repo under its workspace and deploys with the included script.
5. Run **Build Now**. Optionally configure a GitHub webhook to `http://EC2_PUBLIC_IP:8080/github-webhook/` and enable the GitHub hook trigger.

The pipeline performs checkout, `npm ci`, build, tests, release deployment, systemd restart, and an HTTP health check. Failed stages stop later deployment actions. The pipeline assumes a Linux Jenkins agent on the target EC2 instance; for a separate controller/agent layout, run the deployment stage on an agent attached to this host.

## Prometheus configuration

`config/prometheus/prometheus.yml` defines a local Prometheus scrape job for Node Exporter at `127.0.0.1:9100`, with a 15-second scrape interval. The install script downloads a pinned upstream release, installs its binaries and configuration, and registers the included systemd unit.

Verify scraping at `http://EC2_PUBLIC_IP:9090/targets` from an allowed source. The `node` target should show **UP**. Prometheus uses local file-based time-series storage at `/var/lib/prometheus`.

## Grafana configuration

Open `http://EC2_PUBLIC_IP:3000` from an allowed source. The package's initial login is `admin` / `admin`; change it immediately. Provisioning config registers Prometheus at `http://127.0.0.1:9090` and loads the **EC2 Node Exporter** dashboard automatically.

The dashboard includes CPU utilization, memory utilization, root filesystem utilization, received/transmitted network rates, and system uptime. It uses standard Node Exporter metric names and refreshes every 30 seconds.

## Deployment process

Each Jenkins run builds/tests in the checkout, copies `app/dist` to a timestamped directory under `/opt/devops-monitoring/releases`, switches the `current` symlink, restarts `devops-app.service`, then polls `/health`. The app listens only on `127.0.0.1:3001`; Nginx forwards public HTTP traffic and exposes `/health` for the pipeline. Previous timestamped release directories remain available for manual rollback by repointing `current` and restarting the service.

## Troubleshooting

- **Jenkins cannot restart the app:** validate `/etc/sudoers.d/jenkins-devops-app` with `visudo -cf`; confirm the exact systemctl path with `command -v systemctl` and adjust the rule if needed.
- **Deployment gets permission denied:** confirm `/opt/devops-monitoring/releases` is writable by `jenkins`, and the Jenkins job runs on the target host.
- **Health check fails:** inspect `sudo journalctl -u devops-app -n 100 --no-pager`, then `sudo nginx -t` and `sudo journalctl -u nginx -n 100 --no-pager`.
- **Prometheus target is down:** inspect `sudo systemctl status node-exporter prometheus`, `sudo journalctl -u node-exporter -u prometheus -n 100 --no-pager`, and verify the scrape target is `127.0.0.1:9100`.
- **Grafana has no data:** confirm Prometheus target state at `/targets`, then check `sudo journalctl -u grafana-server -n 100 --no-pager` and the data source provisioning file under `/etc/grafana/provisioning/datasources`.
- **Cannot connect from outside:** check the EC2 security group, subnet network ACL, instance public address, and host firewall. Do not open port `9100` to the internet.
- **Systemd unit changes do not take effect:** run `sudo systemctl daemon-reload`, then restart the relevant service.

## Interview walkthrough

- **GitHub** provides versioned source and the trigger point for continuous integration.
- **Jenkins** makes the build reproducible, runs tests before deployment, and automates service restart and health verification.
- **Node.js application** is intentionally dependency-free; the HTTP server exposes a health endpoint and a status API.
- **Nginx** is the public reverse proxy. It keeps the application bound to loopback and gives the deployment pipeline a stable health-check URL.
- **systemd** supervises the app and monitoring services, restarts failed processes, and integrates logs with `journalctl`.
- **Node Exporter** exposes host CPU, memory, filesystem, network, and boot-time counters.
- **Prometheus** scrapes and stores time-series metrics locally; its PromQL expressions calculate useful utilization and rates.
- **Grafana** visualizes Prometheus data through provisioned configuration so dashboards can be reproduced from source control.

Operational improvements to discuss: TLS and a domain, Jenkins credentials and least-privilege deployment, private monitoring access, backups/retention policy, alert rules and Alertmanager, release cleanup, and a separate Jenkins agent for larger deployments.