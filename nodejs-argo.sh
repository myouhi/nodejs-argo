#!/bin/bash
set -e

# --- 全局常量 ---
APP_NAME="nodejs-argo"
INSTALL_DIR="/opt/$APP_NAME"
LOG_FILE="/var/log/${APP_NAME}_install.log"
CONFIG_FILE_ENV="$INSTALL_DIR/config.env"
CONFIG_FILE_SUB="$INSTALL_DIR/tmp/sub.txt"
SERVICE_FILE="/etc/systemd/system/$APP_NAME.service"
ZIP_URL="https://github.com/myouhi/nodejs-argo/releases/download/nodejs-argo.sh/nodejs-argo.zip"
ZIP_FILE="/tmp/$APP_NAME.zip"

# --- 快捷命令 ---
SHORTCUT_CMD="js"
SHORTCUT_PATH="/usr/local/bin/$SHORTCUT_CMD"

# --- 系统检测变量 ---
OS_ID=""
PKG_MANAGER=""
NODE_SETUP_URL=""

# --- 颜色 ---
RED='\033[1;31m'; GREEN='\033[1;32m'; BRIGHT_GREEN='\033[1;32m'; YELLOW='\033[1;33m'
BLUE='\033[1;34m'; MAGENTA='\033[1;35m'; CYAN='\033[1;36m'; WHITE='\033[1;37m'; RESET='\033[0m'

red() { echo -e "${RED}$1${RESET}"; }
green() { echo -e "${GREEN}$1${RESET}"; }
bright_green() { echo -e "${BRIGHT_GREEN}$1${RESET}"; }
yellow() { echo -e "${YELLOW}$1${RESET}"; }
blue() { echo -e "${BLUE}$1${RESET}"; }
cyan() { echo -e "${CYAN}$1${RESET}"; }
white() { echo -e "${WHITE}$1${RESET}"; }

# --- 辅助函数 ---
check_root() {
  if [ "$EUID" -ne 0 ]; then
    red "错误: 此脚本需要 root 权限运行。"
    exit 1
  fi
}

check_system() {
  if ! command -v systemctl &>/dev/null; then
    red "错误: 未找到 systemd (systemctl)。"
    exit 1
  fi

  if [ -f /etc/os-release ]; then
    source /etc/os-release
    OS_ID=$ID
  else
    red "无法检测操作系统。"
    exit 1
  fi

  case $OS_ID in
    ubuntu|debian)
      PKG_MANAGER="apt"
      NODE_SETUP_URL="https://deb.nodesource.com/setup_20.x"
      ;;
    centos|rhel|almalinux|rocky)
      PKG_MANAGER=$(command -v dnf &>/dev/null && echo "dnf" || echo "yum")
      NODE_SETUP_URL="https://rpm.nodesource.com/setup_20.x"
      ;;
    *)
      red "不支持的操作系统: $OS_ID"
      exit 1
      ;;
  esac

  white "检测到系统: $(green "$OS_ID") | 包管理器: $(green "$PKG_MANAGER")"
}

check_dependencies() {
  for cmd in curl unzip; do
    if ! command -v "$cmd" &>/dev/null; then
      red "缺少命令 '$cmd'，请先安装。"
      yellow "示例: sudo $PKG_MANAGER install -y $cmd"
      exit 1
    fi
  done

  if [[ "$OS_ID" =~ centos|rhel ]]; then
    if ! command -v uuidgen &>/dev/null; then
      yellow "安装 uuidgen..."
      "$PKG_MANAGER" install -y util-linux >> "$LOG_FILE" 2>&1
    fi
  fi
}

install_nodejs() {
  if command -v node &>/dev/null; then
    NODE_MAJOR_VERSION=$(node -v | sed 's/v\([0-9]\+\).*/\1/')
    white "检测 Node.js 版本: $(node -v)"
  else
    NODE_MAJOR_VERSION=0
    white "未检测到 Node.js"
  fi

  if [ "$NODE_MAJOR_VERSION" -lt 20 ]; then
    yellow "Node.js 版本低于 v20，正在安装/升级..."
    curl -fsSL "$NODE_SETUP_URL" | bash >> "$LOG_FILE" 2>&1
    "$PKG_MANAGER" install -y nodejs >> "$LOG_FILE" 2>&1
    white "Node.js 已安装: $(node -v)"
  fi
}

generate_uuid() {
  command -v uuidgen &>/dev/null && uuidgen || \
  (cat /proc/sys/kernel/random/uuid 2>/dev/null || head -c 16 /dev/urandom | xxd -p)
}

check_port() {
  local port=$1
  if lsof -i:"$port" &>/dev/null; then
    red "端口 $port 已被占用，请换一个端口"
    return 1
  fi
  return 0
}

check_status_for_menu() {
  if [ -f "$SERVICE_FILE" ]; then
    if systemctl is-active --quiet "$APP_NAME"; then
      echo -e "  当前状态: $(bright_green "运行中")"
    else
      echo -e "  当前状态: $(white "已停止")"
    fi
  else
    echo -e "  当前状态: $(yellow "未安装")"
  fi
  cyan "--------------------------------------------"
}

# --- 安装/重装 ---
install_service() {
  check_root
  mkdir -p "$(dirname "$LOG_FILE")"
  echo "--- 安装日志开始于 $(date) ---" > "$LOG_FILE"
  UUID_GENERATED=false

  if [ -f "$SERVICE_FILE" ]; then
    yellow "检测到服务已存在，将覆盖安装。"
  fi

  cyan "--- 自定义安装流程 ---"
  read -p "$(yellow "1. 请输入 用户UUID (留空自动生成): ")" UUID
  [ -z "$UUID" ] && UUID_GENERATED=true && UUID=$(generate_uuid)

  while true; do
    read -p "$(yellow "2. 请输入 HTTP服务端口 [默认: 3000]: ")" PORT
    [ -z "$PORT" ] && PORT=3000
    [[ "$PORT" =~ ^[0-9]+$ ]] && [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ] || { red "请输入 1-65535 的有效端口号"; continue; }
    check_port "$PORT" || continue
    break
  done

  read -p "$(yellow "3. 请输入 固定隧道密钥 (ARGO_AUTH): ")" ARGO_AUTH
  read -p "$(yellow "4. 请输入 固定隧道域名 (ARGO_DOMAIN): ")" ARGO_DOMAIN

  while true; do
    read -p "$(yellow "5. 请输入 Argo隧道端口 [默认: 8001]: ")" ARGO_PORT
    [ -z "$ARGO_PORT" ] && ARGO_PORT=8001
    [[ "$ARGO_PORT" =~ ^[0-9]+$ ]] && [ "$ARGO_PORT" -ge 1 ] && [ "$ARGO_PORT" -le 65535 ] && break
    red "请输入 1-65535 的有效端口号。"
  done

  read -p "$(yellow "6. 请输入 优选域名或IP [默认: cdns.doon.eu.org]: ")" CFIP
  [ -z "$CFIP" ] && CFIP="cdns.doon.eu.org"
  read -p "$(yellow "7. 请输入 订阅路径 [默认: sub]: ")" SUB_PATH
  [ -z "$SUB_PATH" ] && SUB_PATH="sub"
  read -p "$(yellow "8. 请输入 节点名称前缀 [默认: VIs]: ")" NAME
  [ -z "$NAME" ] && NAME="VIs"
  read -p "$(yellow "9. 请输入 书签管理密码 [默认: 123456]: ")" ADMIN_PASSWORD
  [ -z "$ADMIN_PASSWORD" ] && ADMIN_PASSWORD="123456"

  if [ -z "$ARGO_DOMAIN" ] || [ -z "$ARGO_AUTH" ]; then
    red "ARGO_DOMAIN 和 ARGO_AUTH 为必填项"; return 1
  fi

  CFPORT=443

  clear
  cyan "--- 请确认配置 ---"
  echo -e "UUID        : $(green "$UUID")"
  [ "$UUID_GENERATED" = true ] && bright_green "  (已自动生成)"
  echo -e "HTTP端口    : $(green "$PORT")"
  echo -e "隧道密钥    : $(green "[已隐藏]")"
  echo -e "隧道域名    : $(green "$ARGO_DOMAIN")"
  echo -e "Argo端口    : $(green "$ARGO_PORT")"
  echo -e "优选IP/域名 : $(green "$CFIP")"
  echo -e "订阅路径    : $(green "$SUB_PATH")"
  echo -e "节点名称前缀: $(green "$NAME")"
  echo -e "书签密码    : $(green "$ADMIN_PASSWORD")"
  cyan "--------------------------------"
  read -p "$(yellow "确认开始安装? (y/n): ")" confirm
  [[ ! "$confirm" =~ [yY] ]] && yellow "安装已取消" && return

  bright_green "开始安装... 日志: $LOG_FILE"
  [ -f "$SERVICE_FILE" ] && systemctl stop "$APP_NAME" &>/dev/null || true
  install_nodejs
  id -u "$APP_NAME" &>/dev/null || useradd -r -m -s /usr/sbin/nologin "$APP_NAME"

  white "下载项目文件..."
  curl -L -o "$ZIP_FILE" "$ZIP_URL" >> "$LOG_FILE" 2>&1
  rm -rf "$INSTALL_DIR"; mkdir -p "$INSTALL_DIR"
  unzip -q "$ZIP_FILE" -d "$INSTALL_DIR"; rm -f "$ZIP_FILE"

  cd "$INSTALL_DIR"
  white "安装 npm 依赖..."
  npm install --omit=dev --silent >> "$LOG_FILE" 2>&1 || { red "npm install 失败"; exit 1; }

  white "创建配置文件..."
  cat > "$CONFIG_FILE_ENV" <<EOF
PORT=${PORT}
UUID=${UUID}
NAME=${NAME}
ARGO_DOMAIN=${ARGO_DOMAIN}
ARGO_AUTH=${ARGO_AUTH}
ARGO_PORT=${ARGO_PORT}
CFIP=${CFIP}
CFPORT=${CFPORT}
NEZHA_SERVER=
NEZHA_PORT=
NEZHA_KEY=
UPLOAD_URL=
PROJECT_URL=https://www.google.com
AUTO_ACCESS=false
FILE_PATH=./tmp
SUB_PATH=${SUB_PATH}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
NODE_ENV=production
EOF

  chown -R "$APP_NAME":"$APP_NAME" "$INSTALL_DIR"
  chmod 600 "$CONFIG_FILE_ENV"
  bright_green "权限设置完成"

  white "创建 systemd 服务..."
  NODE_PATH=$(command -v node)
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=$APP_NAME Service
After=network.target
[Service]
Type=simple
User=$APP_NAME
Group=$APP_NAME
WorkingDirectory=$INSTALL_DIR
ExecStart=$NODE_PATH index.js
Restart=always
EnvironmentFile=$CONFIG_FILE_ENV
[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable "$APP_NAME"
  systemctl start "$APP_NAME"

  bright_green "🎉 安装完成！服务已启动并开机自启。"
  yellow "请等待1分钟后使用查看订阅链接。"

  # 创建快捷命令
  SCRIPT_PATH=$(realpath "$0")
  ln -sf "$SCRIPT_PATH" "$SHORTCUT_PATH"
  bright_green "快捷命令 '$SHORTCUT_CMD' 已创建。可直接输入 '$SHORTCUT_CMD' 运行脚本。"
}

# --- 卸载 ---
uninstall_service() {
  check_root
  read -p "$(yellow "确定删除 '$APP_NAME' 及所有文件? (y/n): ")" confirm
  [[ ! "$confirm" =~ [yY] ]] && cyan "卸载已取消" && return
  systemctl stop "$APP_NAME" &>/dev/null || true
  systemctl disable "$APP_NAME" &>/dev/null || true
  rm -f "$SERVICE_FILE"
  systemctl daemon-reload
  pkill -u "$APP_NAME" || true
  userdel -r "$APP_NAME" &>/dev/null || true
  rm -rf "$INSTALL_DIR"
  rm -f "$SHORTCUT_PATH"
  bright_green "服务已卸载，快捷命令已删除。"
}

# --- 重启 ---
restart_service() {
  check_root
  if systemctl restart "$APP_NAME" 2>/dev/null; then
    bright_green "服务已重启"
  else
    red "服务不存在或重启失败"
  fi
}

# --- 查看状态 ---
view_status() { systemctl --no-pager status "$APP_NAME"; }

# --- 查看订阅 ---
view_subscription() {
  if [ ! -f "$SERVICE_FILE" ]; then red "服务未安装"; sleep 2; return; fi
  if [ -f "$CONFIG_FILE_SUB" ] && [ -s "$CONFIG_FILE_SUB" ]; then
    cyan "\n--- 订阅链接 ---"
    cat "$CONFIG_FILE_SUB"
    echo
    cyan "----------------"
  else
    red "订阅文件不存在或为空"
    yellow "请确保服务运行并等待1-2分钟后重试"
  fi
}

# --- 修改配置 ---
edit_variables() {
  check_root
  [ ! -f "$CONFIG_FILE_ENV" ] && red "配置文件不存在，请先安装服务" && sleep 2 && return
  cp "$CONFIG_FILE_ENV" "$CONFIG_FILE_ENV.bak"

  while true; do
    clear
    export $(grep -v '^\s*#' "$CONFIG_FILE_ENV" | xargs)

    cyan "======================== 修改配置 ========================"
    echo
    cyan "====== 基础设置 ======"
    echo -e " $(yellow "1.") 用户UUID      : $(green "$UUID")"
    echo -e " $(yellow "2.") 节点名称前缀  : $(green "$NAME")"
    echo -e " $(yellow "3.") HTTP服务端口  : $(green "$PORT")"
    echo
    cyan "====== Argo 隧道设置 ======"
    echo -e " $(yellow "4.") 固定隧道域名  : $(green "$ARGO_DOMAIN")"
    echo -e " $(yellow "5.") 固定隧道密钥  : $(green "[保密]")"
    echo -e " $(yellow "6.") Argo隧道端口  : $(green "$ARGO_PORT")"
    echo
    cyan "====== 节点设置 ======"
    echo -e " $(yellow "7.") 优选域名或IP  : $(green "$CFIP")"
    echo -e " $(yellow "8.") 节点端口      : $(green "$CFPORT")"
    echo -e " $(yellow "9.") 订阅路径      : $(green "$SUB_PATH")"
    echo
    cyan "====== 哪吒监控设置 (留空则禁用) ======"
    echo -e " $(yellow "10.") 哪吒服务器    : $(green "$NEZHA_SERVER")"
    echo -e " $(yellow "11.") 哪吒端口      : $(green "$NEZHA_PORT")"
    echo -e " $(yellow "12.") 哪吒密钥      : $(green "$NEZHA_KEY")"
    echo
    cyan "====== 高级设置 ======"
    echo -e " $(yellow "13.") 订阅上传地址  : $(green "$UPLOAD_URL")"
    echo -e " $(yellow "14.") 项目分配域名  : $(green "$PROJECT_URL")"
    echo -e " $(yellow "15.") 自动访问保活  : $(green "$AUTO_ACCESS")"
    echo -e " $(yellow "16.") 运行目录      : $(green "$FILE_PATH")"
    echo -e " $(yellow "17.") 书签管理密码  : $(green "$ADMIN_PASSWORD")"
    echo
    cyan "---------------------------------------------------------"
    echo -e " $(yellow "S.") $(yellow "保存并重启服务")"
    echo -e " $(yellow "0.") $(yellow "放弃修改并退出")"
    cyan "========================================================="
    read -rp "$(yellow "请输入选项: ")" choice

    update_config_value() { sed -i "s|^$1=.*|$1=$2|" "$CONFIG_FILE_ENV"; }

    case $choice in
      1)  read -p "$(yellow "请输入新的 UUID (留空则自动生成): ")" NEW_VALUE; [ -z "$NEW_VALUE" ] && NEW_VALUE=$(generate_uuid); update_config_value "UUID" "$NEW_VALUE";;
      2)  read -p "$(yellow "请输入新的 NAME: ")" NEW_VALUE; update_config_value "NAME" "$NEW_VALUE";;
      3)  read -p "$(yellow "请输入新的 PORT: ")" NEW_VALUE; update_config_value "PORT" "$NEW_VALUE";;
      4)  read -p "$(yellow "请输入新的 ARGO_DOMAIN: ")" NEW_VALUE; update_config_value "ARGO_DOMAIN" "$NEW_VALUE";;
      5)  read -p "$(yellow "请输入新的 ARGO_AUTH: ")" NEW_VALUE; update_config_value "ARGO_AUTH" "$NEW_VALUE";;
      6)  read -p "$(yellow "请输入新的 ARGO_PORT: ")" NEW_VALUE; update_config_value "ARGO_PORT" "$NEW_VALUE";;
      7)  read -p "$(yellow "请输入新的 CFIP: ")" NEW_VALUE; update_config_value "CFIP" "$NEW_VALUE";;
      8)  read -p "$(yellow "请输入新的 CFPORT: ")" NEW_VALUE; update_config_value "CFPORT" "$NEW_VALUE";;
      9)  read -p "$(yellow "请输入新的 SUB_PATH: ")" NEW_VALUE; update_config_value "SUB_PATH" "$NEW_VALUE";;
      10) read -p "$(yellow "请输入新的 NEZHA_SERVER: ")" NEW_VALUE; update_config_value "NEZHA_SERVER" "$NEW_VALUE";;
      11) read -p "$(yellow "请输入新的 NEZHA_PORT: ")" NEW_VALUE; update_config_value "NEZHA_PORT" "$NEW_VALUE";;
      12) read -p "$(yellow "请输入新的 NEZHA_KEY: ")" NEW_VALUE; update_config_value "NEZHA_KEY" "$NEW_VALUE";;
      13) read -p "$(yellow "请输入新的 UPLOAD_URL: ")" NEW_VALUE; update_config_value "UPLOAD_URL" "$NEW_VALUE";;
      14) read -p "$(yellow "请输入新的 PROJECT_URL: ")" NEW_VALUE; update_config_value "PROJECT_URL" "$NEW_VALUE";;
      15) read -p "$(yellow "请输入新的 AUTO_ACCESS (true/false): ")" NEW_VALUE; update_config_value "AUTO_ACCESS" "$NEW_VALUE";;
      16) read -p "$(yellow "请输入新的 FILE_PATH: ")" NEW_VALUE; update_config_value "FILE_PATH" "$NEW_VALUE";;
      [sS]) rm "$CONFIG_FILE_ENV.bak"; bright_green "正在保存配置并重启服务..."; restart_service; sleep 1; break;;
      0) mv "$CONFIG_FILE_ENV.bak" "$CONFIG_FILE_ENV"; break;;
      *) red "无效选项，请重新输入。"; sleep 1;;
    esac
  done
}

# --- 主菜单 ---
main() {
  clear
  check_root
  check_system
  check_dependencies

  while true; do
    clear
    white "==========================================="
    white "        Nodejs-Argo 管理脚本"
    white "==========================================="
    check_status_for_menu
    install_option_text="安装服务"; [ -f "$SERVICE_FILE" ] && install_option_text="重装服务"

    cyan "====== 基础功能 ======"
    echo -e " $(green "1.") ${install_option_text}"
    echo -e " $(green "2.") 卸载服务"
    echo -e " $(green "3.") 重启服务"
    echo -e " $(green "4.") 查看订阅链接"
    cyan "--------------------------------------------"
    cyan "====== 管理功能 ======"
    echo -e " $(green "5.") 修改配置"
    echo -e " $(green "6.") 查看服务状态"
    cyan "--------------------------------------------"
    echo -e " $(green "0.") $(yellow "退出脚本")"
    cyan "============================================"
    read -rp "$(yellow "请输入选项 [0-6]: ")" num

    case $num in
      1) install_service ;;
      2) uninstall_service ;;
      3) restart_service ;;
      4) view_subscription ;;
      5) edit_variables ;;
      6) view_status ;;
      0) exit 0 ;;
      *) red "无效选项" ;;
    esac
    read -n 1 -s -r -p "按任意键返回主菜单..."
    echo ""
  done
}

main
