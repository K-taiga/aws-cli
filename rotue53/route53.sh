#!/bin/bash
set -euo pipefail

# Variables
MY_DOMAIN="cloud01.work"

## Route53 hosted zone
HOSTED_ZONE_ID=$(aws route53 create-hosted-zone \
	--name $MY_DOMAIN \
	# お決まりの形,複数誤って作成しないため
	--caller-reference "$(date +%Y-%m-%d_%H-%M-%S)" \
	--query "HostedZone.Id" --output text) && echo $HOSTED_ZONE_ID

## Get NS records
aws route53 list-resource-record-sets \
	--hosted-zone-id $HOSTED_ZONE_ID \
	--query 'ResourceRecordSets[?Type==`NS`].ResourceRecords[*].Value'

# ACM
CERTIFICATE_ARN=$(aws acm request-certificate \
	# サブドメインにも対応できるようにワイルドカード証明書としてリクエスト
	--domain-name *.${MY_DOMAIN} \
	# ドメインの検証方法
	--validation-method DNS \
	--query "CertificateArn" --output text) && echo $CERTIFICATE_ARN

VALIDATION_RECORD_NAME=$(aws acm describe-certificate \
	--certificate-arn $CERTIFICATE_ARN \
	--query "Certificate.DomainValidationOptions[*].ResourceRecord.Name" --output text) && echo $VALIDATION_RECORD_NAME

VALIDATION_RECORD_VALUE=$(aws acm describe-certificate \
	--certificate-arn $CERTIFICATE_ARN \
	--query "Certificate.DomainValidationOptions[*].ResourceRecord.Value" --output text) && echo $VALIDATION_RECORD_VALUE

## DNS validation
# Update Record sets file
VALIDATION_RECORD_FILE=./recordsets/dnsvalidation.json
# -iで上書き保存
sed -i -e "s/%VALIDATION_RECORD_NAME%/$VALIDATION_RECORD_NAME/" $VALIDATION_RECORD_FILE
sed -i -e "s/%VALIDATION_RECORD_VALUE%/$VALIDATION_RECORD_VALUE/" $VALIDATION_RECORD_FILE

# Add record sets
aws route53 change-resource-record-sets \
	--hosted-zone-id $HOSTED_ZONE_ID \
	--change-batch file://$VALIDATION_RECORD_FILE

# Initialize
git restore $VALIDATION_RECORD_FILE

## ELB alias
MY_DOMAIN="cloud01.work"
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name==\`${MY_DOMAIN}.\`].Id" --output text) && echo $HOSTED_ZONE_ID

PREFIX="cloud01"
ELB_NAME="${PREFIX}-alb"
FQDN="www.${MY_DOMAIN}"
ELB_HOSTED_ZONE_ID=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?LoadBalancerName==\`$ELB_NAME\`].CanonicalHostedZoneId" --output text) && echo $ELB_HOSTED_ZONE_ID
ELB_DNS_NAME=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?LoadBalancerName==\`$ELB_NAME\`].DNSName" --output text) && echo $ELB_DNS_NAME

# Update record sets file
ELB_RECORD_FILE=./recordsets/elb.json
sed -i -e "s/%FQDN%/$FQDN/" $ELB_RECORD_FILE
sed -i -e "s/%ELB_HOSTED_ZONE_ID%/$ELB_HOSTED_ZONE_ID/" $ELB_RECORD_FILE
sed -i -e "s/%ELB_DNS_NAME%/$ELB_DNS_NAME/" $ELB_RECORD_FILE

# Add record sets
aws route53 change-resource-record-sets \
	--hosted-zone-id $HOSTED_ZONE_ID \
	--change-batch file://$ELB_RECORD_FILE

# Initialize
git restore $ELB_RECORD_FILE