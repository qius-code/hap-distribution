#!/bin/bash

# 测试CDN Range请求支持
# 鸿蒙要求服务器必须支持分片下载（HTTP Range请求）

set -e

echo "🔍 测试CDN Range请求支持"
echo "========================"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 获取仓库信息
get_repo_info() {
    REPO_URL=$(git remote get-url origin 2>/dev/null || echo "")
    
    if [ ! -z "$REPO_URL" ] && [[ $REPO_URL =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
        USERNAME="${BASH_REMATCH[1]}"
        REPO_NAME="${BASH_REMATCH[2]}"
        REPO_NAME="${REPO_NAME%.git}"
        
        echo -e "${GREEN}👤 GitHub用户: $USERNAME${NC}"
        echo -e "${GREEN}📁 仓库: $REPO_NAME${NC}"
    else
        echo -e "${RED}❌ 无法获取GitHub仓库信息${NC}"
        exit 1
    fi
}

# 测试Range请求支持
test_range_support() {
    local url="$1"
    local name="$2"
    
    echo -e "${BLUE}🔍 测试 $name...${NC}"
    echo -e "   URL: $url"
    
    # 测试HEAD请求检查Accept-Ranges
    echo -e "${BLUE}   检查Accept-Ranges头...${NC}"
    ACCEPT_RANGES=$(curl -s -I "$url" | grep -i "accept-ranges" | cut -d' ' -f2- | tr -d '\r\n' || echo "")
    
    if [[ "$ACCEPT_RANGES" == *"bytes"* ]]; then
        echo -e "${GREEN}   ✅ Accept-Ranges: $ACCEPT_RANGES${NC}"
    else
        echo -e "${YELLOW}   ⚠️  Accept-Ranges: $ACCEPT_RANGES (未明确支持)${NC}"
    fi
    
    # 测试实际Range请求
    echo -e "${BLUE}   测试Range请求...${NC}"
    RANGE_RESPONSE=$(curl -s -I -H "Range: bytes=0-1023" "$url" | head -1 | tr -d '\r\n' || echo "")
    
    if [[ "$RANGE_RESPONSE" == *"206"* ]]; then
        echo -e "${GREEN}   ✅ Range请求返回: $RANGE_RESPONSE${NC}"
        RANGE_SUPPORT=true
    else
        echo -e "${RED}   ❌ Range请求返回: $RANGE_RESPONSE${NC}"
        RANGE_SUPPORT=false
    fi
    
    # 检查Content-Range头
    CONTENT_RANGE=$(curl -s -I -H "Range: bytes=0-1023" "$url" | grep -i "content-range" | cut -d' ' -f2- | tr -d '\r\n' || echo "")
    if [ ! -z "$CONTENT_RANGE" ]; then
        echo -e "${GREEN}   ✅ Content-Range: $CONTENT_RANGE${NC}"
    else
        echo -e "${YELLOW}   ⚠️  未返回Content-Range头${NC}"
    fi
    
    # 检查Content-Length
    CONTENT_LENGTH=$(curl -s -I "$url" | grep -i "content-length" | cut -d' ' -f2- | tr -d '\r\n' || echo "")
    if [ ! -z "$CONTENT_LENGTH" ]; then
        echo -e "${GREEN}   ✅ Content-Length: $CONTENT_LENGTH bytes${NC}"
    else
        echo -e "${YELLOW}   ⚠️  未返回Content-Length头${NC}"
    fi
    
    echo
    
    return $RANGE_SUPPORT
}

# 测试URL可达性
test_url_accessibility() {
    local url="$1"
    local name="$2"
    
    echo -e "${BLUE}🌐 测试 $name 可达性...${NC}"
    
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$url" || echo "000")
    
    if [ "$HTTP_STATUS" = "200" ]; then
        echo -e "${GREEN}✅ $name 可访问 (HTTP $HTTP_STATUS)${NC}"
        return 0
    else
        echo -e "${RED}❌ $name 不可访问 (HTTP $HTTP_STATUS)${NC}"
        return 1
    fi
}

# 主测试函数
main() {
    get_repo_info
    
    # 构建测试URL
    JSDELIVR_HAP_URL="https://cdn.jsdelivr.net/gh/$USERNAME/$REPO_NAME@main/hap/AppSigned.hap"
    JSDELIVR_MANIFEST_URL="https://cdn.jsdelivr.net/gh/$USERNAME/$REPO_NAME@main/hap/manifest-jsdelivr.json5"
    GITHUB_PAGES_HAP_URL="https://$USERNAME.github.io/$REPO_NAME/hap/AppSigned.hap"
    GITHUB_PAGES_MANIFEST_URL="https://$USERNAME.github.io/$REPO_NAME/hap/manifest-jsdelivr.json5"
    
    echo -e "${BLUE}🔍 开始测试各个CDN的Range请求支持...${NC}"
    echo
    
    # 测试jsDelivr
    echo -e "${BLUE}================== jsDelivr CDN ==================${NC}"
    test_url_accessibility "$JSDELIVR_HAP_URL" "jsDelivr HAP包"
    if [ $? -eq 0 ]; then
        test_range_support "$JSDELIVR_HAP_URL" "jsDelivr HAP包"
        JSDELIVR_HAP_RANGE=$?
    else
        JSDELIVR_HAP_RANGE=1
    fi
    
    test_url_accessibility "$JSDELIVR_MANIFEST_URL" "jsDelivr Manifest"
    if [ $? -eq 0 ]; then
        test_range_support "$JSDELIVR_MANIFEST_URL" "jsDelivr Manifest"
        JSDELIVR_MANIFEST_RANGE=$?
    else
        JSDELIVR_MANIFEST_RANGE=1
    fi
    
    # 测试GitHub Pages
    echo -e "${BLUE}================== GitHub Pages ==================${NC}"
    test_url_accessibility "$GITHUB_PAGES_HAP_URL" "GitHub Pages HAP包"
    if [ $? -eq 0 ]; then
        test_range_support "$GITHUB_PAGES_HAP_URL" "GitHub Pages HAP包"
        GITHUB_HAP_RANGE=$?
    else
        GITHUB_HAP_RANGE=1
    fi
    
    test_url_accessibility "$GITHUB_PAGES_MANIFEST_URL" "GitHub Pages Manifest"
    if [ $? -eq 0 ]; then
        test_range_support "$GITHUB_PAGES_MANIFEST_URL" "GitHub Pages Manifest"
        GITHUB_MANIFEST_RANGE=$?
    else
        GITHUB_MANIFEST_RANGE=1
    fi
    
    # 生成测试报告
    echo -e "${BLUE}=================== 测试报告 ===================${NC}"
    echo
    echo -e "${GREEN}📊 Range请求支持测试结果:${NC}"
    
    if [ $JSDELIVR_HAP_RANGE -eq 0 ]; then
        echo -e "   ✅ jsDelivr HAP包: 支持Range请求"
    else
        echo -e "   ❌ jsDelivr HAP包: 不支持Range请求"
    fi
    
    if [ $JSDELIVR_MANIFEST_RANGE -eq 0 ]; then
        echo -e "   ✅ jsDelivr Manifest: 支持Range请求"
    else
        echo -e "   ❌ jsDelivr Manifest: 不支持Range请求"
    fi
    
    if [ $GITHUB_HAP_RANGE -eq 0 ]; then
        echo -e "   ✅ GitHub Pages HAP包: 支持Range请求"
    else
        echo -e "   ❌ GitHub Pages HAP包: 不支持Range请求"
    fi
    
    if [ $GITHUB_MANIFEST_RANGE -eq 0 ]; then
        echo -e "   ✅ GitHub Pages Manifest: 支持Range请求"
    else
        echo -e "   ❌ GitHub Pages Manifest: 不支持Range请求"
    fi
    
    echo
    echo -e "${GREEN}💡 鸿蒙分发建议:${NC}"
    
    if [ $JSDELIVR_HAP_RANGE -eq 0 ] && [ $JSDELIVR_MANIFEST_RANGE -eq 0 ]; then
        echo -e "   🎯 推荐使用 jsDelivr CDN (cdn.jsdelivr.net)"
        echo -e "   ✅ 完全符合鸿蒙分发要求"
        echo -e "   📋 deployDomain 设置为: cdn.jsdelivr.net"
    elif [ $GITHUB_HAP_RANGE -eq 0 ] && [ $GITHUB_MANIFEST_RANGE -eq 0 ]; then
        echo -e "   🏠 可以使用 GitHub Pages ($USERNAME.github.io)"
        echo -e "   ✅ 符合鸿蒙分发要求"
        echo -e "   📋 deployDomain 设置为: $USERNAME.github.io"
    else
        echo -e "   ⚠️  检测到Range请求支持问题"
        echo -e "   💡 建议检查服务器配置或使用其他CDN"
    fi
    
    # 生成详细的curl命令用于手动测试
    echo
    echo -e "${BLUE}🛠️  手动测试命令:${NC}"
    echo -e "# 测试jsDelivr Range请求"
    echo -e "curl -I -H \"Range: bytes=0-1023\" \"$JSDELIVR_HAP_URL\""
    echo
    echo -e "# 测试GitHub Pages Range请求"
    echo -e "curl -I -H \"Range: bytes=0-1023\" \"$GITHUB_PAGES_HAP_URL\""
    
    echo -e "${GREEN}🚀 测试完成！${NC}"
}

# 执行测试
main "$@" 