# 🚀 鸿蒙HAP包分发 - Vercel部署指南

## ✅ 方案概述

本项目利用 **Vercel** 平台及其 **Serverless Function** 功能，为鸿蒙(HarmonyOS)应用提供稳定、可靠、支持分片下载的分发服务。

**核心优势**:
- **网络稳定**: 解决之前Cloudflare遇到的网络连接问题。
- **真·分片下载**: 通过无服务器函数代理GitHub Raw文件，正确处理`Range`请求，返回`206 Partial Content`状态码。
- **完全免费**: Vercel的免费套餐足以应对绝大多数分发场景。
- **自动化部署**: 与GitHub仓库深度集成，实现CI/CD。

## 🛠️ 前置准备

1.  **Vercel账号**: [注册一个Vercel账号](https://vercel.com/signup)，并使用您的GitHub账号进行关联。
2.  **Node.js**: 确保您的本地环境已安装Node.js (v18或更高版本)。
3.  **Vercel CLI**: 在本地安装Vercel命令行工具。
    ```bash
    npm install -g vercel
    ```

## 🚀 部署流程

### 1. 登录Vercel CLI
在您的终端中，登录到Vercel。
```bash
vercel login
```

### 2. 关联项目
首次部署时，Vercel会引导您将本地项目关联到Vercel上的一个新项目。
```bash
# 进入项目目录
cd /path/to/your/hap-distribution

# 运行部署命令
vercel
```
按照提示操作：
- `Set up and deploy ...?` -> **Y**
- `Which scope ...?` -> 选择您的Vercel账户。
- `Link to an existing project?` -> **N** (我们是新项目)
- `What's your project's name?` -> 默认为仓库名 `hap-distribution`，回车即可。
- `In which directory is your code located?` -> 默认为 `./`，回车即可。
- Vercel会自动检测到项目配置，不需要修改，一路确认即可。

### 3. 正式部署到生产环境
关联完成后，您就可以一键部署到生产环境了。
```bash
# 此命令会将您的项目部署到带`.vercel.app`后缀的生产域名
vercel --prod
```
部署成功后，Vercel会提供给您一个生产环境的URL，例如 `https://hap-distribution-xxxxxxxx.vercel.app`。**这个就是我们最终要使用的域名**。

## 📁 项目文件结构解析

```
hap-distribution/
├── api/
│   └── handler.js             # Vercel无服务器函数，处理分片下载的核心逻辑
├── hap/
│   ├── AppSigned.hap          # 您的鸿蒙应用包
│   └── manifest-jsdelivr.json5 # 应用配置文件
├── asset/
│   └── (图标等资源)
├── vercel.json                # Vercel配置文件，定义路由规则
├── package.json               # Node.js项目文件，包含依赖
└── ... (其他文件)
```

## ⚙️ 核心配置文件解读

### `vercel.json`
```json
{
  "rewrites": [
    { "source": "/(.*)", "destination": "/api/handler" }
  ]
}
```
这个配置非常关键，它的作用是将所有进入Vercel应用的请求（例如 `/hap/AppSigned.hap`），全部转发给位于 `/api/handler.js` 的无服务器函数来处理。

### `api/handler.js`
这是我们方案的"大脑"。它接收所有请求，然后：
1.  解析请求的路径和`Range`头。
2.  向GitHub Raw的对应文件地址发起一个带有同样`Range`头的请求。
3.  GitHub Raw原生支持`Range`请求并会返回`206`状态码。
4.  我们的函数聪明地将GitHub Raw的响应（包括状态码206和`Content-Range`头）直接"流式"传输给客户端（鸿蒙系统）。
5.  这样就以极低的开销和极高的效率，完美实现了分片下载。

## 🧪 测试与验证

部署成功后，您需要用新的Vercel域名进行测试。

假设您的域名是 `https://your-app.vercel.app`

### 1. 测试连通性
```bash
curl "https://your-app.vercel.app/hap/AppSigned.hap" -I
```
应该返回 `HTTP/2 200` 或 `HTTP/2 206`。

### 2. **关键测试：分片下载**
```bash
curl -I -H "Range: bytes=0-1023" "https://your-app.vercel.app/hap/AppSigned.hap"
```
**必须返回 `HTTP/2 206 Partial Content` 状态码。** 如果成功，代表我们的方案完美达成目标！

## 📱 更新鸿蒙应用配置

一旦您获得了稳定的Vercel生产域名，就需要更新 `hap/manifest-jsdelivr.json5` 和下载页面中的所有URL。

1.  **更新 `manifest-jsdelivr.json5`**:
    - `deployDomain`
    - `packageUrl`
    - `icons`中的URL
    全部替换为您的Vercel域名。

2.  **更新下载页面**:
    - 重新运行 `./generate-download-page.sh` 脚本，它会自动使用新的配置生成页面。

3.  **重新部署**:
    - 提交您的代码更改到GitHub。
    - Vercel会自动检测到新的提交，并自动为您部署最新版本。或者您可以手动运行 `vercel --prod`。

---
**现在，我们拥有了一个非常稳定、可靠且功能完善的鸿蒙应用分发方案。** 🎉 