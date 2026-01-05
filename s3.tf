# S3 Bucket for Frontend
resource "aws_s3_bucket" "frontend" {
  bucket = "${local.name_prefix}-frontend"

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-frontend-bucket"
  })
}

# S3 Bucket for Backend Storage (replacing MinIO)
resource "aws_s3_bucket" "backend_storage" {
  bucket = "${local.name_prefix}-backend-storage"

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-backend-storage-bucket"
  })
}

# S3 Bucket Versioning for Frontend
resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Versioning for Backend Storage
resource "aws_s3_bucket_versioning" "backend_storage" {
  bucket = aws_s3_bucket.backend_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Public Access Block for Frontend - Block all public access
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Public Access Block for Backend Storage - Block all public access
resource "aws_s3_bucket_public_access_block" "backend_storage" {
  bucket = aws_s3_bucket.backend_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Policy for Frontend - Allow CloudFront only
resource "aws_s3_bucket_policy" "frontend" {
  bucket     = aws_s3_bucket.frontend.id
  depends_on = [aws_s3_bucket_public_access_block.frontend]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      }
    ]
  })
}

# S3 Bucket Policy for Backend Storage - Allow CloudFront and ECS tasks
resource "aws_s3_bucket_policy" "backend_storage" {
  bucket = aws_s3_bucket.backend_storage.id
  depends_on = [
    aws_s3_bucket_public_access_block.backend_storage,
    aws_cloudfront_distribution.main,
    aws_iam_role.ecs_task_role
  ]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.backend_storage.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      },
      {
        Sid    = "AllowBackendWriteAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.ecs_task_role.arn
        }
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.backend_storage.arn}/*"
      }
    ]
  })
}

# Note: Removed S3 website configuration - using CloudFront OAC with bucket endpoint instead

# Create images folder in backend storage bucket (maps to /images/* in CloudFront)
resource "aws_s3_object" "images_folder" {
  bucket = aws_s3_bucket.backend_storage.id
  key    = "images/"
}
