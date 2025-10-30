# VPS SSH 公钥添加指南

## 🔑 您的部署公钥

请将以下公钥添加到您的 VPS：

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJia9/DgZKoc2xel8BNVzOSMLL1MgbjR+KRd+1c267ZF nofx-deployment-20251030
```

## 📝 添加公钥到 VPS

### 方法一：使用 ssh-copy-id（推荐）

如果您已经有其他方式访问 VPS（如密码登录），可以执行：

```bash
# 复制公钥到VPS
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJia9/DgZKoc2xel8BNVzOSMLL1MgbjR+KRd+1c267ZF nofx-deployment-20251030" | ssh your-user@your-vps-ip "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

### 方法二：手动添加

1. **SSH登录到您的VPS**（使用现有方式）

2. **创建或编辑 authorized_keys 文件**：

```bash
# 如果不存在，创建目录
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# 添加公钥
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJia9/DgZKoc2xel8BNVzOSMLL1MgbjR+KRd+1c267ZF nofx-deployment-20251030" >> ~/.ssh/authorized_keys

# 设置正确权限
chmod 600 ~/.ssh/authorized_keys
```

### 方法三：如果您是 root 用户

```bash
# 如果以root用户添加
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJia9/DgZKoc2xel8BNVzOSMLL1MgbjR+KRd+1c267ZF nofx-deployment-20251030" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
```

## ✅ 验证连接

添加公钥后，您可以在本地测试连接：

```bash
# 测试SSH连接（使用私钥）
ssh -i /tmp/nofx_deploy_key your-user@your-vps-ip "echo '连接成功！'"
```

## 🔐 安全建议

1. **专用密钥**：这个密钥仅用于部署，部署完成后可以删除
2. **限制权限**：如果需要，可以在VPS上限制此密钥的权限（见下方）
3. **部署后清理**：部署完成后，可以从 authorized_keys 中移除此公钥

## 🔒 限制密钥权限（可选）

如果需要限制此密钥只能执行特定命令或访问特定目录：

编辑 `~/.ssh/authorized_keys`，在公钥前添加限制：

```
command="cd /opt/nofx && /bin/bash",no-port-forwarding,no-X11-forwarding ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJia9/DgZKoc2xel8BNVzOSMLL1MgbjR+KRd+1c267ZF nofx-deployment-20251030
```

## 📋 添加完成后

公钥添加完成后，请告诉我：
- ✅ VPS IP 地址
- ✅ SSH 用户名（如 root、ubuntu 等）
- ✅ 部署方式偏好（Docker 或 PM2）

然后我就可以开始部署了！

## ⚠️ 重要提示

- 这个密钥是临时生成的，仅用于此次部署
- 部署完成后建议从 authorized_keys 中移除
- 如果担心安全，可以限制密钥的权限（见上方）
