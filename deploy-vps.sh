#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# NOFX VPS 自动部署脚本
# 使用方法: 
#   本地执行: ./deploy-vps.sh deploy user@your-vps-ip
#   或手动执行: 将脚本上传到VPS后执行 ./deploy-vps.sh install
# ═══════════════════════════════════════════════════════════════

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印函数
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 部署模式
DEPLOY_MODE="${DEPLOY_MODE:-docker}"  # docker 或 pm2
DEPLOY_DIR="${DEPLOY_DIR:-/opt/nofx}"
APP_USER="${APP_USER:-nofx}"

# ═══════════════════════════════════════════════════════════════
# 远程部署（从本地执行）
# ═══════════════════════════════════════════════════════════════
deploy_remote() {
    local SSH_TARGET="$1"
    
    if [ -z "$SSH_TARGET" ]; then
        print_error "请提供SSH目标: user@host"
        echo "用法: $0 deploy user@your-vps-ip"
        exit 1
    fi
    
    print_info "开始部署到 $SSH_TARGET..."
    
    # 检查SSH连接
    print_info "检查SSH连接..."
    if ! ssh -o ConnectTimeout=10 "$SSH_TARGET" "echo 'SSH连接成功'" &>/dev/null; then
        print_error "无法连接到 $SSH_TARGET"
        print_info "请确保:"
        echo "  1. SSH密钥已配置（或使用密码）"
        echo "  2. VPS防火墙允许SSH连接"
        echo "  3. 服务器正在运行"
        exit 1
    fi
    
    print_success "SSH连接正常"
    
    # 上传脚本到VPS
    print_info "上传部署脚本..."
    scp "$0" "$SSH_TARGET:/tmp/deploy-nofx.sh"
    
    # 在远程执行安装
    print_info "在远程服务器执行安装..."
    ssh "$SSH_TARGET" "bash /tmp/deploy-nofx.sh install"
    
    print_success "部署完成！"
    print_info "SSH登录服务器检查: ssh $SSH_TARGET"
}

# ═══════════════════════════════════════════════════════════════
# 本地安装（在VPS上执行）
# ═══════════════════════════════════════════════════════════════
install_local() {
    print_info "开始安装 NOFX 到 VPS..."
    
    # 检查是否为root用户
    if [ "$EUID" -ne 0 ]; then 
        print_error "请使用 sudo 运行此脚本"
        exit 1
    fi
    
    # 检测操作系统
    detect_os
    
    # 安装依赖
    install_dependencies
    
    # 创建用户和目录
    setup_user_and_dirs
    
    # 克隆/更新代码
    setup_code
    
    # 选择部署方式
    if [ "$DEPLOY_MODE" == "docker" ]; then
        setup_docker
    else
        setup_pm2
    fi
    
    # 配置防火墙
    setup_firewall
    
    # 完成
    print_success "安装完成！"
    print_info "访问地址: http://$(hostname -I | awk '{print $1}'):3000"
    print_info "配置文件位置: $DEPLOY_DIR/config.json"
}

# ═══════════════════════════════════════════════════════════════
# 检测操作系统
# ═══════════════════════════════════════════════════════════════
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        print_error "无法检测操作系统"
        exit 1
    fi
    
    print_info "检测到操作系统: $OS $VER"
}

# ═══════════════════════════════════════════════════════════════
# 安装依赖
# ═══════════════════════════════════════════════════════════════
install_dependencies() {
    print_info "安装系统依赖..."
    
    if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
        apt-get update
        apt-get install -y curl git wget build-essential
        
        if [ "$DEPLOY_MODE" == "docker" ]; then
            install_docker_ubuntu
        else
            install_pm2_dependencies_ubuntu
        fi
    elif [ "$OS" == "centos" ] || [ "$OS" == "rhel" ] || [ "$OS" == "rocky" ]; then
        yum install -y curl git wget gcc gcc-c++ make
        if [ "$DEPLOY_MODE" == "docker" ]; then
            install_docker_centos
        else
            install_pm2_dependencies_centos
        fi
    else
        print_error "不支持的操作系统: $OS"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════════
# 安装 Docker (Ubuntu/Debian)
# ═══════════════════════════════════════════════════════════════
install_docker_ubuntu() {
    if command -v docker &> /dev/null; then
        print_info "Docker 已安装"
        return
    fi
    
    print_info "安装 Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    
    # 启动Docker
    systemctl enable docker
    systemctl start docker
    
    print_success "Docker 安装完成"
}

# ═══════════════════════════════════════════════════════════════
# 安装 Docker (CentOS/RHEL)
# ═══════════════════════════════════════════════════════════════
install_docker_centos() {
    if command -v docker &> /dev/null; then
        print_info "Docker 已安装"
        return
    fi
    
    print_info "安装 Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    
    # 启动Docker
    systemctl enable docker
    systemctl start docker
    
    print_success "Docker 安装完成"
}

# ═══════════════════════════════════════════════════════════════
# 安装 PM2 依赖 (Ubuntu/Debian)
# ═══════════════════════════════════════════════════════════════
install_pm2_dependencies_ubuntu() {
    print_info "安装 Node.js 和 Go..."
    
    # 安装 Node.js
    if ! command -v node &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
    fi
    
    # 安装 Go
    if ! command -v go &> /dev/null; then
        GO_VERSION="1.21"
        wget https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
        tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
        echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
        rm go${GO_VERSION}.linux-amd64.tar.gz
    fi
    
    # 安装 TA-Lib
    apt-get install -y libta-lib0-dev
    
    # 安装 PM2
    if ! command -v pm2 &> /dev/null; then
        npm install -g pm2
    fi
    
    print_success "PM2 依赖安装完成"
}

# ═══════════════════════════════════════════════════════════════
# 安装 PM2 依赖 (CentOS/RHEL)
# ═══════════════════════════════════════════════════════════════
install_pm2_dependencies_centos() {
    print_info "安装 Node.js 和 Go..."
    
    # 安装 Node.js
    if ! command -v node &> /dev/null; then
        curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
        yum install -y nodejs
    fi
    
    # 安装 Go
    if ! command -v go &> /dev/null; then
        GO_VERSION="1.21"
        wget https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
        tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
        echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
        rm go${GO_VERSION}.linux-amd64.tar.gz
    fi
    
    # 安装 TA-Lib（需要从源码编译）
    if ! pkg-config --exists ta-lib; then
        yum install -y epel-release
        yum install -y wget
        cd /tmp
        wget http://prdownloads.sourceforge.net/ta-lib/ta-lib-0.4.0-src.tar.gz
        tar -xzf ta-lib-0.4.0-src.tar.gz
        cd ta-lib/
        ./configure --prefix=/usr
        make && make install
        cd -
        rm -rf ta-lib ta-lib-0.4.0-src.tar.gz
    fi
    
    # 安装 PM2
    if ! command -v pm2 &> /dev/null; then
        npm install -g pm2
    fi
    
    print_success "PM2 依赖安装完成"
}

# ═══════════════════════════════════════════════════════════════
# 创建用户和目录
# ═══════════════════════════════════════════════════════════════
setup_user_and_dirs() {
    print_info "创建应用用户和目录..."
    
    # 创建用户（如果不存在）
    if ! id "$APP_USER" &>/dev/null; then
        useradd -r -s /bin/bash -d "$DEPLOY_DIR" "$APP_USER"
        print_info "创建用户: $APP_USER"
    fi
    
    # 创建目录
    mkdir -p "$DEPLOY_DIR"
    mkdir -p "$DEPLOY_DIR/decision_logs"
    mkdir -p "$DEPLOY_DIR/logs"
    
    # 设置权限
    chown -R "$APP_USER:$APP_USER" "$DEPLOY_DIR"
    
    print_success "目录创建完成"
}

# ═══════════════════════════════════════════════════════════════
# 设置代码
# ═══════════════════════════════════════════════════════════════
setup_code() {
    print_info "设置代码..."
    
    # 如果目录已存在，更新代码
    if [ -d "$DEPLOY_DIR/.git" ]; then
        print_info "更新代码..."
        cd "$DEPLOY_DIR"
        sudo -u "$APP_USER" git pull
    else
        print_info "克隆代码..."
        # 注意：这里需要实际的仓库URL
        REPO_URL="${REPO_URL:-https://github.com/tinkle-community/nofx.git}"
        sudo -u "$APP_USER" git clone "$REPO_URL" "$DEPLOY_DIR"
    fi
    
    # 复制配置文件模板
    if [ ! -f "$DEPLOY_DIR/config.json" ]; then
        print_info "创建配置文件..."
        cp "$DEPLOY_DIR/config.json.example" "$DEPLOY_DIR/config.json"
        chown "$APP_USER:$APP_USER" "$DEPLOY_DIR/config.json"
        print_warning "请编辑 $DEPLOY_DIR/config.json 填入您的API密钥"
    fi
    
    print_success "代码设置完成"
}

# ═══════════════════════════════════════════════════════════════
# 设置 Docker 部署
# ═══════════════════════════════════════════════════════════════
setup_docker() {
    print_info "配置 Docker 部署..."
    
    # 创建 docker-compose 服务
    cat > /etc/systemd/system/nofx.service << EOF
[Unit]
Description=NOFX Trading System
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$DEPLOY_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
User=$APP_USER
Group=$APP_USER

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载systemd
    systemctl daemon-reload
    
    # 启动服务
    print_info "启动 Docker 服务..."
    systemctl enable nofx.service
    systemctl start nofx.service
    
    print_success "Docker 部署完成"
}

# ═══════════════════════════════════════════════════════════════
# 设置 PM2 部署
# ═══════════════════════════════════════════════════════════════
setup_pm2() {
    print_info "配置 PM2 部署..."
    
    cd "$DEPLOY_DIR"
    
    # 编译后端
    print_info "编译后端..."
    source /etc/profile  # 加载 Go 环境变量
    sudo -u "$APP_USER" go build -o nofx
    
    # 安装前端依赖
    print_info "安装前端依赖..."
    cd web
    sudo -u "$APP_USER" npm install
    cd ..
    
    # 使用 PM2 启动
    print_info "启动 PM2 服务..."
    sudo -u "$APP_USER" pm2 start pm2.config.js
    sudo -u "$APP_USER" pm2 save
    sudo -u "$APP_USER" pm2 startup
    
    print_success "PM2 部署完成"
}

# ═══════════════════════════════════════════════════════════════
# 配置防火墙
# ═══════════════════════════════════════════════════════════════
setup_firewall() {
    print_info "配置防火墙..."
    
    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian UFW
        ufw allow 22/tcp
        ufw allow 3000/tcp
        ufw allow 8080/tcp
        print_info "UFW 防火墙规则已添加"
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL firewalld
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --permanent --add-port=3000/tcp
        firewall-cmd --permanent --add-port=8080/tcp
        firewall-cmd --reload
        print_info "Firewalld 防火墙规则已添加"
    else
        print_warning "未检测到防火墙工具，请手动配置防火墙"
    fi
}

# ═══════════════════════════════════════════════════════════════
# 主函数
# ═══════════════════════════════════════════════════════════════
main() {
    case "${1:-help}" in
        deploy)
            deploy_remote "$2"
            ;;
        install)
            install_local
            ;;
        help|--help|-h)
            echo "NOFX VPS 自动部署脚本"
            echo ""
            echo "用法:"
            echo "  $0 deploy user@vps-ip          # 从本地部署到远程VPS"
            echo "  $0 install                     # 在VPS上本地安装"
            echo ""
            echo "环境变量:"
            echo "  DEPLOY_MODE=docker|pm2          # 部署方式（默认: docker）"
            echo "  DEPLOY_DIR=/opt/nofx            # 部署目录（默认: /opt/nofx）"
            echo "  APP_USER=nofx                   # 运行用户（默认: nofx）"
            echo "  REPO_URL=git-url                # 仓库URL（可选）"
            echo ""
            echo "示例:"
            echo "  $0 deploy root@192.168.1.100"
            echo "  DEPLOY_MODE=pm2 $0 deploy user@vps-ip"
            ;;
        *)
            print_error "未知命令: $1"
            echo "运行 $0 help 查看帮助"
            exit 1
            ;;
    esac
}

main "$@"
