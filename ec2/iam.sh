#!/bin/bash
set -euo pipefail

# Variables
PREFIX="cloud01"
POLICY_ARN="arn:aws:iam::aws:policy/AdministratorAccess"

# IAM Role
aws iam create-role \
	--role-name ${PREFIX}-ec2-role \
	--assume-role-policy-document file://param/AssumeRole.json

aws iam create-instance-profile \
	--instance-profile-name ${PREFIX}-ec2-role

aws iam add-role-to-instance-profile \
	--role-name ${PREFIX}-ec2-role \
	--instance-profile-name ${PREFIX}-ec2-role

aws iam attach-role-policy \
	--policy-arn $POLICY_ARN \
	--role-name ${PREFIX}-ec2-role