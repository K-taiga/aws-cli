#!/bin/bash
set -euo pipefail

# Variables
PREFIX="cloud01"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text) && echo $ACCOUNT_ID
RDS_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${PREFIX}-rds-sg" --query "SecurityGroups[*].GroupId" --output text) && echo $RDS_SECURITY_GROUP_ID
VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=${PREFIX}-vpc --query "Vpcs[*].VpcId" --output text) && echo $VPC_ID

## VPC
# Private subnet
PRIVATE_SUBNET_1a_ID=$(aws ec2 create-subnet \
	--vpc-id $VPC_ID \
	--cidr-block 10.0.21.0/24 \
	--availability-zone ap-northeast-1a \
	--tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PREFIX}-private-subnet-1a}]" \
	--query "Subnet.SubnetId" --output text) && echo $PRIVATE_SUBNET_1a_ID

PRIVATE_SUBNET_1c_ID=$(aws ec2 create-subnet \
	--vpc-id $VPC_ID \
	--cidr-block 10.0.22.0/24 \
	--availability-zone ap-northeast-1c \
	--tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PREFIX}-private-subnet-1c}]" \
	--query "Subnet.SubnetId" --output text) && echo $PRIVATE_SUBNET_1c_ID

# Private routeTable
PRIVATE_ROUTE_TABLE_ID=$(aws ec2 create-route-table \
	--vpc-id $VPC_ID \
	--tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PREFIX}-private-route}]" \
	--query "RouteTable.RouteTableId" --output text) && echo $PRIVATE_ROUTE_TABLE_ID

aws ec2 associate-route-table \
	--route-table-id $PRIVATE_ROUTE_TABLE_ID \
	--subnet-id $PRIVATE_SUBNET_1a_ID

aws ec2 associate-route-table \
	--route-table-id $PRIVATE_ROUTE_TABLE_ID \
	--subnet-id $PRIVATE_SUBNET_1c_ID

## RDS
# Subnet group
aws rds create-db-subnet-group \
	--db-subnet-group-name ${PREFIX}-subnet-group \
	--db-subnet-group-description ${PREFIX}-subnet-group \
	--subnet-ids $PRIVATE_SUBNET_1a_ID $PRIVATE_SUBNET_1c_ID

# Parameter group
aws rds create-db-parameter-group \
	--db-parameter-group-name ${PREFIX}-parameter-group \
	--description ${PREFIX}-parameter-group \
	--db-parameter-group-family mysql8.0

# Enable export logs
aws rds modify-db-parameter-group \
	--db-parameter-group-name ${PREFIX}-parameter-group \
	--parameters \
	ParameterName=general_log,ParameterValue=1,ApplyMethod=immediate \
	ParameterName=slow_query_log,ParameterValue=1,ApplyMethod=immediate \
	ParameterName=long_query_time,ParameterValue=0,ApplyMethod=immediate \
	ParameterName=log_output,ParameterValue=FILE,ApplyMethod=immediate

# Option group
aws rds create-option-group \
	--option-group-name ${PREFIX}-option-group \
	--option-group-description ${PREFIX}-option-group \
	--engine-name mysql \
	--major-engine-version 8.0

aws rds add-option-to-option-group \
	--option-group-name ${PREFIX}-option-group \
	--options "OptionName=MEMCACHED,Port=11211,VpcSecurityGroupMemberships=$RDS_SECURITY_GROUP_ID, \
	OptionSettings=[{Name=BACKLOG_QUEUE_LIMIT,Value=1024},{Name=BINDING_PROTOCOL,Value=auto}]" \
	--apply-immediately

# DB instance
aws rds create-db-instance \
	--engine mysql \
	--engine-version 8.0.20 \
	--db-instance-identifier ${PREFIX}-db-instance \
	--master-username root \
	--master-user-password password \
	--db-instance-class db.t3.medium \
	--storage-type gp2 \
	--allocated-storage 20 \
	--max-allocated-storage 100 \
	--multi-az \
	--db-subnet-group-name ${PREFIX}-subnet-group \
	--no-publicly-accessible \
	--vpc-security-group-ids $RDS_SECURITY_GROUP_ID \
	--port 3306 \
	--no-enable-iam-database-authentication \
	--db-name cloud \
	--db-parameter-group-name ${PREFIX}-parameter-group \
	--option-group-name ${PREFIX}-option-group \
	--backup-retention-period 7 \
	--preferred-backup-window "19:00-20:00" \
	--copy-tags-to-snapshot \
	--storage-encrypted \
	--enable-performance-insights \
	--performance-insights-retention-period 7 \
	--monitoring-interval 60 \
	--monitoring-role-arn arn:aws:iam::${ACCOUNT_ID}:role/rds-monitoring-role \
	--enable-cloudwatch-logs-exports "error" "general" "slowquery" \
	--no-auto-minor-version-upgrade \
	--preferred-maintenance-window "Sat:20:00-Sat:21:00" \
	--deletion-protection

# SSH connection to EC2
cd ~/environment/cloud01-aws-cli/02.ec2/
EC2_NAME="${PREFIX}-web-01"
INSTANCE_ID=$(aws ec2 describe-instances --filter Name=tag:Name,Values=$EC2_NAME Name=instance-state-name,Values=running --query "Reservations[*].Instances[*].InstanceId" --output text) && echo $INSTANCE_ID
PUBLIC_IP_ADDRESS=$(aws ec2 describe-instances --instance-id $INSTANCE_ID --query "Reservations[*].Instances[*].PublicIpAddress" --output text) && echo $PUBLIC_IP_ADDRESS
ssh -i cloud01-key.pem ec2-user@$PUBLIC_IP_ADDRESS

# RDS connection test
RDS_ENDPOINT=$(aws rds describe-db-instances \
	--region ap-northeast-1 \
	--db-instance-identifier cloud01-db-instance \
	--query "DBInstances[*].Endpoint.Address" --output text) && echo $RDS_ENDPOINT

mysql -h $RDS_ENDPOINT -u root -p

