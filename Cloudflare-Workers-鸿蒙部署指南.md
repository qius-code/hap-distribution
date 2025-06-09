# 🚀 鸿蒙HAP包分发 - Cloudflare Workers部署指南

## 📋 项目概述

本项目基于Cloudflare Workers构建鸿蒙(HarmonyOS)应用分发系统，完全支持鸿蒙系统的严格要求：
- ✅ **HTTPS协议支持**
- ✅ **HTTP Range请求支持**（返回206状态码）
- ✅ **域名一致性保证**
- ✅ **正确的Content-Type设置**
- ✅ **CORS跨域配置**

## 🎯 为什么选择Cloudflare Workers？

相比其他方案：
- **GitHub Pages**: 不支持Range请求（只返回200状态码）❌
- **jsDelivr CDN**: 部分地区访问不稳定❌
- **Cloudflare Workers**: 完美支持所有鸿蒙要求✅

## 🛠️ 前置准备

### 1. 账号准备
- [Cloudflare账号](https://dash.cloudflare.com/) (免费版即可)
- GitHub仓库（存放HAP包和配置文件）

### 2. 环境要求
- Node.js v20+ (Wrangler要求)
- Git命令行工具
- 已签名的HAP包文件

### 3. 检查Node.js版本
```bash
# 检查当前版本
node --version

# 如果版本低于v20，使用nvm升级
nvm install v20.19.2
nvm use v20.19.2
```

## 🚀 快速部署

### 第一步：项目准备
```bash
# 克隆项目
git clone https://github.com/your-username/your-repo.git
cd your-repo

# 确保HAP包在正确位置
ls hap/AppSigned.hap
```

### 第二步：登录Cloudflare
```bash
# 首次使用需要登录
npx wrangler login
```
这会打开浏览器窗口，完成OAuth授权。

### 第三步：一键部署
```bash
# 运行自动化部署脚本
./deploy-cloudflare.sh
```

## 📁 项目文件结构

```
hap-distribution/
├── hap/
│   ├── AppSigned.hap                 # 鸿蒙应用包
│   └── manifest-jsdelivr.json5       # 应用配置文件
├── asset/
│   ├── icon29.png                    # 应用小图标
│   └── icon1024.png                  # 应用大图标
├── cloudflare-worker.js              # Worker核心代码
├── wrangler.toml                     # Worker配置文件
├── deploy-cloudflare.sh              # 自动化部署脚本
└── harmony-download.html             # 下载页面
```

## ⚙️ 核心配置文件

### 1. wrangler.toml
```toml
name = "harmony-hap-distribution"
main = "cloudflare-worker.js"
compatibility_date = "2024-03-01"

# 鸿蒙HAP包分发专用Worker
# 支持Range请求，返回206状态码
```

### 2. cloudflare-worker.js核心特性
```javascript
// 关键特性：
// 1. 支持Range请求处理
// 2. 返回正确的206状态码
// 3. 设置正确的Content-Type
// 4. 配置CORS头部
// 5. 代理GitHub Raw文件
```

### 3. manifest-jsdelivr.json5配置
```json5
{
  "app": {
    "bundleName": "com.app.service.zlx",
    "version": "1.0.31",
    "versionName": "1.0.31",
    "deployDomain": "harmony-hap-distribution.username.workers.dev",
    "modules": [{
      "packageUrl": "https://harmony-hap-distribution.username.workers.dev/hap/AppSigned.hap",
      "packageHash": "da20ff5596643d7ab12b729395d77471d71a438d5522bee5ff1267d5f863a17e"
    }],
    "icons": {
      "normal": "https://harmony-hap-distribution.username.workers.dev/asset/icon29.png",
      "large": "https://harmony-hap-distribution.username.workers.dev/asset/icon1024.png"
    }
  }
}
```

## 🔧 手动部署步骤

### 1. 安装Wrangler CLI
```bash
npm install -g wrangler
# 或使用npx
npx wrangler --version
```

### 2. 初始化Worker项目
```bash
# 创建wrangler.toml配置文件
cat > wrangler.toml << EOF
name = "harmony-hap-distribution"
main = "cloudflare-worker.js"
compatibility_date = "2024-03-01"
EOF
```

### 3. 部署Worker
```bash
# 部署到Cloudflare
npx wrangler deploy

# 查看部署状态
npx wrangler deployments list
```

### 4. 更新应用配置
```bash
# 使用脚本自动更新manifest文件
python3 -c "
import json
import hashlib

# 计算HAP包哈希
with open('hap/AppSigned.hap', 'rb') as f:
    hash_value = hashlib.sha256(f.read()).hexdigest()

# 更新配置文件
with open('hap/manifest-jsdelivr.json5', 'r') as f:
    data = json.load(f)

data['app']['deployDomain'] = 'your-worker.workers.dev'
data['app']['modules'][0]['packageHash'] = hash_value
data['app']['modules'][0]['packageUrl'] = 'https://your-worker.workers.dev/hap/AppSigned.hap'

with open('hap/manifest-jsdelivr.json5', 'w') as f:
    json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
"
```

## 🧪 测试部署

### 1. 测试Worker可访问性
```bash
# 测试基本访问
curl -I "https://your-worker.workers.dev/"

# 测试HAP包下载
curl -I "https://your-worker.workers.dev/hap/AppSigned.hap"
```

### 2. 测试Range请求支持（关键！）
```bash
# 测试分片下载
curl -I -H "Range: bytes=0-1023" "https://your-worker.workers.dev/hap/AppSigned.hap"

# 应该返回：HTTP/2 206 Partial Content
```

### 3. 测试配置文件
```bash
# 测试manifest文件
curl "https://your-worker.workers.dev/hap/manifest-jsdelivr.json5"
```

## 📱 鸿蒙安装设置

### 1. 生成DeepLink
```bash
# URL编码manifest地址
MANIFEST_URL="https://your-worker.workers.dev/hap/manifest-jsdelivr.json5"
ENCODED_URL=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$MANIFEST_URL', safe=''))")
DEEPLINK="store://enterprise/manifest?url=$ENCODED_URL"

echo "DeepLink: $DEEPLINK"
```

### 2. 下载页面生成
```bash
# 运行页面生成器
./generate-download-page.sh

# 生成文件：
# - harmony-download.html (完整页面)
# - harmony-download-widget.html (组件)
```

### 3. 用户安装流程
1. 用户在**华为浏览器**中访问下载页面
2. 点击"立即下载"按钮
3. 系统自动跳转到鸿蒙应用商店
4. 完成应用安装

## 🔍 故障排除

### 1. Worker无法访问
```bash
# 检查部署状态
npx wrangler deployments list

# 查看Worker日志
npx wrangler tail

# 重新部署
npx wrangler deploy
```

### 2. Range请求失败
- 检查cloudflare-worker.js文件
- 确认Range请求处理逻辑正确
- 验证返回206状态码

### 3. 鸿蒙安装失败
- 确认HAP包已正确签名
- 检查manifest.json5配置
- 验证所有URL域名一致
- 确保使用华为浏览器

### 4. 域名不一致错误
```bash
# 确保所有URL使用相同域名
grep -r "workers.dev" hap/manifest-jsdelivr.json5
grep -r "workers.dev" harmony-download.html
```

## 📊 监控和维护

### 1. Worker性能监控
```bash
# 查看实时日志
npx wrangler tail

# 查看Worker统计
npx wrangler d1 list  # 如果使用D1数据库
```

### 2. 更新HAP包
```bash
# 使用更新脚本
./update-hap.sh new-app.hap

# 手动更新
cp new-app.hap hap/AppSigned.hap
npx wrangler deploy
```

### 3. 备份恢复
```bash
# 备份配置
cp hap/manifest-jsdelivr.json5 backup/
cp wrangler.toml backup/

# 恢复配置
cp backup/manifest-jsdelivr.json5 hap/
cp backup/wrangler.toml ./
npx wrangler deploy
```

## 💰 成本分析

### Cloudflare Workers免费额度
- **请求数**: 100,000次/天
- **CPU时间**: 10ms/请求
- **存储**: Worker脚本最大1MB

### 超出免费额度收费
- **附加请求**: $0.15/百万请求
- **附加CPU时间**: $12.50/百万GB-秒

**结论**: 对于中小规模应用分发，**完全免费**！

## 🔒 安全考虑

### 1. HTTPS强制
- 所有请求强制HTTPS
- 设置安全响应头

### 2. CORS配置
- 允许特定域名访问
- 防止恶意跨域请求

### 3. HAP包完整性
- SHA256哈希验证
- 防止文件被篡改

## 🚀 高级功能

### 1. 自定义域名
```bash
# 添加自定义域名（需要Cloudflare托管域名）
npx wrangler route add "hap.yourdomain.com/*" harmony-hap-distribution
```

### 2. 环境管理
```toml
# wrangler.toml
[env.production]
name = "harmony-hap-prod"

[env.staging]
name = "harmony-hap-staging"
```

### 3. 密钥管理
```bash
# 设置环境变量
npx wrangler secret put API_KEY
npx wrangler secret list
```

## 📚 相关文档

- [Cloudflare Workers文档](https://developers.cloudflare.com/workers/)
- [Wrangler CLI指南](https://developers.cloudflare.com/workers/wrangler/)
- [鸿蒙应用分发指南](https://developer.harmonyos.com/)

## 🆘 技术支持

如果部署过程中遇到问题：

1. **检查日志**: `npx wrangler tail`
2. **验证配置**: 确认所有URL域名一致
3. **测试Range**: 验证206状态码返回
4. **重新部署**: `npx wrangler deploy`

---

## ✅ 部署成功标志

当看到以下输出时，说明部署成功：

```bash
✅ Cloudflare Worker部署成功
🌐 Worker URL: https://harmony-hap-distribution.username.workers.dev
✅ Range请求支持正常 - 返回206状态码
✅ 鸿蒙下载页面生成成功
🎉 部署完成！Cloudflare Workers已就绪 🎉
```

现在您的鸿蒙应用分发系统已经完全就绪！🚀 