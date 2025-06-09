#!/bin/bash

# 鸿蒙应用下载页面生成器
# 从manifest.json5读取配置并生成下载页面

set -e

echo "📄 鸿蒙应用下载页面生成器"
echo "========================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查依赖
check_dependencies() {
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}❌ 需要Python3${NC}"
        exit 1
    fi
    
    if [ ! -f "harmony-download-template.html" ]; then
        echo -e "${RED}❌ 未找到模板文件: harmony-download-template.html${NC}"
        exit 1
    fi
    
    if [ ! -f "hap/manifest-jsdelivr.json5" ]; then
        echo -e "${RED}❌ 未找到配置文件: hap/manifest-jsdelivr.json5${NC}"
        exit 1
    fi
}

# 从manifest提取配置
extract_config() {
    echo -e "${BLUE}📋 读取应用配置...${NC}"
    
    # 使用Python解析JSON配置
    CONFIG_JSON=$(python3 -c "
import json
import sys

try:
    with open('hap/manifest-jsdelivr.json5', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    app = data['app']
    module = app['modules'][0]
    
    config = {
        'name': app.get('label', '鸿蒙应用'),
        'version': app.get('versionName', '1.0.0'),
        'bundleName': app.get('bundleName', ''),
        'packageUrl': module.get('packageUrl', ''),
        'packageHash': module.get('packageHash', ''),
        'minAPIVersion': app.get('minAPIVersion', ''),
        'deployDomain': app.get('deployDomain', ''),
        'iconNormal': app.get('icons', {}).get('normal', ''),
        'iconLarge': app.get('icons', {}).get('large', '')
    }
    
    print(json.dumps(config, ensure_ascii=False))

except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
")
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ 配置文件解析失败${NC}"
        exit 1
    fi
    
    # 提取各个配置项
    APP_NAME=$(echo "$CONFIG_JSON" | python3 -c "import json, sys; print(json.load(sys.stdin)['name'])")
    APP_VERSION=$(echo "$CONFIG_JSON" | python3 -c "import json, sys; print(json.load(sys.stdin)['version'])")
    BUNDLE_NAME=$(echo "$CONFIG_JSON" | python3 -c "import json, sys; print(json.load(sys.stdin)['bundleName'])")
    PACKAGE_URL=$(echo "$CONFIG_JSON" | python3 -c "import json, sys; print(json.load(sys.stdin)['packageUrl'])")
    PACKAGE_HASH=$(echo "$CONFIG_JSON" | python3 -c "import json, sys; print(json.load(sys.stdin)['packageHash'])")
    MIN_API_VERSION=$(echo "$CONFIG_JSON" | python3 -c "import json, sys; print(json.load(sys.stdin)['minAPIVersion'])")
    DEPLOY_DOMAIN=$(echo "$CONFIG_JSON" | python3 -c "import json, sys; print(json.load(sys.stdin)['deployDomain'])")
    
    # 生成manifest URL
    MANIFEST_URL="${PACKAGE_URL%/hap/AppSigned.hap}/hap/manifest-jsdelivr.json5"
    
    # 生成DeepLink
    ENCODED_URL=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$MANIFEST_URL', safe=''))")
    DEEPLINK="store://enterprise/manifest?url=$ENCODED_URL"
    
    echo -e "${GREEN}✅ 配置读取完成${NC}"
    echo -e "   应用名称: $APP_NAME"
    echo -e "   版本: $APP_VERSION"
    echo -e "   包名: $BUNDLE_NAME"
    echo -e "   部署域名: $DEPLOY_DOMAIN"
}

# 生成下载页面
generate_page() {
    echo -e "${BLUE}🔧 生成下载页面...${NC}"
    
    # 复制模板
    cp "harmony-download-template.html" "harmony-download.html"
    
    # 替换占位符
    sed -i.tmp "s/APP_NAME_PLACEHOLDER/$APP_NAME/g" harmony-download.html
    sed -i.tmp "s/APP_VERSION_PLACEHOLDER/$APP_VERSION/g" harmony-download.html
    sed -i.tmp "s/BUNDLE_NAME_PLACEHOLDER/$BUNDLE_NAME/g" harmony-download.html
    sed -i.tmp "s|PACKAGE_URL_PLACEHOLDER|$PACKAGE_URL|g" harmony-download.html
    sed -i.tmp "s|MANIFEST_URL_PLACEHOLDER|$MANIFEST_URL|g" harmony-download.html
    sed -i.tmp "s/PACKAGE_HASH_PLACEHOLDER/$PACKAGE_HASH/g" harmony-download.html
    sed -i.tmp "s/MIN_API_VERSION_PLACEHOLDER/$MIN_API_VERSION/g" harmony-download.html
    sed -i.tmp "s|DEEPLINK_PLACEHOLDER|$DEEPLINK|g" harmony-download.html
    
    # 清理临时文件
    rm -f harmony-download.html.tmp
    
    echo -e "${GREEN}✅ 下载页面生成完成: harmony-download.html${NC}"
}

# 生成简化版本（用于集成到现有页面）
generate_widget() {
    echo -e "${BLUE}🔧 生成下载组件...${NC}"
    
    cat > "harmony-download-widget.html" << EOF
<!-- 鸿蒙应用下载组件 -->
<div class="harmony-download-widget" style="
    max-width: 400px;
    margin: 20px auto;
    padding: 30px;
    background: linear-gradient(135deg, #FF6B6B, #4ECDC4);
    border-radius: 20px;
    color: white;
    text-align: center;
    box-shadow: 0 10px 30px rgba(0,0,0,0.2);
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
">
    <div style="font-size: 48px; margin-bottom: 15px;">📱</div>
    <h3 style="margin: 0 0 10px; font-size: 24px; font-weight: 700;">$APP_NAME</h3>
    <p style="margin: 0 0 20px; opacity: 0.9; font-size: 14px;">版本 $APP_VERSION</p>
    
    <button onclick="downloadHarmonyApp()" style="
        background: rgba(255,255,255,0.2);
        color: white;
        border: 2px solid rgba(255,255,255,0.3);
        padding: 12px 24px;
        border-radius: 25px;
        font-size: 16px;
        font-weight: 600;
        cursor: pointer;
        transition: all 0.3s ease;
        backdrop-filter: blur(10px);
    " onmouseover="this.style.background='rgba(255,255,255,0.3)'" 
       onmouseout="this.style.background='rgba(255,255,255,0.2)'">
        📥 立即下载安装
    </button>
    
    <p style="margin: 15px 0 0; font-size: 12px; opacity: 0.8;">
        仅支持华为浏览器 · HarmonyOS设备
    </p>
</div>

<script>
function downloadHarmonyApp() {
    const deeplink = '$DEEPLINK';
    console.log('启动鸿蒙应用下载:', deeplink);
    
    try {
        window.open(deeplink, '_parent');
        
        // 显示提示（可选）
        const btn = event.target;
        const originalText = btn.textContent;
        btn.textContent = '🔄 启动中...';
        btn.disabled = true;
        
        setTimeout(() => {
            btn.textContent = originalText;
            btn.disabled = false;
        }, 3000);
        
    } catch (error) {
        console.error('DeepLink启动失败:', error);
        alert('启动下载失败，请确保使用华为浏览器');
    }
}
</script>
EOF
    
    echo -e "${GREEN}✅ 下载组件生成完成: harmony-download-widget.html${NC}"
}

# 验证生成的页面
validate_page() {
    echo -e "${BLUE}🔍 验证生成的页面...${NC}"
    
    # 检查文件是否存在
    if [ ! -f "harmony-download.html" ]; then
        echo -e "${RED}❌ 页面文件未生成${NC}"
        exit 1
    fi
    
    # 检查是否还有未替换的占位符
    PLACEHOLDERS=$(grep -o "PLACEHOLDER" harmony-download.html | wc -l || echo "0")
    
    if [ "$PLACEHOLDERS" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  发现 $PLACEHOLDERS 个未替换的占位符${NC}"
        grep "PLACEHOLDER" harmony-download.html || true
    else
        echo -e "${GREEN}✅ 所有占位符已正确替换${NC}"
    fi
    
    # 检查文件大小
    FILE_SIZE=$(wc -c < harmony-download.html)
    if [ "$FILE_SIZE" -lt 1000 ]; then
        echo -e "${RED}❌ 页面文件太小，可能生成失败${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 页面验证通过 (大小: ${FILE_SIZE} bytes)${NC}"
}

# 显示使用说明
show_usage() {
    echo -e "${GREEN}🎉 页面生成完成！${NC}"
    echo -e "${BLUE}=========================${NC}"
    echo
    echo -e "${GREEN}📄 生成的文件:${NC}"
    echo -e "   📱 完整下载页面: harmony-download.html"
    echo -e "   🔧 下载组件: harmony-download-widget.html"
    echo
    echo -e "${GREEN}🔗 关键信息:${NC}"
    echo -e "   🎯 应用名称: $APP_NAME"
    echo -e "   📋 包名: $BUNDLE_NAME"
    echo -e "   🌐 下载地址: $PACKAGE_URL"
    echo -e "   🔗 DeepLink: $DEEPLINK"
    echo
    echo -e "${GREEN}📱 使用方式:${NC}"
    echo -e "   1. 将 harmony-download.html 部署到您的网站"
    echo -e "   2. 或将 harmony-download-widget.html 集成到现有页面"
    echo -e "   3. 用户在华为浏览器中访问并点击下载按钮"
    echo
    echo -e "${YELLOW}⚠️  重要提醒:${NC}"
    echo -e "   • 仅在华为浏览器中有效"
    echo -e "   • 需要用户点击触发，不能自动启动"
    echo -e "   • 确保HAP包已正确签名"
}

# 主函数
main() {
    check_dependencies
    extract_config
    generate_page
    generate_widget
    validate_page
    show_usage
}

# 执行主函数
main "$@" 