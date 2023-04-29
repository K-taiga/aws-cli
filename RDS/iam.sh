#!/bin/bash
set -euo pipefail

# Variables
RDS_ROLE_NAME="rds-monitoring-role"
POLICY_ARN="arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"

# IAM Role
aws iam create-role \
	--role-name $RDS_ROLE_NAME \
	--assume-role-policy-document file://param/AssumeRole.json

aws iam attach-role-policy \
	--policy-arn $POLICY_ARN \
	--role-name $RDS_ROLE_NAME