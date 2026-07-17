# AWS Enterprise Network & Cloud Active Directory (Samba4 AD DC)

This project is a fully automated cloud network (VPC) in AWS. It simulates a real corporate IT environment. I used Terraform (Infrastructure as Code) to build the infrastructure, and Ansible with GitHub Actions to configure the servers automatically.

The heart of this network is a private Active Directory (Samba4 AD DC) server, safely hidden in a private subnet.

## 🏗️ Network Architecture

The network is divided into two Availability Zones for better reliability. It uses a Zero-Trust security model.

* **VPC (10.128.0.0/16):** The main cloud network.
* **Public Subnets (DMZ):** This is where the NAT and VPN Gateways live. They have public IPs and connect to the internet.
* **Private Subnets (Secure Zone):** This is for internal servers (like the Active Directory) and user computers. They don't have public IPs. They connect to the internet safely through the NAT Gateway.
* **Custom NAT Gateway (EC2):** A Linux server acting as a router to let private machines access the internet.
* **Samba4 AD DC (EC2):** The main Active Directory domain controller (`ls.ege.ds`).
* **Amazon EFS:** A shared network drive connected securely to the AD server.

## 🚀 Key Features

* **Zero-Trust Security (100% Keyless & No Port 22):** Standard SSH is completely disabled. All administrative connections and Ansible deployments use native AWS Systems Manager (SSM) without any SSH keys.
* **Automated DHCP Options:** The AWS network automatically injects the Active Directory's IP as the primary DNS for all machines in the VPC.
* **S3 Remote Backend:** The Terraform state file is safely stored in an AWS S3 bucket. This makes teamwork and CI/CD possible.
* **GitOps Pipeline:** Everything is automated. When I push code to the `main` branch, GitHub Actions automatically deploys the changes.

## 🛣️ Roadmap (What I am building next)

* [x] **DHCP Options Set:** Telling the AWS network to automatically give the AD server's IP as the main DNS to all new machines.
* [ ] **PKI & LDAPS (Port 636):** Setting up a Root CA (Certificate Authority) to encrypt all Active Directory traffic and stop Man-in-the-Middle attacks.
* [ ] **Client-to-Site VPN:** Setting up OpenVPN or WireGuard so remote workers can safely connect to the company network from home.

---

## 👨‍💻 How to test this project

Everything is deployed automatically by GitHub Actions. If you want to see if it works, just check the **Actions** tab in this repository to see the pipeline history.

If you want to run this in your own AWS account, follow these steps:

**1. Prerequisites**
* Fork this repository.
* Create an S3 Bucket in your AWS account.
* ❗ Change the S3 bucket name in `terraform/main.tf` (in the `backend "s3"` block). ❗

**2. GitHub Secrets**
Go to **Settings -> Secrets and variables -> Actions** in your repository and add:

* `AWS_ACCESS_KEY_ID`: Your IAM User Access Key.
* `AWS_SECRET_ACCESS_KEY`: Your IAM User Secret Key.
* `ANSIBLE_VAULT_PASSWORD`: The password used to encrypt the Ansible variables.

**3. Deploy**
Push a new commit to the `main` branch. GitHub Actions will run Terraform and Ansible automatically.

## 🧹 Teardown (Cost Management)

To delete everything and avoid AWS costs, run this locally:

```bash
cd terraform
terraform init
terraform destroy -auto-approve
aws s3 rb s3://<YOUR-BUCKET-NAME> --force
