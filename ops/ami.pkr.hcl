packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.6"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "unique_ami_name" {
  type = string
  default = "sock"
}

# uses an api call similar to this:
# aws ec2 describe-images --owners amazon --filters "Name=architecture,Values=arm64" "Name=name,Values=al2*" --query "Images | sort_by(@, &CreationDate) | [].[ImageId, Name]" | jq '.[]'
source "amazon-ebs" "al2" {
  ami_name      = var.unique_ami_name
  instance_type = "t4g.nano"
  region        = "us-east-1"
  force_deregister = true
  force_delete_snapshot = true
  // there are options for spot instances
  source_ami_filter {
    filters = {
      name                = "al2*"
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
    source = "../slap.js"
    destination = "/home/ec2-user/slap.js"
  }
  provisioner "file" {
    source = "../typer.js"
    destination = "/home/ec2-user/typer.js"
  }
  provisioner "file" {
    source = "../sock.config.cjs"
    destination = "/home/ec2-user/sock.config.cjs"
  }
  provisioner "file" {
    source = "../package.json"
    destination = "/home/ec2-user/package.json"
  }
  provisioner "file" {
    source = "../.env"
    destination = "/home/ec2-user/.env"
  }
  provisioner "file" {
    source = "../game.js"
    destination = "/home/ec2-user/game.js"
  }
  provisioner "file" {
    source = "../data.json"
    destination = "/home/ec2-user/data.json"
  }

  // I used a gist guide on how to setup log agent as well as the AWS docs
  // gist = https://gist.github.com/adam-hanna/06afe09209589c80ba460662f7dce65c
  // docs = https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html 
  provisioner "shell" {
    // environment_vars = [
    //   "FOO=hello world",
    // ]
    inline = [
      // "set -x",
      "sudo yum update -y -q",

      // AWS monitoring
      "sudo yum install amazon-cloudwatch-agent -y -q",

      // mem save technique
      // "sudo grubby --update-kernel=ALL --remove-args=\"systemd.unified_cgroup_hierarchy=0\"",

      // install node, use latest version https://github.com/nvm-sh/nvm/releases
      "sudo yum install nodejs -y -q",

      // allow global installs w/o sudo
      "npm config set prefix '~/.local/'",
      "mkdir -p ~/.local/bin",
      "echo 'export PATH=~/.local/bin/:$PATH' >> ~/.bashrc",

      // TODO: using npm ci is more secure, but slows down my install
      "npm install",

      // TODO: nginx or iptables are more secure than adding node to sudo
      // "sudo cp $(echo \"$NVM_DIR/versions/node/$(nvm version)/bin/node\") /bin",

      // pm2
      "npm install -g @socket.io/pm2",
      "pm2 start sock.config.cjs",
      "pm2 startup",
      "sudo env PATH=$PATH:/usr/bin /home/ec2-user/.local/lib/node_modules/@socket.io/pm2/bin/pm2 startup systemd -u ec2-user --hp /home/ec2-user",
      "pm2 save",

      // add monitoring config
      "sudo chmod 750 /tmp/agent.json",
      "sudo chown root:root /tmp/agent.json",
      "sudo cp /tmp/agent.json /opt/aws/agent.json",

      // start monitoring process
      "sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/agent.json",
      // "sudo yum clean all"
    ]
  }
}


/*
pm2 stop main

one guide suggested pm2 put logs at  /home/safeuser/.pm2/logs/app-err.log.

# question
- find out what `pm2 startup -u safeuser` does

filter @logStream = 'log'
 | fields datefloor(@timestamp, 1s) as time
#  | parse @timestamp "*" as year, month, day, other
#  | filter @message like /URL query contains semicolon, which is no longer a supported separator/
 | filter @message like /debug/
 | parse time "*-*-*" as simpleTime, th1, th3
 | parse  @message '"level":"*"' as level
 | parse  @message '"message":"*"' as message


sudo iptables -A PREROUTING -t nat -i eth0 -p tcp --dport 80 -j REDIRECT --to-port 8080
sudo iptables -A PREROUTING -t nat -i eth0 -p tcp --dport 80 -j REDIRECT --to-port 8080

delete
sudo iptables -t nat -D PREROUTING 1

list
sudo iptables -t nat -v -L PREROUTING -n --line-number

stackoverflow with tomcat 

sudo iptables -A INPUT -i eth0 -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -i eth0 -p tcp --dport 8080 -j ACCEPT
sudo iptables -A FORWARD -p tcp --dport 80 -j ACCEPT
sudo iptables -A PREROUTING -t nat -i eth0 -p tcp --dport 80 -j REDIRECT --to-port 8080

medium article
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 9000

enable routing
echo 1 > /proc/sys/net/ipv4/ip_forward

save iptables
iptables-save > /etc/sysconfig/iptables #IPv4

sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
*/