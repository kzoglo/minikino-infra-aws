#!/bin/bash

# MiniKino AWS Deployment Script
set -e

echo "🚀 Starting MiniKino AWS Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform >= 1.0"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker"
        exit 1
    fi
    
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install Node.js"
        exit 1
    fi
    
    print_status "All prerequisites are satisfied!"
}

# Deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying AWS infrastructure..."
    
    cd minikino-terraform-aws
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    print_status "Planning deployment..."
    terraform plan -out=tfplan
    
    # Apply infrastructure
    print_status "Applying infrastructure..."
    terraform apply tfplan
    
    # Get outputs
    ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
    S3_FRONTEND_BUCKET=$(terraform output -raw s3_frontend_bucket)
    S3_BACKEND_BUCKET=$(terraform output -raw s3_backend_storage_bucket)
    CLOUDFRONT_URL=$(terraform output -raw cloudfront_url)
    CLOUDFRONT_DOMAIN=$(terraform output -raw cloudfront_domain)
    CLOUDFRONT_DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id)
    
    print_status "Infrastructure deployed successfully!"
    print_status "ECR Repository: $ECR_REPO_URL"
    print_status "S3 Frontend Bucket: $S3_FRONTEND_BUCKET"
    print_status "S3 Backend Bucket: $S3_BACKEND_BUCKET"
    print_status "CloudFront URL: $CLOUDFRONT_URL"
    print_status "CloudFront Domain: $CLOUDFRONT_DOMAIN"
    
    cd ..
}

# Build and deploy backend
deploy_backend() {
    print_status "Building and deploying backend..."
    
    cd CodersCamp_MiniKino_Backend
    
    # Get ECR repository URL, AWS region, and Elastic IP
    ECR_REPO_URL=$(cd ../minikino-terraform-aws && terraform output -raw ecr_repository_url)
    AWS_REGION=$(cd ../minikino-terraform-aws && terraform output -raw aws_region)
    ELASTIC_IP=$(cd ../minikino-terraform-aws && terraform output -raw elastic_ip)
    
    # Get AWS account ID from ECR URL
    AWS_ACCOUNT_ID=$(echo $ECR_REPO_URL | cut -d'.' -f1)
    
    # Install dependencies (to ensure AWS SDK is installed)
    print_status "Installing dependencies..."
    npm install
    
    # Login to ECR
    print_status "Logging into ECR..."
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
    
    # Build Docker image (production target)
    print_status "Building Docker image for linux/amd64 (production target)..."
    docker build --platform linux/amd64 -f node.Dockerfile --target production -t minikino-backend:latest .
    
    # Tag image for ECR
    print_status "Tagging image..."
    docker tag minikino-backend:latest $ECR_REPO_URL:latest
    
    # Push image to ECR
    print_status "Pushing image to ECR..."
    docker push $ECR_REPO_URL:latest
    
    # Force new deployment of ECS service
    print_status "Forcing ECS service update..."
    ECS_CLUSTER=$(cd ../minikino-terraform-aws && terraform output -raw ecs_cluster_name)
    ECS_SERVICE=$(cd ../minikino-terraform-aws && terraform output -raw ecs_service_name)
    if aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --force-new-deployment --region $AWS_REGION > /dev/null 2>&1; then
        print_status "ECS service update triggered successfully"
        print_status "Deployment may take 2-3 minutes to complete..."
    else
        print_warning "ECS service update failed (service may not exist yet)"
    fi
    
    print_status "Backend deployed successfully!"
    cd ..
}

# Build and deploy frontend
deploy_frontend() {
    print_status "Building and deploying frontend..."
    
    cd CodersCamp_MiniKino_Frontend
    
    # Get ALB URL for backend API
    ALB_URL=$(cd ../minikino-terraform-aws && terraform output -raw alb_url)
    CLOUDFRONT_DOMAIN=$(cd ../minikino-terraform-aws && terraform output -raw cloudfront_domain)

    # Use CloudFront domain for API calls (proxied to ALB)
    CLOUDFRONT_URL=$(cd ../minikino-terraform-aws && terraform output -raw cloudfront_url)
    print_status "Using CloudFront domain for API: $CLOUDFRONT_URL"

    # Create .env.production file
    print_status "Creating production environment file..."
    cat > .env.production << EOF
    # API URL - CloudFront proxies /api/* to ALB backend
    REACT_APP_API_URL=$CLOUDFRONT_URL
    # Images are served from CloudFront at /images/* path
    REACT_APP_S3_URL=https://$CLOUDFRONT_DOMAIN
    REACT_APP_S3_BUCKET=images
EOF
    
    # Install dependencies
    print_status "Installing dependencies..."
    npm install

    # Build React app in production mode
    print_status "Building React application..."
    NODE_ENV=production npm run build
    
    # Get S3 frontend bucket
    S3_FRONTEND_BUCKET=$(cd ../minikino-terraform-aws && terraform output -raw s3_frontend_bucket)
    
    # Sync to S3
    print_status "Syncing build to S3..."
    aws s3 sync build/ s3://$S3_FRONTEND_BUCKET --delete
    
    # Invalidate CloudFront cache
    print_status "Invalidating CloudFront cache..."
    CLOUDFRONT_DISTRIBUTION_ID=$(cd ../minikino-terraform-aws && terraform output -raw cloudfront_distribution_id)
    
    if [ ! -z "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
        aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_DISTRIBUTION_ID --paths "/*"
        print_status "CloudFront cache invalidated."
    else
        print_warning "CloudFront distribution ID not found. Cache invalidation skipped."
    fi
    
    print_status "Frontend deployed successfully!"
    cd ..
}

# Print final deployment info
print_deployment_info() {
    print_status "=========================================="
    print_status "🎉 Deployment Summary"
    print_status "=========================================="
    
    cd minikino-terraform-aws
    
    CLOUDFRONT_URL=$(terraform output -raw cloudfront_url)
    ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
    ECS_CLUSTER=$(terraform output -raw ecs_cluster_name)
    ELASTIC_IP=$(terraform output -raw elastic_ip)
    
    print_status "Frontend URL: $CLOUDFRONT_URL"
    print_status "Backend API: $CLOUDFRONT_URL/api (via CloudFront/ALB)"
    print_status "Direct Backend API: https://$ELASTIC_IP (via ALB, if needed)"
    print_status "ECR Repository: $ECR_REPO_URL"
    print_status "ECS Cluster: $ECS_CLUSTER"
    print_status ""
    print_status "✅ Deployment completed successfully!"
    print_status "Your app should be available at: $CLOUDFRONT_URL"
    print_status ""
    print_warning "Note: Spot instances may be interrupted. ECS will automatically reschedule tasks to new instances."
    print_warning "The Elastic IP remains associated with the new instance, so your API calls will continue working."
    
    cd ..
}

# Main deployment function
main() {
    print_status "Starting MiniKino deployment to AWS..."
    
    # Check prerequisites
    check_prerequisites
    
    # Check if we're in the right directory
    if [ ! -d "minikino-terraform-aws" ] || [ ! -d "CodersCamp_MiniKino_Backend" ]; then
        print_error "Please run this script from the PROJEKTY_AKTUALNE directory"
        exit 1
    fi
    
    # Deploy infrastructure
    deploy_infrastructure
    
    # Deploy backend
    deploy_backend
    
    # Deploy frontend
    deploy_frontend
    
    # Print final info
    print_deployment_info
}

# Run main function
main "$@"
