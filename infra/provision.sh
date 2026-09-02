#!/bin/bash
# Provision the AWS infrastructure for the three-tier app CI/CD project.
# Creates: key pair, two security groups, and two t3.micro EC2 instances
# (jenkins-server, app-server) in the default VPC, us-east-1.
#
# Usage: MY_IP=<your-public-ip> ./provision.sh
set -euo pipefail

REGION=us-east-1
AMI=ami-0d7f022123f8ff19d   # Canonical Ubuntu 24.04 LTS amd64 (via SSM public parameter)
TYPE=t3.micro
KEY_NAME=devops-key
KEY_FILE="$HOME/.ssh/${KEY_NAME}.pem"
MY_IP="${MY_IP:?Set MY_IP to your public IP, e.g. MY_IP=1.2.3.4 ./provision.sh}"

# --- Key pair ---
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region $REGION >/dev/null 2>&1; then
  aws ec2 create-key-pair --key-name "$KEY_NAME" --key-type ed25519 \
    --query 'KeyMaterial' --output text --region $REGION > "$KEY_FILE"
  chmod 400 "$KEY_FILE"
  echo "Key pair saved to $KEY_FILE"
fi

VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true \
  --query 'Vpcs[0].VpcId' --output text --region $REGION)

# --- Security groups ---
JENKINS_SG=$(aws ec2 create-security-group --group-name jenkins-sg \
  --description "Jenkins server: SSH from admin IP, 8080 for UI+webhooks" \
  --vpc-id "$VPC_ID" --query GroupId --output text --region $REGION)
aws ec2 authorize-security-group-ingress --group-id "$JENKINS_SG" --region $REGION \
  --protocol tcp --port 22 --cidr "${MY_IP}/32" >/dev/null
# 8080 open wide so GitHub webhooks can reach Jenkins (UI itself is login-protected)
aws ec2 authorize-security-group-ingress --group-id "$JENKINS_SG" --region $REGION \
  --protocol tcp --port 8080 --cidr 0.0.0.0/0 >/dev/null

APP_SG=$(aws ec2 create-security-group --group-name app-sg \
  --description "App server: SSH from admin IP + Jenkins SG, HTTP public" \
  --vpc-id "$VPC_ID" --query GroupId --output text --region $REGION)
aws ec2 authorize-security-group-ingress --group-id "$APP_SG" --region $REGION \
  --protocol tcp --port 22 --cidr "${MY_IP}/32" >/dev/null
aws ec2 authorize-security-group-ingress --group-id "$APP_SG" --region $REGION \
  --protocol tcp --port 22 --source-group "$JENKINS_SG" >/dev/null
aws ec2 authorize-security-group-ingress --group-id "$APP_SG" --region $REGION \
  --protocol tcp --port 80 --cidr 0.0.0.0/0 >/dev/null

echo "jenkins-sg=$JENKINS_SG app-sg=$APP_SG vpc=$VPC_ID"

# --- Instances ---
launch() {
  local name=$1 sg=$2 userdata=$3
  aws ec2 run-instances --region $REGION \
    --image-id $AMI --instance-type $TYPE --key-name "$KEY_NAME" \
    --security-group-ids "$sg" \
    --user-data "file://$userdata" \
    --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=12,VolumeType=gp3}' \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$name},{Key=Project,Value=three-tier-devops}]" \
    --query 'Instances[0].InstanceId' --output text
}

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
JENKINS_ID=$(launch jenkins-server "$JENKINS_SG" "$SCRIPT_DIR/jenkins-userdata.sh")
APP_ID=$(launch app-server "$APP_SG" "$SCRIPT_DIR/app-userdata.sh")
echo "jenkins-server=$JENKINS_ID app-server=$APP_ID"

aws ec2 wait instance-running --instance-ids "$JENKINS_ID" "$APP_ID" --region $REGION
aws ec2 describe-instances --instance-ids "$JENKINS_ID" "$APP_ID" --region $REGION \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,InstanceId,PublicIpAddress]' \
  --output table
