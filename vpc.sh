## Variables
PREFIX="cloud01"

## VPCの作成
aws ec2 create-vpc \
	--cidr-block 10.0.0.0/16 \
	--instance-tenancy default \
	--tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${PREFIX}-vpc}]"

VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=${PREFIX}-vpc\
	--query "Vpcs[*].VpcId" --output text)

## InternetGateway
INTERNET_GATEWAY_ID=$(aws ec2 create-internet-gateway \
	--tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${PREFIX}-igw}]" \
	--query "InternetGateway.InternetGatewayId" --output text)

aws ec2 attach-internet-gateway \
	--internet-gateway-id $INTERNET_GATEWAY_ID \
	--vpc-id $VPC_ID

## Public subnet
### 1a
PUBLIC_SUBNET_1a_ID=$(aws ec2 create-subnet \
	--vpc-id $VPC_ID \
	--cidr-block 10.0.11.0/24 \
	--availability-zone ap-northeast-1a \
	--tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PREFIX}-public-subnet-1a}]" \
	--query "Subnet.SubnetId" --output text)

### 1c
PUBLIC_SUBNET_1c_ID=$(aws ec2 create-subnet \
	--vpc-id $VPC_ID \
	--cidr-block 10.0.1.0/24 \
	--availability-zone ap-northeast-1c \
	--tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PREFIX}-public-subnet-1c}]" \
	--query "Subnet.SubnetId" --output text)

## Public route table
PUBLIC_ROUTE_TABLE_ID=$(aws ec2 create-route-table \
	--vpc-id $VPC_ID \
	--tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PREFIX}-public-route}]" \
	--query "RouteTable.RouteTableId" --output text)

aws ec2 create-route \
	--route-table-id $PUBLIC_ROUTE_TABLE_ID \
	--destination-cidr-block 0.0.0.0/0 \
	--gateway-id $INTERNET_GATEWAY_ID

### 1aへのassociate
aws ec2 associate-route-table \
	--route-table-id $PUBLIC_ROUTE_TABLE_ID \
	--subnet-id $PUBLIC_SUBNET_1a_ID

### 1cへのassociate
aws ec2 associate-route-table \
	--route-table-id $PUBLIC_ROUTE_TABLE_ID \
	--subnet-id $PUBLIC_SUBNET_1c_ID
