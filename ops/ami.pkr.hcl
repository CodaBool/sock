packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.7"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "unique_ami_name" {
  type = string
}

# uses an api call similar to this:
# aws ec2 describe-images --owners amazon --filters "Name=architecture,Values=arm64" "Name=name,Values=al2*" --query "Images | sort_by(@, &CreationDate) | [].[ImageId, Name]" | jq '.[]'
source "amazon-ebs" "al2" {
  ami_name      = var.unique_ami_name
  instance_type = "t4g.nano"
  region        = "us-east-1"
  force_deregister = true
  force_delete_snapshot = true
  source_ami_filter {
    filters = {
      name                = "al2*minimal*"
      architecture        = "arm64"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  ssh_username = "ec2-user"
  tags = {
    Name = var.unique_ami_name
  }
}

build {
  name = "init"
  sources = [
    "source.amazon-ebs.al2"
  ]
  provisioner "file" {
    source = "agent.json"
    destination = "/tmp/agent.json"
  }
  provisioner "file" {
    source = "../slap.mjs"
    destination = "/home/ec2-user/slap.js"
  }
  // provisioner "file" {
  //   source = "../typer.mjs"
  //   destination = "/home/ec2-user/typer.js"
  // }
  provisioner "file" {
    source = "../sock.config.cjs"
    destination = "/home/ec2-user/sock.config.cjs"
  }
  provisioner "file" {
    source = "../package.json"
    destination = "/home/ec2-user/package.json"
  }
  // provisioner "file" {
  //   source = "../.env"
  //   destination = "/home/ec2-user/.env"
  // }
  // provisioner "file" {
  //   source = "../game.js"
  //   destination = "/home/ec2-user/game.js"
  // }
  // provisioner "file" {
  //   source = "../data.js"
  //   destination = "/home/ec2-user/data.js"
  // }
  provisioner "file" {
    source = "../nginx.conf"
    destination = "/tmp/nginx.conf"
  }

  // I used a gist guide on how to setup log agent as well as the AWS docs
  // gist = https://gist.github.com/adam-hanna/06afe09209589c80ba460662f7dce65c
  // docs = https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html 
  provisioner "shell" {
    // environment_vars = [
    //   "FOO=hello world",
    // ]
    inline = [
      "sudo yum update -y -q",

      // AWS monitoring & node & nginx
      // add back in ssm agent when AWS supports ipv6 for agent requests
      // https://s3.us-east-1.amazonaws.com/amazon-ssm-us-east-1/latest/linux_arm64/amazon-ssm-agent.rpm
      "sudo yum install amazon-cloudwatch-agent nodejs nginx -y -q",

      // mem save technique
      "sudo grubby --update-kernel=ALL --remove-args=\"systemd.unified_cgroup_hierarchy=0\"",

      // allow global installs w/o sudo
      "npm config set prefix '~/.local/'",
      "mkdir -p ~/.local/bin",
      "echo 'export PATH=~/.local/bin/:$PATH' >> ~/.bashrc",

      // TODO: using npm ci is more secure, also consider using --production
      "npm install",

      // pm2
      "npm install -g @socket.io/pm2",
      "pm2 start sock.config.cjs",
      "sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u ec2-user --hp /home/ec2-user",
      "pm2 save",

      // add monitoring config
      // "chmod 400 ~/.env",
      "sudo chmod 750 /tmp/agent.json",
      "sudo chown root:root /tmp/agent.json",
      "sudo mv /tmp/agent.json /opt/aws/agent.json",

      // reverse proxy
      "sudo chmod 644 /tmp/nginx.conf",
      "sudo chown root:root /tmp/nginx.conf",
      "sudo mv /tmp/nginx.conf /etc/nginx/nginx.conf",
      "sudo systemctl enable --now nginx",

      // start monitoring process
      "sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/agent.json",
      "sudo yum clean all"
    ]
  }
}