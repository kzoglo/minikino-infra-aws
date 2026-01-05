#!/bin/bash
# ECS-optimized AMI already has ECS agent and Docker pre-installed
# We only need to configure the cluster and mount EFS
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user-data script at $(date)"

# Install EFS utilities (not included in ECS-optimized AMI)
yum install -y amazon-efs-utils || echo "WARNING: EFS utils installation failed, continuing..."

# Configure ECS cluster (ECS agent is already installed in the AMI)
echo "ECS_CLUSTER=${cluster_name}" >> /etc/ecs/ecs.config
echo "ECS_ENABLE_SPOT_INSTANCE_DRAINING=true" >> /etc/ecs/ecs.config
echo "ECS agent configured for cluster: ${cluster_name}"

# ECS service is already enabled and will start automatically
# No need to manually start it - the AMI handles this

# Create MongoDB data directory
mkdir -p ${mongo_data_path}
echo "Created MongoDB data directory: ${mongo_data_path}"

# Mount EFS for MongoDB persistent storage (with retry and error logging)
# EFS mount is NOT critical for ECS agent registration, but needed for MongoDB
EFS_MOUNTED=false
for i in {1..30}; do
  echo "EFS mount attempt $i/30..."
  if mount -t efs -o tls,iam ${efs_file_system_id}:/ ${mongo_data_path} 2>&1; then
    echo "EFS mounted successfully"
    EFS_MOUNTED=true
    break
  else
    echo "EFS mount attempt $i failed (check logs above for details)"
    sleep 2
  fi
done

if [ "$EFS_MOUNTED" = false ]; then
  echo "WARNING: EFS mount failed after 30 attempts, but continuing..."
  echo "MongoDB will use local storage until EFS is manually mounted"
fi

# Add to fstab for automatic mounting after reboot
echo "${efs_file_system_id}:/ ${mongo_data_path} efs _netdev,tls,iam 0 0" >> /etc/fstab

# Associate Elastic IP with this instance (with retry and error logging)
# EIP association is NOT critical for ECS agent registration
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
EIP_ASSOCIATED=false
for i in {1..10}; do
  echo "Elastic IP association attempt $i/10..."
  if aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id ${eip_allocation_id} --region ${aws_region} 2>&1; then
    echo "Elastic IP associated successfully"
    EIP_ASSOCIATED=true
    break
  else
    echo "Elastic IP association attempt $i failed (check logs above for details)"
    sleep 5
  fi
done

if [ "$EIP_ASSOCIATED" = false ]; then
  echo "WARNING: Elastic IP association failed after 10 attempts, but continuing..."
fi

# Set permissions for MongoDB container (only if EFS mounted successfully)
if mountpoint -q ${mongo_data_path}; then
  chown 999:999 ${mongo_data_path}
  echo "Set MongoDB permissions on ${mongo_data_path}"
else
  echo "WARNING: ${mongo_data_path} is not a mountpoint, skipping chown"
fi

# Create EIP disassociation script for shutdown
cat > /usr/local/bin/disassociate_eip.sh << 'EOF'
#!/bin/bash
# Disassociate Elastic IP on shutdown to prevent Terraform destroy issues
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
if [ -n "$INSTANCE_ID" ]; then
  echo "Disassociating Elastic IP from instance $INSTANCE_ID..."
  aws ec2 disassociate-address --instance-id $INSTANCE_ID --region ${aws_region} || echo "Failed to disassociate EIP (may not be associated)"
fi
EOF

chmod +x /usr/local/bin/disassociate_eip.sh

# Create systemd service to run on shutdown
cat > /etc/systemd/system/disassociate-eip.service << EOF
[Unit]
Description=Disassociate Elastic IP on shutdown
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/disassociate_eip.sh
TimeoutStartSec=30
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
systemctl enable disassociate-eip.service || echo "Failed to enable EIP disassociation service"

echo "User-data script completed at $(date)"
echo "ECS agent should be registering with cluster: ${cluster_name}"
echo "EIP disassociation service installed for clean shutdowns"
