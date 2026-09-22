# 四象 · 公网部署（Docker + Caddy 自动 HTTPS）

把后端部署到一台公网服务器，手机随时随地可用。前提：

1. 一台 Linux 服务器（轻量应用服务器即可，1C2G 足够，如腾讯云/阿里云轻量 ~¥50-100/年）
2. 一个域名（如 `api.example.com`），解析 A 记录到服务器 IP
3. 服务器防火墙放行 80/443（Caddy 自动申请证书）与 22

## 步骤

### 1. 服务器上安装 Docker

```bash
curl -fsSL https://get.docker.com | sh
```

### 2. 上传本目录到服务器

在本机（Windows）项目根目录执行（或手动上传 deploy/ 文件夹）：

```bash
scp -r deploy root@你的服务器IP:/opt/sixiang
```

### 3. 修改环境变量

```bash
ssh root@你的服务器IP
cd /opt/sixiang
cp .env.example .env
nano .env
```

必改两项：
- `API_DOMAIN=api.你的域名.com`
- `JWT_SECRET=` 换成强随机值（例如 `openssl rand -hex 32` 的输出）

### 4. 启动

```bash
docker compose up -d --build
```

完成后 API 地址为 `https://api.你的域名.com`（Caddy 自动申请并续期证书）。

### 5. App 端配置

iPhone 打开「四象」→ 登录页右上角服务器图标（或「我的 → 设置 → 服务器地址」）→ 填 `https://api.你的域名.com` → 注册/登录即可。

## 结构说明

| 文件 | 用途 |
| --- | --- |
| docker-compose.yml | postgres + api + caddy 三容器编排 |
| Caddyfile | 反向代理 api 容器并自动 HTTPS |
| api.Dockerfile | 复用 server/ 源码构建 API 镜像 |
| .env.example | 环境变量模板 |

> 注：deploy 目录与 server/ 目录共用同一份后端源码（构建时复制），两者发布配置一致。
