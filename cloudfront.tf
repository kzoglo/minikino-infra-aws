locals {
  s3_frontend_origin_id = "S3-Frontend"
  s3_images_origin_id   = "S3-Images"
}

# Origin Request Policy for API calls
resource "aws_cloudfront_origin_request_policy" "api" {
  name    = "${local.name_prefix}-api-origin-request-policy"
  comment = "Policy for API requests that forwards all viewer headers including Authorization"

  cookies_config {
    cookie_behavior = "none"
  }

  headers_config {
    header_behavior = "allViewer"
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

# Origin Access Control for Frontend
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${local.name_prefix}-frontend-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Origin Access Control for Backend Storage (Images)
resource "aws_cloudfront_origin_access_control" "backend_storage" {
  name                              = "${local.name_prefix}-backend-storage-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Single CloudFront Distribution with 2 Origins
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # Use only North America and Europe for cost optimization
  comment             = "MiniKino - Frontend + Images + API"

  # Origin 1: Frontend S3 bucket
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = local.s3_frontend_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # Origin 2: Images S3 bucket
  origin {
    domain_name              = aws_s3_bucket.backend_storage.bucket_regional_domain_name
    origin_id                = local.s3_images_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.backend_storage.id
  }

  # Origin 3: Backend API (via ALB)
  origin {
    domain_name = aws_lb.backend.dns_name
    origin_id   = "Backend-API"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default behavior: Frontend (SPA) - HTTPS
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_frontend_origin_id

    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # Path-based behavior: /images/* → Images bucket
  ordered_cache_behavior {
    path_pattern     = "/images/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_images_origin_id

    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # Path-based behavior: /api/* → Backend API (via ALB)
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "Backend-API"

    # Use CachingDisabled for API calls
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled

    origin_request_policy_id = aws_cloudfront_origin_request_policy.api.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # Handle SPA routing (404/403 → index.html)
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-cloudfront"
  })
}
