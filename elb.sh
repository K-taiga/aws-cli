#!/bin/bash
set -euo pipefail

# Variables
PREFIX="cloud01"
MY_DOMAIN="cloud01.work"
PUBLIC_SUBNET_1a_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=${PREFIX}-public-subnet-1a --query "Subnets[*].SubnetId" --output text) && echo $PUBLIC_SUBNET_1a_ID
PUBLIC_SUBNET_1c_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=${PREFIX}-public-subnet-1c --query "Subnets[*].SubnetId" --output text) && echo $PUBLIC_SUBNET_1c_ID
ELB_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --filters Name=tag:Name,Values=${PREFIX}-elb-sg --query "SecurityGroups[*].GroupId" --output text) && echo $ELB_SECURITY_GROUP_ID
VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=${PREFIX}-vpc --query "Vpcs[*].VpcId" --output text) && echo $VPC_ID
CERTIFICATE_ARN=$(aws acm list-certificates --query "CertificateSummaryList[?DomainName==\`*.$MY_DOMAIN\`].CertificateArn" --output text) && echo $CERTIFICATE_ARN

# ELB
LOAD_BALANCER_ARN=$(aws elbv2 create-load-balancer \
	--name ${PREFIX}-alb  \
	--subnets $PUBLIC_SUBNET_1a_ID $PUBLIC_SUBNET_1c_ID \
	--security-groups $ELB_SECURITY_GROUP_ID \
	# ここでnetworkにするとNLB
	--type application \
	# ここでinternalを選ぶと内部ロードバランサー
	--scheme internet-facing \
	--query "LoadBalancers[*].LoadBalancerArn" --output text) && echo $LOAD_BALANCER_ARN


# TargetGroup
TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
	--name ${PREFIX}-alb-tg \
	# EC2に直接に向けることもできる、その場合はinstance idを指定する
	--target-type ip \
	--protocol HTTP \
	--port 80 \
	--protocol-version HTTP1 \
	--vpc-id $VPC_ID \
	--health-check-protocol HTTP \
	--health-check-path / \
	--health-check-port traffic-port \
	--healthy-threshold-count 5 \
	--unhealthy-threshold-count 2 \
	--health-check-timeout-seconds 5 \
	--health-check-interval-seconds 30 \
	--matcher HttpCode=200 \
	--query "TargetGroups[*].TargetGroupArn" --output text) && echo $TARGET_GROUP_ARN

# Register targets
aws elbv2 register-targets \
	--target-group-arn $TARGET_GROUP_ARN \
	--targets Id=10.0.11.11 Id=10.0.12.11

## Listener
# HTTP
aws elbv2 create-listener \
	--load-balancer-arn $LOAD_BALANCER_ARN \
	--protocol HTTP \
	--port 80 \
	# もとのリクエストを保持してリダイレクトする
	--default-actions 'Type=redirect,RedirectConfig={Protocol=HTTPS,Port=443,Host="#{host}",Path="/#{path}",Query="#{query}",StatusCode=HTTP_301}'

# HTTPS
aws elbv2 create-listener \
	--load-balancer-arn $LOAD_BALANCER_ARN \
	--protocol HTTPS \
	--port 443 \
	--certificates CertificateArn=$CERTIFICATE_ARN \
	--default-actions Type=forward,TargetGroupArn=$TARGET_GROUP_ARN
