# MiniKino AWS Infrastructure

This Terraform configuration deploys the MiniKino cinema application to AWS with the following architecture:

## Architecture Overview

### Frontend

- **S3 Bucket**: Static website hosting for React application
- **CloudFront**: Global CDN with multiple origins (frontend S3, images S3, backend API via ALB)

### Backend

- **Application Load Balancer (ALB)**: Load balancer for backend API with health checks
- **ECS Cluster**: Container orchestration with Fargate tasks
- **Spot EC2 Instances**: Cost-optimized compute with Auto Scaling Group (1 min/desired/max)
- **Elastic IP**: Static IP for consistent backend access
- **S3 Bucket**: Object storage for images and backend data
- **EFS**: Network file system for MongoDB data persistence across instance replacements
- **ECR**: Docker image registry
- **Parameter Store**: Secure environment variable storage
- **AWS Budgets**: Cost monitoring and alerts

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.0 installed
3. **Docker** for building backend image
4. **Node.js** for building frontend
5. **Project Structure**: Run deployment from directory containing both `minikino-terraform-aws/` and application directories

## Configuration

### 1. Update Variables

Edit `main.tf` to customize:

- `domain_name`: Your domain (optional)
- `instance_types`: EC2 instance types for ASG mixed instances (default: ["t3.small"])
- `project_name`: Project name (default: minikino)
- `environment`: Environment name (default: production)

### 2. Update Parameter Store Values

**Important**: Set the sensitive values via Terraform variables (recommended in `terraform.tfvars` or via `-var`). These values are written into Parameter Store by Terraform:

```hcl
# terraform.tfvars
jwt_private_key     = "your-super-secret-jwt-key-change-this-in-production"
mongo_root_password = "example-password-change-this-in-production"
```

Terraform also writes non-sensitive deployment parameters (ECR URL, ECS names, CloudFront values, etc.) automatically.

### 3. Backend Configuration

The backend automatically uses the appropriate storage based on environment:

- **Local Development**: Uses MinIO for local file storage
- **Production**: Uses AWS S3 for cloud storage

Environment variables are automatically configured by the deployment script.

### 4. Frontend Configuration

Update the frontend environment variables:

- `REACT_APP_API_URL`: Backend EC2 public IP on port 3001
- `REACT_APP_S3_URL`: S3 bucket URL for images
- `REACT_APP_S3_BUCKET`: S3 bucket name

## Deployment

### Infrastructure Deployment

Deploy the AWS infrastructure:

```bash
cd minikino-terraform-aws
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Full Application Deployment (Optional)

To deploy the complete MiniKino demo application, clone the repositories and use the automated script:

```bash
# Clone demo apps (optional)
git clone https://github.com/your-org/CodersCamp_MiniKino_Backend.git
git clone https://github.com/your-org/CodersCamp_MiniKino_Frontend.git

# Run full deployment
./minikino-terraform-aws/deployment-scripts/deploy.sh
```

The script handles infrastructure + application deployment automatically.

## Cost Optimization Features

- **Spot Instances**: Up to 90% cost savings with automatic task rescheduling
- **t3.small**: Optimized instance size (2 vCPU, 2GB RAM) for container workloads
- **Single AZ**: Reduced data transfer costs
- **CloudFront Price Class 100**: North America and Europe only for CDN costs
- **7-day log retention**: Cost-effective CloudWatch log storage
- **EFS One Zone**: Cheaper network storage with data persistence
- **ALB with HTTP only**: CloudFront handles HTTPS, ALB uses HTTP for cost savings
- **AWS Budgets**: Automated cost monitoring and alerts

## Security Considerations

- Environment variables stored securely in Parameter Store
- IAM roles follow least privilege principle
- S3 buckets have appropriate access policies
- Security groups restrict access appropriately

## Parameter Store Management

### View Parameters

```bash
# List all parameters
aws ssm describe-parameters --filters "Key=Name,Values=/minikino-production/*"

# Get parameter values
aws ssm get-parameter --name "/minikino-production/jwt-private-key" --with-decryption
aws ssm get-parameter --name "/minikino-production/cloudfront-url"
```

### Update Parameters

```bash
# Update JWT key
aws ssm put-parameter \
  --name "/minikino-production/jwt-private-key" \
  --value "your-new-jwt-key" \
  --type "SecureString" \
  --overwrite

# Update MongoDB password
aws ssm put-parameter \
  --name "/minikino-production/mongo-root-password" \
  --value "your-new-password" \
  --type "SecureString" \
  --overwrite
```

## AWS Budgets Management

The infrastructure includes automated cost monitoring with AWS Budgets.

### Budget Configuration

- **Monthly Limit**: $50 USD (configurable via `budget_amount` variable)
- **Alert Thresholds**: 50%, 80%, and 100% of budget
- **Email Notifications**: Sent to configured alert email address

### View Budget Status

```bash
# List all budgets
aws budgets describe-budgets

# Get budget details
aws budgets describe-budget --budget-name minikino-production-monthly-budget
```

### Update Budget Amount

```bash
# Update budget limit (requires AWS CLI configured)
aws budgets update-budget \
  --budget-name minikino-production-monthly-budget \
  --budget-limit Amount=75,Unit=USD
```

### Budget Alerts

Budget alerts are automatically configured for:

- **50% threshold**: Early warning
- **80% threshold**: Action required warning
- **100% threshold**: Budget exceeded

## Terraform Outputs

After deployment, these outputs are available for accessing your infrastructure:

### Application URLs

```bash
# CloudFront URLs (primary access points)
terraform output cloudfront_url          # Frontend: https://xxx.cloudfront.net
terraform output alb_url                 # Backend API via ALB: https://alb-xxx.region.elb.amazonaws.com
terraform output backend_url             # Direct backend API URL

# Elastic IP (for direct backend access if needed)
terraform output elastic_ip              # Static IP: xxx.xxx.xxx.xxx
```

### Storage Resources

```bash
# S3 Buckets
terraform output s3_frontend_bucket      # Frontend static files
terraform output s3_backend_storage_bucket # Images and uploads

# ECR Repository
terraform output ecr_repository_url      # Docker image repository
```

### Infrastructure Resources

```bash
# CloudFront
terraform output cloudfront_domain       # CloudFront domain name
terraform output cloudfront_distribution_id # Distribution ID for cache invalidation

# ECS Resources
terraform output ecs_cluster_name        # ECS cluster name
terraform output ecs_service_name        # ECS service name

# Network
terraform output vpc_id                  # VPC ID

# Storage
terraform output efs_file_system_id      # EFS file system for MongoDB data
```

### Parameter Store Paths

```bash
# Sensitive parameter paths
terraform output parameter_store_paths   # JWT key, MongoDB credentials
```

Additional deployment parameters are stored under the same prefix, for example:

- `/minikino-production/ecr-repository-url`
- `/minikino-production/ecs-cluster-name`
- `/minikino-production/ecs-service-name`
- `/minikino-production/s3-frontend-bucket`
- `/minikino-production/cloudfront-url`
- `/minikino-production/cloudfront-domain`
- `/minikino-production/cloudfront-distribution-id`

### Example Usage

```bash
# Get all outputs
terraform output

# Get specific output
terraform output -raw cloudfront_url

# Use in scripts
CLOUDFRONT_URL=$(terraform output -raw cloudfront_url)
echo "Your app is live at: $CLOUDFRONT_URL"
```

## Monitoring

## Scaling

The Auto Scaling Group is configured with:

- Minimum: 1 instance
- Desired: 1 instance
- Maximum: 1 instance

For production scaling, consider:

- Increasing max capacity
- Adding CloudWatch alarms
- Implementing horizontal pod autoscaling

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Troubleshooting

### Common Issues

1. **Spot Instance Interruptions**: Normal behavior, ECS will reschedule tasks
2. **ECS Service Not Starting**: Check IAM roles and security groups
3. **S3 Access Denied**: Verify bucket policies and IAM permissions
4. **MongoDB Connection Issues**: Check EFS mount and security groups
5. **Parameter Store Access**: Verify IAM permissions for ECS execution role

### Logs

- ECS task logs: CloudWatch `/ecs/minikino-production-backend`
- MongoDB logs: CloudWatch `/ecs/minikino-production-mongodb`

## Estimated Costs (us-east-1)

- **t3.small Spot**: ~$8-12/month (2 vCPU, 2GB RAM for better performance)
- **CloudFront**: ~$1-2/month
- **ALB**: ~$16/month (but used efficiently with CloudFront)
- **S3**: ~$0.50/month
- **EFS One Zone**: ~$1-2/month (cheaper than EBS for persistence)
- **Elastic IP**: ~$3.50/month (minimal when instance is running)
- **Data Transfer**: ~$1-2/month
- **AWS Budgets**: ~$0/month (free service)

**Total**: ~$30-40/month (includes ALB for production-grade setup)

_Note: Costs may vary based on usage and region_

## Key Features of Current Version

- **Production-Grade Architecture**: ALB + CloudFront for high availability and performance
- **Persistent Storage**: EFS One Zone for MongoDB data across instance replacements
- **Cost Monitoring**: AWS Budgets with automated alerts at 50%, 80%, and 100% thresholds
- **Automated Deployment**: Complete deployment script for infrastructure + applications
- **Secure Configuration**: Parameter Store for all sensitive environment variables
- **Spot Instance Optimization**: Automatic task rescheduling on spot interruptions
- **Global CDN**: CloudFront with multiple origins (frontend, images, API)
