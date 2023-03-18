#!/bin/bash
set -euo pipefail

# Variables
PREFIX="cloud01"

# KeyPair
aws ec2 create-key-pair \
	--key-name ${PREFIX}-key \
	--query "KeyMaterial" \
	--output text > ${PREFIX}-key.pem