<div align="center">

## nodejs-argo-nav隧道代理

[![npm version](https://img.shields.io/npm/v/nodejs-argo.svg)](https://www.npmjs.com/package/nodejs-argo)
[![npm downloads](https://img.shields.io/npm/dm/nodejs-argo.svg)](https://www.npmjs.com/package/nodejs-argo)
[![License](https://img.shields.io/npm/l/nodejs-argo.svg)](https://github.com/eooce/nodejs-argo/blob/main/LICENSE)

nodejs-argo是一个强大的Argo隧道部署工具，专为PaaS平台和游戏玩具平台设计。它支持多种代理协议（VLESS、VMess、Trojan等），并集成了哪吒探针功能。

---
</div>

### 🚀 一键安装脚本

```bash
bash <(curl -sSL https://raw.githubusercontent.com/myouhi/nodejs-argo/main/install.sh)
```

### 📋 环境变量

| 变量名 | 是否必须 | 默认值 | 说明 |
|--------|----------|--------|------|
| UPLOAD_URL | 否 | - | 订阅上传地址 |
| PROJECT_URL | 否 | https://www.google.com | 项目分配的域名 |
| AUTO_ACCESS | 否 | false | 是否开启自动访问保活 |
| PORT | 否 | 3000 | HTTP服务监听端口 |
| ARGO_PORT | 否 | 8001 | Argo隧道端口 |
| UUID | 否 | 89c13786-25aa-4520-b2e7-12cd60fb5202 | 用户UUID |
| NEZHA_SERVER | 否 | - | 哪吒面板域名 |
| NEZHA_PORT | 否 | - | 哪吒端口 |
| NEZHA_KEY | 否 | - | 哪吒密钥 |
| ARGO_DOMAIN | 否 | - | Argo固定隧道域名 |
| ARGO_AUTH | 否 | - | Argo固定隧道密钥 |
| CFIP | 否 | cdns.doon.eu.org | 节点优选域名或IP |
| CFPORT | 否 | 443 | 节点端口 |
| NAME | 否 | Vls | 节点名称前缀 |
| FILE_PATH | 否 | ./tmp | 运行目录 |
| SUB_PATH | 否 | sub | 订阅路径 |
| ADMIN_PASSWORD | 否 | 123456 | 后台管理密码 |

### 🔗 订阅地址

- 标准端口：`https://your-domain.com/sub`
- 非标端口：`http://your-domain.com:port/sub`
- 导航站页：`http://your-domain.com:port`
- 管理后台：`http://your-domain.com:port/admin`

---
  
### 免责声明
* 本程序仅供学习了解, 非盈利目的，请于下载后 24 小时内删除, 不得用作任何商业用途, 文字、数据及图片均有所属版权, 如转载须注明来源。
* 使用本程序必循遵守部署免责声明，使用本程序必循遵守部署服务器所在地、所在国家和用户所在国家的法律法规, 程序作者不对使用者任何不当行为负责。
