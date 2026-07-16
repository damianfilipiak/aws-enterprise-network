# AWS Enterprise Network & Cloud Active Directory (Samba4 AD DC)

This project showcases a complete, automated cloud data center (VPC) architecture in AWS, built to simulate real-world corporate IT standards. The infrastructure is designed using the **Infrastructure as Code (IaC)** methodology with **Terraform**, while server provisioning and configuration are fully automated using **Ansible** and **GitHub Actions**.

The core of this network is a private **Active Directory (Samba4 AD DC)** domain controller, securely isolated in a private subnet.

## 🏗️ Network Architecture

The project implements a Multi-AZ architecture with strict network segmentation and a Zero-Trust approach.

* **VPC (10.128.0.0/16):** Divided into two availability zones (`eu-central-1a` and `eu-central-1b`).
* **Public Subnets (DMZ):** Contain the NAT/VPN Gateway. These machines have public IPs and access to the Internet Gateway.
* **Private Subnets (Secure Zone):** Host internal servers (like the AD controller and Office Simulator VMs). They have no public IP addresses. Outbound internet access is routed exclusively through the NAT Gateway.
* **Custom NAT Gateway (EC2):** Acts as a software router (IP Masquerade via iptables) with AWS `source_dest_check` disabled to allow routing for private subnets.
* **Samba4 AD DC (EC2):** A private server running the Active Directory domain controller role (`ls.ege.ds`).
* **Amazon EFS:** A network file system mounted directly on the domain controller via a secure TLS tunnel.

## 🛠️ Technologies Used

* **Cloud Provider:** Amazon Web Services (VPC, EC2, EFS, IAM, Systems Manager - SSM, S3)
* **Infrastructure as Code:** Terraform (with S3 Remote Backend)
* **Configuration Management:** Ansible & Ansible Vault (for secret encryption)
* **CI/CD Automation:** GitHub Actions (GitOps flow)
* **Core Service:** Samba4 AD DC on Ubuntu Server 22.04 LTS

## 🚀 Key Features

* **Zero-Trust Access (No Port 22):** Traditional SSH access is completely disabled. All administrative connections and Ansible playbooks are executed securely through AWS Systems Manager (SSM) Session Manager.
* **S3 Remote State Backend:** The Terraform `.tfstate` is securely hosted in an S3 bucket, allowing for seamless team collaboration and CI/CD consistency.
* **Automated GitOps Pipeline:** Infrastructure modifications and software provisioning are strictly handled by GitHub Actions upon merging to the `main` branch.

## 🛣️ Future Roadmap

* [ ] **DHCP Options Set (In Progress):** Configuring the AWS VPC to automatically assign the Active Directory's IP as the primary DNS server for all newly launched internal instances.
* [ ] **Client-to-Site VPN (OpenVPN/WireGuard):** Implementing a Remote Access VPN on the DMZ Gateway to allow off-site employees secure, encrypted access to the internal Active Directory and enterprise EFS storage.
* [ ] **Automated Domain Join:** Creating scripts for new EC2 instances to automatically join the `ls.ege.ds` domain upon boot.

---

## 👨‍💻 How to test this project

The deployment of this architecture is fully automated via GitHub Actions. If you simply want to verify the functionality, please check the **Actions** tab in this repository to see the successful pipeline runs. 

If you want to deploy this infrastructure in your own AWS account, please follow these steps:

**1. Prerequisites**
* Fork this repository to your own GitHub account.
* Create an S3 Bucket in your AWS account to hold the Terraform state.
* ❗ Update the S3 bucket name in `terraform/main.tf` (in the `backend "s3"` block). ❗

**2. Configure GitHub Secrets**
Go to your forked repository's **Settings -> Secrets and variables -> Actions** and add the following repository secrets:

* `AWS_ACCESS_KEY_ID`: Your IAM User Access Key (Ensure this user has sufficient permissions, e.g., AdministratorAccess for testing).
* `AWS_SECRET_ACCESS_KEY`: Your IAM User Secret Key.
* `SSH_PRIVATE_KEY`: A generated RSA private key for the SSM tunnel. 
  *(Don't have one? Generate it locally using: `ssh-keygen -t rsa -b 4096 -f ./id_rsa` and copy the contents of the `id_rsa` file).*
* `ANSIBLE_VAULT_PASSWORD`: A custom password string used to decrypt the Ansible Active Directory credentials. Make sure it matches the password you used to encrypt your `!vault |` blocks.

**3. Trigger Deployment**
Once the secrets are in place, simply push a commit to the `main` branch. The GitHub Actions pipeline will automatically initialize Terraform, provision the AWS environment, establish an SSM tunnel, and configure the Active Directory via Ansible.

## 🧹 Teardown (Cost Management)

To destroy the environment and avoid AWS charges, execute the following locally (assuming your local Terraform is initialized with your S3 backend):

cd terraform
terraform destroy -auto-approve
aws s3 rb s3://<YOUR-BUCKET-NAME> --force
