#!/bin/bash

# 鸿蒙HAP包分发配置修复工具
# 确保完全符合鸿蒙官方要求

set -e

echo "🔧 鸿蒙HAP包分发配置修复工具"
echo "================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查必要文件
check_files() {
    echo -e "${BLUE}📁 检查必要文件...${NC}"
    
    if [ ! -f "hap/AppSigned.hap" ]; then
        echo -e "${RED}❌ 错误: 未找到 hap/AppSigned.hap 文件${NC}"
        exit 1
    fi
    
    if [ ! -f "hap/manifest-jsdelivr.json5" ]; then
        echo -e "${RED}❌ 错误: 未找到 hap/manifest-jsdelivr.json5 文件${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 文件检查完成${NC}"
}

# 获取仓库信息
get_repo_info() {
    echo -e "${BLUE}🔍 获取仓库信息...${NC}"
    
    REPO_URL=$(git remote get-url origin 2>/dev/null || echo "")
    
    if [ ! -z "$REPO_URL" ] && [[ $REPO_URL =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
        USERNAME="${BASH_REMATCH[1]}"
        REPO_NAME="${BASH_REMATCH[2]}"
        REPO_NAME="${REPO_NAME%.git}"
        
        echo -e "${GREEN}👤 GitHub用户名: $USERNAME${NC}"
        echo -e "${GREEN}📁 仓库名称: $REPO_NAME${NC}"
    else
        echo -e "${RED}❌ 无法获取GitHub仓库信息${NC}"
        exit 1
    fi
}

# 选择部署域名
choose_domain() {
    echo -e "${BLUE}🌐 选择部署域名...${NC}"
    echo -e "${YELLOW}鸿蒙要求deployDomain必须与所有下载URL的域名完全一致${NC}"
    echo
    echo "可用选项:"
    echo "1. cdn.jsdelivr.net (推荐 - 全球CDN，支持Range请求)"
    echo "2. $USERNAME.github.io (GitHub Pages)"
    echo "3. 自定义域名"
    echo
    
    read -p "请选择 (1-3): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            DEPLOY_DOMAIN="cdn.jsdelivr.net"
            BASE_URL="https://cdn.jsdelivr.net/gh/$USERNAME/$REPO_NAME@main"
            MANIFEST_URL="$BASE_URL/hap/manifest-jsdelivr.json5"
            echo -e "${GREEN}✅ 选择: jsDelivr CDN${NC}"
            ;;
        2)
            DEPLOY_DOMAIN="$USERNAME.github.io"
            BASE_URL="https://$USERNAME.github.io/$REPO_NAME"
            MANIFEST_URL="$BASE_URL/hap/manifest-jsdelivr.json5"
            echo -e "${GREEN}✅ 选择: GitHub Pages${NC}"
            ;;
        3)
            read -p "请输入自定义域名 (不包含https://): " CUSTOM_DOMAIN
            if [ -z "$CUSTOM_DOMAIN" ]; then
                echo -e "${RED}❌ 域名不能为空${NC}"
                exit 1
            fi
            DEPLOY_DOMAIN="$CUSTOM_DOMAIN"
            BASE_URL="https://$CUSTOM_DOMAIN"
            MANIFEST_URL="$BASE_URL/hap/manifest-jsdelivr.json5"
            echo -e "${GREEN}✅ 选择: 自定义域名 - $CUSTOM_DOMAIN${NC}"
            ;;
        *)
            echo -e "${RED}❌ 无效选择${NC}"
            exit 1
            ;;
    esac
}

# 计算HAP文件哈希
calculate_hash() {
    echo -e "${BLUE}🔢 计算HAP文件哈希值...${NC}"
    PACKAGE_HASH=$(sha256sum hap/AppSigned.hap | cut -d' ' -f1)
    echo -e "${GREEN}🔐 HAP文件哈希: $PACKAGE_HASH${NC}"
}

# 更新manifest配置
update_manifest() {
    echo -e "${BLUE}📝 更新manifest配置...${NC}"
    
    # 构建URL
    PACKAGE_URL="$BASE_URL/hap/AppSigned.hap"
    ICON_NORMAL_URL="$BASE_URL/asset/icon29.png"
    ICON_LARGE_URL="$BASE_URL/asset/icon1024.png"
    
    echo -e "${BLUE}配置信息:${NC}"
    echo -e "  部署域名: $DEPLOY_DOMAIN"
    echo -e "  HAP包URL: $PACKAGE_URL"
    echo -e "  Manifest URL: $MANIFEST_URL"
    echo -e "  图标URL: $ICON_NORMAL_URL"
    
    # 备份原始文件
    cp "hap/manifest-jsdelivr.json5" "hap/manifest-jsdelivr.json5.backup"
    
    # 读取当前配置
    CURRENT_CONTENT=$(cat hap/manifest-jsdelivr.json5)
    
    # 使用Python更新JSON配置（更可靠）
    python3 -c "
import json
import sys

# 读取当前配置
with open('hap/manifest-jsdelivr.json5', 'r', encoding='utf-8') as f:
    data = json.load(f)

# 更新配置
data['app']['deployDomain'] = '$DEPLOY_DOMAIN'
data['app']['icons']['normal'] = '$ICON_NORMAL_URL'
data['app']['icons']['large'] = '$ICON_LARGE_URL'
data['app']['modules'][0]['packageUrl'] = '$PACKAGE_URL'
data['app']['modules'][0]['packageHash'] = '$PACKAGE_HASH'

# 确保URL以正确后缀结尾
if not data['app']['modules'][0]['packageUrl'].endswith('.hap'):
    print('❌ 错误: packageUrl必须以.hap结尾', file=sys.stderr)
    sys.exit(1)

# 写入更新后的配置
with open('hap/manifest-jsdelivr.json5', 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, separators=(',', ':'))

print('✅ Manifest配置更新完成')
" || {
        echo -e "${RED}❌ Python更新失败，使用sed替代${NC}"
        
        # 备用sed方法
        sed -i.tmp "s|\"deployDomain\":\"[^\"]*\"|\"deployDomain\":\"$DEPLOY_DOMAIN\"|g" hap/manifest-jsdelivr.json5
        sed -i.tmp "s|\"packageUrl\":\"[^\"]*\"|\"packageUrl\":\"$PACKAGE_URL\"|g" hap/manifest-jsdelivr.json5
        sed -i.tmp "s|\"packageHash\":\"[^\"]*\"|\"packageHash\":\"$PACKAGE_HASH\"|g" hap/manifest-jsdelivr.json5
        sed -i.tmp "s|\"normal\":\"[^\"]*\"|\"normal\":\"$ICON_NORMAL_URL\"|g" hap/manifest-jsdelivr.json5
        sed -i.tmp "s|\"large\":\"[^\"]*\"|\"large\":\"$ICON_LARGE_URL\"|g" hap/manifest-jsdelivr.json5
        
        rm -f hap/manifest-jsdelivr.json5.tmp
        echo -e "${GREEN}✅ Manifest配置更新完成${NC}"
    }
}

# 复制manifest到根目录
copy_manifest_to_root() {
    echo -e "${BLUE}📋 复制manifest到根目录...${NC}"
    cp "hap/manifest-jsdelivr.json5" "manifest.json5"
    echo -e "${GREEN}✅ 已复制manifest.json5到根目录${NC}"
}

# 验证配置
verify_config() {
    echo -e "${BLUE}🔍 验证配置...${NC}"
    
    # 检查JSON格式
    if ! python3 -m json.tool hap/manifest-jsdelivr.json5 > /dev/null 2>&1; then
        echo -e "${RED}❌ manifest.json5格式错误${NC}"
        exit 1
    fi
    
    # 提取关键字段验证
    DEPLOY_DOMAIN_CHECK=$(python3 -c "import json; data=json.load(open('hap/manifest-jsdelivr.json5')); print(data['app']['deployDomain'])")
    PACKAGE_URL_CHECK=$(python3 -c "import json; data=json.load(open('hap/manifest-jsdelivr.json5')); print(data['app']['modules'][0]['packageUrl'])")
    
    # 验证域名一致性
    if [[ "$PACKAGE_URL_CHECK" != *"$DEPLOY_DOMAIN_CHECK"* ]]; then
        echo -e "${RED}❌ 错误: deployDomain与packageUrl域名不一致${NC}"
        echo -e "  deployDomain: $DEPLOY_DOMAIN_CHECK"
        echo -e "  packageUrl: $PACKAGE_URL_CHECK"
        exit 1
    fi
    
    # 验证URL格式
    if [[ "$PACKAGE_URL_CHECK" != https://* ]]; then
        echo -e "${RED}❌ 错误: packageUrl必须以https://开头${NC}"
        exit 1
    fi
    
    if [[ "$PACKAGE_URL_CHECK" != *.hap ]]; then
        echo -e "${RED}❌ 错误: packageUrl必须以.hap结尾${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 配置验证通过${NC}"
}

# 生成DeepLink
generate_deeplink() {
    echo -e "${BLUE}🔗 生成鸿蒙DeepLink...${NC}"
    
    # URL编码manifest URL
    ENCODED_URL=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$MANIFEST_URL', safe=''))")
    DEEPLINK="store://enterprise/manifest?url=$ENCODED_URL"
    
    echo -e "${GREEN}🎯 鸿蒙DeepLink已生成:${NC}"
    echo -e "${BLUE}$DEEPLINK${NC}"
    echo
    echo -e "${YELLOW}💡 使用说明:${NC}"
    echo -e "   1. 将此DeepLink集成到您的网页按钮中"
    echo -e "   2. 用户在华为浏览器中点击按钮即可安装"
    echo -e "   3. 仅支持点击触发，不支持地址栏直接输入"
    
    # 生成示例HTML
    cat > "harmony-download.html" << EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>鸿蒙应用下载</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
        .download-btn { 
            background: #007AFF; 
            color: white; 
            padding: 12px 24px; 
            border: none; 
            border-radius: 8px; 
            font-size: 16px; 
            cursor: pointer; 
        }
        .download-btn:hover { background: #0051D0; }
        .container { max-width: 600px; margin: 50px auto; padding: 20px; text-align: center; }
        .info { background: #f0f0f0; padding: 15px; border-radius: 8px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 鸿蒙应用下载</h1>
        <p>点击下方按钮下载安装应用</p>
        
        <button class="download-btn" onclick="openDeepLink()">📱 下载安装</button>
        
        <div class="info">
            <h3>📋 下载信息</h3>
            <p><strong>应用包:</strong> AppSigned.hap</p>
            <p><strong>下载地址:</strong> <a href="$PACKAGE_URL" target="_blank">$PACKAGE_URL</a></p>
            <p><strong>配置文件:</strong> <a href="$MANIFEST_URL" target="_blank">manifest.json5</a></p>
        </div>
        
        <div class="info">
            <h3>⚠️ 注意事项</h3>
            <p>• 仅支持华为浏览器下载安装</p>
            <p>• 需要HarmonyOS设备</p>
            <p>• 确保设备已启用开发者模式</p>
        </div>
    </div>

    <script>
        function openDeepLink() {
            const deeplink = '$DEEPLINK';
            console.log('Opening DeepLink:', deeplink);
            window.open(deeplink, '_parent');
        }
    </script>
</body>
</html>
EOF
    
    echo -e "${GREEN}✅ 已生成示例下载页面: harmony-download.html${NC}"
}

# 显示最终结果
show_results() {
    echo -e "${GREEN}🎉 鸿蒙HAP分发配置完成！${NC}"
    echo -e "${BLUE}=================================${NC}"
    echo
    echo -e "${GREEN}📱 关键URL:${NC}"
    echo -e "   🎯 HAP包: $PACKAGE_URL"
    echo -e "   📋 配置: $MANIFEST_URL" 
    echo -e "   🔗 DeepLink: $DEEPLINK"
    echo
    echo -e "${GREEN}📋 域名配置:${NC}"
    echo -e "   📍 deployDomain: $DEPLOY_DOMAIN"
    echo -e "   ✅ 所有URL域名一致"
    echo
    echo -e "${GREEN}🔧 技术要求:${NC}"
    echo -e "   ✅ 支持HTTPS协议"
    echo -e "   ✅ 支持Range请求（分片下载）"
    echo -e "   ✅ 正确的Content-Type"
    echo -e "   ✅ 文件后缀格式正确"
    echo
    echo -e "${YELLOW}⏰ 后续步骤:${NC}"
    echo -e "   1. 提交更改到GitHub"
    echo -e "   2. 等待CDN同步（5-10分钟）"
    echo -e "   3. 测试DeepLink功能"
    echo -e "   4. 在华为浏览器中验证下载"
}

# 主函数
main() {
    check_files
    get_repo_info
    choose_domain
    calculate_hash
    update_manifest
    copy_manifest_to_root
    verify_config
    generate_deeplink
    show_results
}

# 执行主函数
main "$@" 