#!/bin/sh

TMP_FILE="/tmp/install_payload_$$"
trap 'rm -f "$TMP_FILE"' EXIT

if [ "$(id -u)" -ne 0 ]; then
  echo "错误：此脚本必须以 root 用户身份运行。" >&2
  exit 1
fi

OS_FAMILY=""
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS_ID=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
  ID_LIKE=$(echo "$ID_LIKE" | tr '[:upper:]' '[:lower:]')
  
  if echo "$ID_LIKE" | grep -q "debian" || [ "$OS_ID" = "debian" ] || [ "$OS_ID" = "ubuntu" ]; then
    OS_FAMILY="debian"
  elif echo "$ID_LIKE" | grep -q "rhel" || echo "$ID_LIKE" | grep -q "centos" || [ "$OS_ID" = "centos" ] || [ "$OS_ID" = "rhel" ] || [ "$OS_ID" = "fedora" ] || [ "$OS_ID" = "almalinux" ] || [ "$OS_ID" = "rocky" ]; then
    OS_FAMILY="rhel"
  elif [ "$OS_ID" = "alpine" ]; then
    OS_FAMILY="alpine"
  fi
fi

if [ -z "$OS_FAMILY" ]; then
  echo "错误：无法确定操作系统类型，或不支持此系统。" >&2; exit 1;
fi

ensure_packages() {
  for pkg in "$@"; do
    if ! command -v "$pkg" >/dev/null 2>&1; then
      echo "--> 未找到命令 '$pkg'，正在尝试自动安装..."
      case "$OS_FAMILY" in
        debian) 
            apt-get update -qq >/dev/null 2>&1 
            apt-get install -y -qq "$pkg" 
            ;;
        rhel) 
            if command -v dnf >/dev/null 2>&1; then dnf install -y "$pkg"; else yum install -y "$pkg"; fi 
            ;;
        alpine) 
            apk add --no-cache "$pkg" 
            ;;
      esac
      
      if ! command -v "$pkg" >/dev/null 2>&1; then
        echo "错误：自动安装 '$pkg' 失败，请手动安装后重试。" >&2; exit 1;
      else
        echo "--> '$pkg' 安装成功。";
      fi
    fi
  done
}

case "$OS_FAMILY" in
    alpine) ensure_packages "curl" "bash" ;;
    *)      ensure_packages "curl" ;;
esac

BASE_URL="https://raw.githubusercontent.com/myouhi/nodejs-argo/main"
STD_SCRIPT_URL="${BASE_URL}/nodejs-argo.sh"
ALPINE_SCRIPT_URL="${BASE_URL}/nodejs-argo-alpine.sh"

main() {
  url=$1
  os_name=$2
  shell_to_use=$3

  echo "--------------------------------------------------"
  echo "系统类型: $os_name"
  echo "检测脚本: $url"
  echo "执行方式: 使用 $shell_to_use 执行"
  echo "--------------------------------------------------"
  printf "您确定要继续吗? [y/N]: "
  read -r choice

  case "$choice" in
    y|Y)
      echo "--> 正在下载脚本到 $TMP_FILE ..."
      if ! curl -sSL -f -o "$TMP_FILE" "$url"; then
        echo "错误：下载脚本失败，请检查 URL 或网络连接。" >&2
        exit 1
      fi

      echo "--> 下载完成，正在启动安装程序..."
      chmod +x "$TMP_FILE"
      "$shell_to_use" "$TMP_FILE"
      
      echo "--> 安装脚本执行结束。"
      ;;
    *)
      echo "--> 操作已取消。"
      exit 0
      ;;
  esac
}

case "$OS_FAMILY" in
  debian) main "$STD_SCRIPT_URL" "Debian/Ubuntu" "bash" ;;
  rhel)   main "$STD_SCRIPT_URL" "CentOS/RHEL" "bash" ;;
  alpine) main "$ALPINE_SCRIPT_URL" "Alpine Linux" "bash" ;;
esac

exit 0
