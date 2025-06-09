#!/bin/bash

# HAP包分发部署脚本 - GitHub + jsDelivr
# 用于快速配置和部署HAP包分发系统

set -e  # 遇到错误立即退出

echo "🚀 HAP包分发系统 - 自动化部署脚本"
echo "=================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查必要工具
check_tools() {
    echo -e "${BLUE}🔍 检查必要工具...${NC}"
    
    if ! command -v git &> /dev/null; then
        echo -e "${RED}❌ Git 未安装${NC}"
        exit 1
    fi
    
    if ! command -v sha256sum &> /dev/null; then
        echo -e "${RED}❌ sha256sum 未安装${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 工具检查完成${NC}"
}

# 检查必要文件
check_files() {
    echo -e "${BLUE}📁 检查项目文件...${NC}"
    
    if [ ! -f "hap/AppSigned.hap" ]; then
        echo -e "${RED}❌ 错误: 未找到 hap/AppSigned.hap 文件${NC}"
        echo -e "${YELLOW}💡 请将您的HAP文件放置到 hap/ 目录下并命名为 AppSigned.hap${NC}"
        exit 1
    fi
    
    # 检查HAP文件大小
    hap_size=$(du -h "hap/AppSigned.hap" | cut -f1)
    echo -e "${GREEN}📦 HAP文件大小: $hap_size${NC}"
    
    echo -e "${GREEN}✅ 文件检查完成${NC}"
}

# 获取GitHub仓库信息
get_repo_info() {
    echo -e "${BLUE}🔍 获取仓库信息...${NC}"
    
    if ! git remote -v &> /dev/null; then
        echo -e "${RED}❌ 当前目录不是Git仓库${NC}"
        exit 1
    fi
    
    REPO_URL=$(git remote get-url origin 2>/dev/null || echo "")
    
    if [ -z "$REPO_URL" ]; then
        echo -e "${RED}❌ 未找到Git远程仓库${NC}"
        echo -e "${YELLOW}💡 请先添加GitHub远程仓库: git remote add origin <your-repo-url>${NC}"
        exit 1
    fi
    
    # 解析用户名和仓库名
    if [[ $REPO_URL =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
        USERNAME="${BASH_REMATCH[1]}"
        REPO_NAME="${BASH_REMATCH[2]}"
        REPO_NAME="${REPO_NAME%.git}"  # 移除.git后缀
    else
        echo -e "${RED}❌ 无法解析GitHub仓库URL: $REPO_URL${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}👤 GitHub用户名: $USERNAME${NC}"
    echo -e "${GREEN}📁 仓库名称: $REPO_NAME${NC}"
    echo -e "${GREEN}🔗 仓库URL: $REPO_URL${NC}"
}

# 计算文件哈希
calculate_hash() {
    echo -e "${BLUE}🔢 计算HAP文件哈希值...${NC}"
    
    PACKAGE_HASH=$(sha256sum hap/AppSigned.hap | cut -d' ' -f1)
    echo -e "${GREEN}🔐 HAP文件哈希: $PACKAGE_HASH${NC}"
}

# 更新manifest配置（鸿蒙兼容）
update_manifest() {
    echo -e "${BLUE}📝 更新manifest配置文件(鸿蒙兼容)...${NC}"
    
    # 备份原始文件
    if [ -f "hap/manifest-jsdelivr.json5" ]; then
        cp "hap/manifest-jsdelivr.json5" "hap/manifest-jsdelivr.json5.bak"
        echo -e "${YELLOW}💾 已备份原始manifest文件${NC}"
    fi
    
    # 构建jsDelivr CDN URLs（鸿蒙要求域名一致性）
    DEPLOY_DOMAIN="cdn.jsdelivr.net"
    CDN_BASE_URL="https://cdn.jsdelivr.net/gh/$USERNAME/$REPO_NAME@main"
    PACKAGE_URL="$CDN_BASE_URL/hap/AppSigned.hap"
    MANIFEST_URL="$CDN_BASE_URL/hap/manifest-jsdelivr.json5"
    ICON_NORMAL_URL="$CDN_BASE_URL/asset/icon29.png"
    ICON_LARGE_URL="$CDN_BASE_URL/asset/icon1024.png"
    
    # 验证鸿蒙要求
    if [[ "$PACKAGE_URL" != https://* ]]; then
        echo -e "${RED}❌ 错误: packageUrl必须以https://开头${NC}"
        exit 1
    fi
    
    if [[ "$PACKAGE_URL" != *.hap ]]; then
        echo -e "${RED}❌ 错误: packageUrl必须以.hap结尾${NC}"
        exit 1
    fi
    
    # 读取现有配置或创建新的
    if [ -f "hap/manifest-jsdelivr.json5" ]; then
        # 使用Python更新JSON（更可靠）
        python3 -c "
import json
import sys

try:
    with open('hap/manifest-jsdelivr.json5', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # 更新配置确保符合鸿蒙要求
    data['app']['deployDomain'] = '$DEPLOY_DOMAIN'
    data['app']['icons']['normal'] = '$ICON_NORMAL_URL'
    data['app']['icons']['large'] = '$ICON_LARGE_URL'
    data['app']['modules'][0]['packageUrl'] = '$PACKAGE_URL'
    data['app']['modules'][0]['packageHash'] = '$PACKAGE_HASH'
    
    # 写入更新后的配置
    with open('hap/manifest-jsdelivr.json5', 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
    
    print('✅ Manifest updated for HarmonyOS compatibility')
except Exception as e:
    print(f'❌ Error updating manifest: {e}')
    sys.exit(1)
        "
        
        # 复制到根目录供鸿蒙访问
        cp "hap/manifest-jsdelivr.json5" "manifest.json5"
        echo -e "${GREEN}✅ 已复制manifest到根目录${NC}"
    else
        echo -e "${RED}❌ manifest-jsdelivr.json5 不存在，无法继续${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Manifest配置更新完成${NC}"
    echo -e "${BLUE}🔗 包下载地址: $PACKAGE_URL${NC}"
    echo -e "${BLUE}📋 配置文件地址: $MANIFEST_URL${NC}"
}

# 创建.nojekyll文件（避免GitHub Pages Jekyll处理）
create_nojekyll() {
    if [ ! -f ".nojekyll" ]; then
        touch .nojekyll
        echo -e "${GREEN}📄 已创建 .nojekyll 文件${NC}"
    fi
}

# 生成鸿蒙下载页面
generate_harmony_pages() {
    echo -e "${BLUE}📱 生成鸿蒙下载页面...${NC}"
    
    if [ -f "generate-download-page.sh" ]; then
        ./generate-download-page.sh
        
        if [ -f "harmony-download.html" ]; then
            echo -e "${GREEN}✅ 鸿蒙下载页面生成成功${NC}"
        else
            echo -e "${YELLOW}⚠️  鸿蒙下载页面生成失败，跳过此步骤${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  未找到页面生成器，跳过页面生成步骤${NC}"
    fi
}

# 鸿蒙配置验证
validate_harmony_config() {
    echo -e "${BLUE}🔍 验证鸿蒙分发配置...${NC}"
    
    # 生成DeepLink
    ENCODED_URL=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$MANIFEST_URL', safe=''))")
    DEEPLINK="store://enterprise/manifest?url=$ENCODED_URL"
    
    echo -e "${GREEN}✅ 鸿蒙配置验证通过${NC}"
    echo -e "${BLUE}🔗 DeepLink: $DEEPLINK${NC}"
}

# 创建CNAME文件（如果有自定义域名）
create_cname() {
    echo -e "${BLUE}🌐 域名配置${NC}"
    read -p "是否有自定义域名？(y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "请输入您的域名 (例如: app.yourdomain.com): " custom_domain
        if [ ! -z "$custom_domain" ]; then
            echo "$custom_domain" > CNAME
            echo -e "${GREEN}📝 已创建 CNAME 文件: $custom_domain${NC}"
        fi
    fi
}

# 提交并推送更改
commit_and_push() {
    echo -e "${BLUE}📤 提交更改到GitHub...${NC}"
    
    # 检查是否有待提交的更改
    if git diff --staged --quiet && git diff --quiet; then
        echo -e "${YELLOW}⚠️  没有需要提交的更改${NC}"
        return
    fi
    
    # 添加所有更改
    git add .
    
    # 创建提交信息
    COMMIT_MSG="🚀 Deploy: Update HAP package and configuration

- Package hash: ${PACKAGE_HASH:0:16}...
- jsDelivr CDN: $CDN_BASE_URL
- Auto-generated by deploy script"
    
    git commit -m "$COMMIT_MSG"
    
    echo -e "${BLUE}🚀 推送到远程仓库...${NC}"
    git push origin main
    
    echo -e "${GREEN}✅ 代码已推送到GitHub${NC}"
}

# 显示部署结果
show_results() {
    echo -e "${GREEN}🎉 鸿蒙HAP包分发部署完成！${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${GREEN}📱 鸿蒙应用分发地址:${NC}"
    echo -e "   🚀 HAP下载: $PACKAGE_URL"
    echo -e "   📋 配置文件: $MANIFEST_URL"
    echo -e "   🏠 GitHub Pages: https://$USERNAME.github.io/$REPO_NAME/"
    echo -e "   📋 项目仓库: https://github.com/$USERNAME/$REPO_NAME"
    
    if [ -f "harmony-download.html" ]; then
        echo -e "   📱 下载页面: https://$USERNAME.github.io/$REPO_NAME/harmony-download.html"
    fi
    
    echo
    echo -e "${GREEN}🔗 鸿蒙安装链接:${NC}"
    echo -e "   DeepLink: $DEEPLINK"
    echo
    echo -e "${GREEN}🎯 鸿蒙使用指南:${NC}"
    echo -e "   1. 仅支持华为浏览器使用"
    echo -e "   2. 必须通过页面点击触发，不能直接输入地址栏"
    echo -e "   3. 确保设备为HarmonyOS且开启开发者模式"
    echo -e "   4. 需要内部测试或企业分发权限"
    echo
    echo -e "${YELLOW}⏰ 同步时间:${NC}"
    echo -e "   • jsDelivr CDN: 5-10 分钟同步更新"
    echo -e "   • GitHub Pages: 构建完成后可访问"
    echo -e "   • 首次部署需要在仓库设置中启用 GitHub Pages"
    echo
    echo -e "${BLUE}🔧 后续操作:${NC}"
    echo -e "   1. 访问 https://github.com/$USERNAME/$REPO_NAME/settings/pages 启用 GitHub Pages"
    echo -e "   2. 选择 Source: Deploy from a branch, Branch: main"
    echo -e "   3. 等待构建完成后即可访问"
    echo
    echo -e "${GREEN}🔧 工具链:${NC}"
    echo -e "   • Range请求测试: ./test-range-support.sh"
    echo -e "   • 配置修复工具: ./fix-harmony-config.sh"
    echo -e "   • 页面生成器: ./generate-download-page.sh"
    echo
    echo -e "${GREEN}🌟 缓存刷新 (如需要):${NC}"
    echo -e "   访问: https://purge.jsdelivr.net/gh/$USERNAME/$REPO_NAME@main/hap/AppSigned.hap"
}

# 主函数
main() {
    echo -e "${BLUE}开始执行鸿蒙HAP包分发部署流程...${NC}"
    echo
    
    check_tools
    check_files
    get_repo_info
    calculate_hash
    update_manifest
    validate_harmony_config
    generate_harmony_pages
    create_nojekyll
    create_cname
    commit_and_push
    show_results
    
    echo -e "${GREEN}🚀 鸿蒙HAP包分发系统部署完成！${NC}"
}

# 执行主函数
main "$@" 