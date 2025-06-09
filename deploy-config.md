# HAP包分发配置指南

## GitHub + jsDelivr 部署步骤

### 1. 仓库配置

确保您的GitHub仓库具有以下结构：
```
hap-distribution/
├── hap/
│   ├── AppSigned.hap              # 您的HAP安装包
│   ├── manifest-jsdelivr.json5     # jsDelivr CDN配置
│   ├── manifest.json5             # 标准配置
│   └── manifest-worker.json5      # Cloudflare Worker配置
├── asset/                         # 资源文件
│   ├── icon29.png                 # 应用小图标
│   └── icon1024.png               # 应用大图标
├── index.html                     # 分发页面
└── README.md                      # 项目说明
```

### 2. 配置文件说明

#### manifest-jsdelivr.json5 (推荐用于生产环境)
使用jsDelivr CDN加速，全球访问速度最佳：

```json5
{
  "app": {
    "bundleName": "com.app.service.zlx",
    "bundleType": "app", 
    "versionCode": 1000035,
    "versionName": "1.0.31",
    "label": "灵犀服务UAT",
    "deployDomain": "your-github-username.github.io",
    "icons": {
      "normal": "https://cdn.jsdelivr.net/gh/your-username/hap-distribution@main/asset/icon29.png",
      "large": "https://cdn.jsdelivr.net/gh/your-username/hap-distribution@main/asset/icon1024.png"
    },
    "minAPIVersion": "5.0.5(17)",
    "targetAPIVersion": "5.0.5(17)",
    "modules": [{
      "name": "entry",
      "type": "entry", 
      "deviceTypes": ["phone", "tablet", "2in1"],
      "packageUrl": "https://cdn.jsdelivr.net/gh/your-username/hap-distribution@main/hap/AppSigned.hap",
      "packageHash": "your-package-hash-here"
    }]
  },
  "sign": "your-signature-here"
}
```

### 3. 自动化部署配置

#### GitHub Actions 配置 (.github/workflows/deploy.yml)

```yaml
name: Deploy HAP Distribution

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        
    - name: Calculate HAP file hash
      run: |
        cd hap
        echo "PACKAGE_HASH=$(sha256sum AppSigned.hap | cut -d' ' -f1)" >> $GITHUB_ENV
        
    - name: Update manifest with new hash
      run: |
        sed -i "s/\"packageHash\":\"[^\"]*\"/\"packageHash\":\"$PACKAGE_HASH\"/g" hap/manifest-jsdelivr.json5
        
    - name: Deploy to GitHub Pages
      uses: peaceiris/actions-gh-pages@v3
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        publish_dir: ./
```

### 4. 快速部署脚本

#### deploy.sh
```bash
#!/bin/bash

# HAP包分发部署脚本
echo "🚀 开始部署HAP包分发系统..."

# 检查必要文件
if [ ! -f "hap/AppSigned.hap" ]; then
    echo "❌ 错误: 未找到 hap/AppSigned.hap 文件"
    exit 1
fi

# 计算HAP文件哈希值
echo "📝 计算HAP文件哈希值..."
PACKAGE_HASH=$(sha256sum hap/AppSigned.hap | cut -d' ' -f1)
echo "🔢 HAP文件哈希: $PACKAGE_HASH"

# 获取GitHub仓库信息
REPO_URL=$(git remote get-url origin)
USERNAME=$(echo $REPO_URL | sed -n 's/.*github\.com[:/]\([^/]*\)\/.*/\1/p')
REPO_NAME=$(basename -s .git $REPO_URL)

echo "👤 GitHub用户名: $USERNAME"
echo "📁 仓库名称: $REPO_NAME"

# 更新manifest文件
echo "🔄 更新manifest配置..."

# 更新jsDelivr配置
sed -i.bak "s|https://cdn\.jsdelivr\.net/gh/[^/]*/[^/]*|https://cdn.jsdelivr.net/gh/$USERNAME/$REPO_NAME|g" hap/manifest-jsdelivr.json5
sed -i.bak "s/\"packageHash\":\"[^\"]*\"/\"packageHash\":\"$PACKAGE_HASH\"/g" hap/manifest-jsdelivr.json5

# 提交更改
echo "📤 提交更改到GitHub..."
git add .
git commit -m "🚀 Deploy: Update HAP package and manifest (hash: ${PACKAGE_HASH:0:8})"
git push origin main

echo "✅ 部署完成!"
echo "🌐 您的HAP包将在以下地址可用:"
echo "   - jsDelivr CDN: https://cdn.jsdelivr.net/gh/$USERNAME/$REPO_NAME@main/hap/AppSigned.hap"
echo "   - GitHub Pages: https://$USERNAME.github.io/$REPO_NAME/"
echo ""
echo "⏰ 注意: jsDelivr CDN可能需要几分钟时间同步更新"
```

### 5. 域名配置

#### 自定义域名设置

1. **GitHub Pages设置**
   - 进入仓库 Settings → Pages
   - 选择 Source: Deploy from a branch
   - 选择 Branch: main / (root)
   - 如有自定义域名，在Custom domain中填入

2. **DNS配置**
   ```
   # CNAME记录
   www.yourdomain.com → your-username.github.io
   
   # A记录 (GitHub Pages IP)
   185.199.108.153
   185.199.109.153  
   185.199.110.153
   185.199.111.153
   ```

### 6. 性能优化

#### CDN缓存策略
- jsDelivr自动缓存，全球CDN节点
- 支持HTTP/2和Brotli压缩
- 自动HTTPS加密

#### 备用CDN配置
```javascript
// 多CDN降级策略
const cdnUrls = [
  'https://cdn.jsdelivr.net/gh/{username}/{repo}@main/',
  'https://fastly.jsdelivr.net/gh/{username}/{repo}@main/',
  'https://gcore.jsdelivr.net/gh/{username}/{repo}@main/',
  'https://{username}.github.io/{repo}/'
];
```

### 7. 监控和分析

#### 访问统计
- 使用 GitHub Pages 内置统计
- 集成 Google Analytics（可选）
- jsDelivr 提供详细的CDN使用统计

#### 错误监控
```javascript
// 下载错误监控
window.addEventListener('error', function(e) {
  console.error('HAP下载错误:', e);
  // 发送错误信息到监控服务
});
```

### 8. 常见问题解决

#### jsDelivr缓存刷新
访问以下URL强制刷新缓存：
```
https://purge.jsdelivr.net/gh/{username}/{repo}@main/hap/AppSigned.hap
```

#### GitHub Pages 构建失败
- 检查文件大小限制（单文件<100MB，仓库<1GB）
- 确保没有Jekyll冲突（添加.nojekyll文件）
- 检查文件名是否包含特殊字符

#### HAP包安装失败
- 验证包签名是否正确
- 检查设备HarmonyOS版本兼容性
- 确认包哈希值是否匹配

---

🎉 按照以上步骤配置后，您的HAP包就可以通过GitHub + jsDelivr进行全球分发了！ 