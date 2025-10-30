# VPS 部署指南

本指南将帮助您将 NOFX 项目部署到 VPS 服务器。

## 🚀 快速部署（推荐）

### 方法一：使用自动部署脚本（最简单）

#### 前置要求

1. **本地需要**：
   - 已配置 SSH 密钥访问 VPS（或使用密码）
   - VPS 的 IP 地址和用户名

2. **VPS 需要**：
   - Ubuntu 20.04+ / Debian 11+ / CentOS 8+ / RHEL 8+
   - 至少 2GB 内存
   - 至少 10GB 磁盘空间
   - root 或 sudo 权限

#### 一键部署

```bash
# 在本地执行（自动连接VPS并部署）
./deploy-vps.sh deploy root@your-vps-ip

# 或使用自定义用户
./deploy-vps.sh deploy user@your-vps-ip
```

**脚本会自动完成：**
- ✅ 安装 Docker 和 Docker Compose（或 Node.js/Go/PM2）
- ✅ 创建应用用户和目录
- ✅ 克隆代码仓库
- ✅ 配置防火墙
- ✅ 启动服务

#### 部署后配置

部署完成后，需要配置 API 密钥：

```bash
# SSH 登录到 VPS
ssh root@your-vps-ip

# 编辑配置文件
nano /opt/nofx/config.json

# 填入您的 API 密钥，然后重启服务
systemctl restart nofx  # Docker 方式
# 或
pm2 restart all         # PM2 方式
```

### 方法二：手动部署（推荐用于定制）

如果自动脚本不适合您的环境，可以手动执行：

#### 步骤 1: 上传脚本到 VPS

```bash
# 从本地上传脚本
scp deploy-vps.sh root@your-vps-ip:/tmp/

# SSH 登录到 VPS
ssh root@your-vps-ip
```

#### 步骤 2: 在 VPS 上执行安装

```bash
# 赋予执行权限
chmod +x /tmp/deploy-vps.sh

# 执行安装（需要 root 权限）
sudo /tmp/deploy-vps.sh install

# 或指定部署方式
DEPLOY_MODE=docker sudo /tmp/deploy-vps.sh install
DEPLOY_MODE=pm2 sudo /tmp/deploy-vps.sh install
```

## 📋 部署方式选择

### Docker 部署（推荐）

**优点：**
- ✅ 环境隔离，易于管理
- ✅ 自动处理所有依赖
- ✅ 易于更新和回滚
- ✅ 适合生产环境

**缺点：**
- ❌ 资源占用稍高
- ❌ 需要 Docker 环境

**使用场景：**
- 生产环境部署
- 需要环境隔离
- 多项目服务器

### PM2 部署

**优点：**
- ✅ 资源占用低
- ✅ 启动速度快
- ✅ 自动重启和监控
- ✅ 适合轻量级部署

**缺点：**
- ❌ 需要手动安装依赖（Go、Node.js、TA-Lib）
- ❌ 环境配置复杂

**使用场景：**
- 开发环境
- 资源有限的服务器
- 单项目专用服务器

## 🔧 详细配置

### 环境变量

部署脚本支持以下环境变量：

```bash
# 部署方式
export DEPLOY_MODE=docker    # 或 pm2

# 部署目录
export DEPLOY_DIR=/opt/nofx

# 运行用户
export APP_USER=nofx

# 仓库URL（如果使用私有仓库）
export REPO_URL=https://github.com/your-repo/nofx.git
```

### 修改端口

#### Docker 方式

编辑 `docker-compose.yml`：

```yaml
services:
  nofx:
    ports:
      - "8080:8080"  # 改为您的端口
  nofx-frontend:
    ports:
      - "3000:80"    # 改为您的端口
```

#### PM2 方式

编辑 `config.json`：

```json
{
  "api_server_port": 8080  // 后端端口
}
```

编辑 `web/vite.config.ts` 修改前端端口。

### 配置域名和 HTTPS

#### 使用 Nginx 反向代理

```nginx
# /etc/nginx/sites-available/nofx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /api/ {
        proxy_pass http://localhost:8080/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

启用配置：

```bash
ln -s /etc/nginx/sites-available/nofx /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
```

#### 配置 HTTPS（Let's Encrypt）

```bash
# 安装 Certbot
apt-get install certbot python3-certbot-nginx  # Ubuntu/Debian
yum install certbot python3-certbot-nginx      # CentOS/RHEL

# 获取证书
certbot --nginx -d your-domain.com

# 自动续期测试
certbot renew --dry-run
```

## 📊 服务管理

### Docker 方式

```bash
# 查看状态
systemctl status nofx

# 查看日志
docker compose -f /opt/nofx/docker-compose.yml logs -f

# 重启服务
systemctl restart nofx

# 停止服务
systemctl stop nofx

# 更新代码
cd /opt/nofx
git pull
systemctl restart nofx
```

### PM2 方式

```bash
# 查看状态
sudo -u nofx pm2 status

# 查看日志
sudo -u nofx pm2 logs

# 重启服务
sudo -u nofx pm2 restart all

# 停止服务
sudo -u nofx pm2 stop all

# 更新代码
cd /opt/nofx
git pull
sudo -u nofx pm2 restart all
```

## 🔒 安全建议

### 1. 配置防火墙

```bash
# UFW (Ubuntu/Debian)
ufw allow 22/tcp
ufw allow 3000/tcp
ufw allow 8080/tcp
ufw enable

# Firewalld (CentOS/RHEL)
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-port=3000/tcp
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --reload
```

### 2. 限制 SSH 访问

```bash
# 编辑 SSH 配置
nano /etc/ssh/sshd_config

# 修改以下配置：
# PermitRootLogin no
# PasswordAuthentication no  # 仅使用密钥登录
# Port 2222                  # 更改默认端口

# 重启 SSH
systemctl restart sshd
```

### 3. 定期更新

```bash
# 更新系统
apt-get update && apt-get upgrade  # Ubuntu/Debian
yum update                          # CentOS/RHEL

# 更新 Docker 镜像
docker compose pull && docker compose up -d
```

### 4. 监控和日志

```bash
# 监控资源使用
htop              # CPU/内存
docker stats      # Docker 容器资源
pm2 monit         # PM2 进程监控

# 查看日志
journalctl -u nofx -f          # systemd 日志（Docker）
docker compose logs -f         # Docker 日志
pm2 logs                        # PM2 日志
```

## 🐛 故障排查

### 服务无法启动

```bash
# 检查日志
docker compose logs nofx        # Docker
pm2 logs                        # PM2
journalctl -u nofx -n 50        # systemd

# 检查端口占用
netstat -tulpn | grep :8080
netstat -tulpn | grep :3000

# 检查配置文件
cat /opt/nofx/config.json
```

### 无法访问 Web 界面

1. **检查防火墙**：
   ```bash
   ufw status
   firewall-cmd --list-all
   ```

2. **检查服务状态**：
   ```bash
   systemctl status nofx        # Docker
   pm2 status                  # PM2
   ```

3. **检查端口监听**：
   ```bash
   ss -tulpn | grep :3000
   ss -tulpn | grep :8080
   ```

### API 连接错误

1. **检查后端服务**：
   ```bash
   curl http://localhost:8080/health
   ```

2. **检查配置文件**：
   ```bash
   nano /opt/nofx/config.json
   ```

3. **检查网络连接**：
   ```bash
   ping api.binance.com
   ```

## 📝 备份和恢复

### 备份

```bash
# 备份配置和日志
tar -czf nofx-backup-$(date +%Y%m%d).tar.gz \
  /opt/nofx/config.json \
  /opt/nofx/decision_logs
```

### 恢复

```bash
# 解压备份
tar -xzf nofx-backup-20240101.tar.gz

# 恢复文件
cp config.json /opt/nofx/
cp -r decision_logs /opt/nofx/

# 重启服务
systemctl restart nofx  # 或 pm2 restart all
```

## 📞 获取帮助

如果遇到问题：

1. 查看日志文件
2. 检查配置文件格式
3. 确认所有依赖已安装
4. 查看项目 GitHub Issues

## ✅ 部署检查清单

部署完成后，确认：

- [ ] 服务已启动（`systemctl status nofx` 或 `pm2 status`）
- [ ] 可以访问 Web 界面（http://your-vps-ip:3000）
- [ ] API 健康检查通过（http://your-vps-ip:8080/health）
- [ ] 配置文件已正确填写（`config.json`）
- [ ] 防火墙规则已配置
- [ ] 日志正常输出
- [ ] 开机自启动已配置

---

**祝您部署顺利！** 🎉
