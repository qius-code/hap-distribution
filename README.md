# HAP 包分发系统

基于 GitHub + jsDelivr 的鸿蒙HAP包分发解决方案，支持快速、稳定的应用包分发。

## 项目特点

- ✅ **鸿蒙官方兼容**: 完全符合鸿蒙HAP包分发要求和规范
- ✅ **全球CDN加速**: 基于 jsDelivr CDN，全球节点提供高速访问
- ✅ **Range请求支持**: 支持HTTP分片下载，返回206状态码（鸿蒙必需）
- ✅ **域名一致性**: 确保deployDomain与所有下载URL域名一致
- ✅ **免费可靠**: 利用GitHub仓库存储，jsDelivr提供免费CDN服务
- ✅ **自动更新**: 支持版本管理和自动更新检测
- ✅ **多域名备用**: 提供多个备用域名确保访问稳定性

## 快速开始

### 📱 安装HAP包

**方法1: 扫码安装**
使用鸿蒙设备扫描以下二维码或访问链接：

```
https://qius.hm-34r.pages.dev
```

**方法2: 直接下载**
```
https://cdn.jsdelivr.net/gh/qius-code/hap-distribution@main/hap/AppSigned.hap
```

### 🔧 项目部署

#### 自动化部署（推荐）

1. **Fork或克隆本项目**
   ```bash
   git clone https://github.com/qius-code/hap-distribution.git
   cd hap-distribution
   ```

2. **替换HAP文件**
   - 将您的 `.hap` 文件复制到 `hap/` 目录，命名为 `AppSigned.hap`

3. **运行自动化部署脚本**
   ```bash
   ./deploy.sh
   ```
   
   脚本将自动：
   - 计算HAP文件哈希值
   - 更新所有manifest配置文件
   - 创建必要的GitHub Pages配置
   - 提交并推送到GitHub

4. **启用GitHub Pages**
   - 访问您的仓库 Settings → Pages
   - 选择 Source: Deploy from a branch
   - 选择 Branch: main / (root)
   - 等待部署完成

#### 手动部署

1. **Fork本项目**到您的GitHub账户

2. **替换HAP文件**
   - 将您的 `.hap` 文件放置到 `hap/` 目录
   - 更新 `manifest-jsdelivr.json5` 配置

3. **修改配置**
   - 编辑 `hap/manifest-jsdelivr.json5`
   - 更新包信息、版本号、CDN地址等

4. **部署到GitHub Pages**
   - 在仓库设置中启用GitHub Pages
   - 选择source为main分支

### 🚀 快速更新HAP包

使用内置的更新工具快速替换HAP包：

```bash
# 更新HAP文件
./update-hap.sh /path/to/new/AppSigned.hap

# 更新HAP文件并指定版本号
./update-hap.sh /path/to/new/AppSigned.hap 1.0.32
```

工具会自动：
- 备份旧版本
- 计算新文件哈希
- 更新所有manifest配置
- 可选择自动提交推送

### 🔧 鸿蒙配置修复

确保完全符合鸿蒙官方要求：

```bash
# 修复鸿蒙配置（域名一致性、Range请求等）
./fix-harmony-config.sh

# 测试CDN Range请求支持
./test-range-support.sh
```

修复工具会：
- 检查域名一致性
- 选择最佳CDN配置
- 生成标准DeepLink
- 验证所有配置项

## 配置说明

### manifest配置文件

项目包含多个manifest配置文件：

- `manifest-jsdelivr.json5`: jsDelivr CDN配置
- `manifest.json5`: 标准配置
- `manifest-worker.json5`: Cloudflare Worker配置

### 主要配置项

```json5
{
  "app": {
    "bundleName": "com.app.service.zlx",
    "versionCode": 1000035,
    "versionName": "1.0.31",
    "deployDomain": "your-domain.pages.dev",
    "packageUrl": "https://cdn.jsdelivr.net/gh/username/repo@main/hap/AppSigned.hap"
  }
}
```

## 备用访问地址

为确保服务稳定性，我们提供多个备用域名：

1. **主域名**: `https://qius.hm-34r.pages.dev`
2. **jsDelivr CDN**: `https://cdn.jsdelivr.net/gh/qius-code/hap-distribution@main/`
3. **GitHub Pages**: `https://qius-code.github.io/hap-distribution/`

## 技术架构

- **存储**: GitHub Repository
- **CDN**: jsDelivr全球CDN网络
- **前端**: 静态HTML页面
- **后端**: Cloudflare Workers (可选)

## 版本管理

- 支持语义化版本号 (Semantic Versioning)
- 自动生成版本对比和更新检测
- 支持增量更新和差分包

## 安全特性

- HAP包签名验证
- HTTPS安全传输
- 包完整性校验
- 防篡改机制

## 开发指南

### 本地测试

```bash
# 启动本地服务器
python -m http.server 8000
# 或使用 Node.js
npx serve .
```

### 更新HAP包

1. 替换 `hap/AppSigned.hap` 文件
2. 更新 `manifest-jsdelivr.json5` 中的版本信息
3. 提交更改到GitHub
4. jsDelivr会自动同步更新（可能需要等待几分钟）

### 自定义域名

如果您有自己的域名，可以：

1. 配置CNAME记录指向GitHub Pages
2. 更新manifest中的 `deployDomain` 字段
3. 配置SSL证书（GitHub Pages自动提供）

## 故障排除

### 常见问题

**Q: jsDelivr访问慢怎么办？**
A: 可以使用备用CDN地址或自建CDN节点

**Q: HAP包无法安装？**
A: 检查包签名是否正确，确保设备支持该版本

**Q: 更新不生效？**
A: jsDelivr CDN可能需要时间同步，可以尝试刷新缓存

### 缓存刷新

如果更新后访问到的还是旧版本，可以访问：
```
https://purge.jsdelivr.net/gh/username/repo@main/hap/AppSigned.hap
```

## 许可证

MIT License

## 贡献

欢迎提交Issue和Pull Request！

---

## 联系方式

如有问题请通过Issue联系或查看[备用访问地址文档](alternative-hosts.md)。
