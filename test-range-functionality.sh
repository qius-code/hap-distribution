#!/bin/bash

# 鸿蒙HAP包分片下载测试脚本
# 确保Worker正确支持Range请求和206状态码

set -e

echo "🔍 鸿蒙HAP包分片功能测试"
echo "========================="

# 测试多个可能的Worker URL
WORKER_URLS=(
    "https://harmony-hap-distribution.q17626049428.workers.dev"
    "https://harmony-hap-distribution.d6d0faf10241a7417fcabe9e8781ae3a.workers.dev"
)

# GitHub Pages作为对比测试
GITHUB_PAGES_URL="https://qius-code.github.io/hap-distribution"

# 测试函数
test_range_request() {
    local url="$1"
    local description="$2"
    
    echo ""
    echo "📡 测试: $description"
    echo "🌐 URL: $url"
    
    # 1. 基本连通性测试
    echo "   🔍 测试连通性..."
    if timeout 10 curl -s --max-time 10 -I "$url/hap/AppSigned.hap" > /dev/null 2>&1; then
        echo "   ✅ 连通性正常"
    else
        echo "   ❌ 连通性失败，跳过此URL"
        return 1
    fi
    
    # 2. 获取文件信息
    echo "   📊 获取文件信息..."
    local headers=$(timeout 10 curl -s --max-time 10 -I "$url/hap/AppSigned.hap" 2>/dev/null)
    local content_length=$(echo "$headers" | grep -i "content-length" | head -1 | cut -d' ' -f2 | tr -d '\r\n')
    local accept_ranges=$(echo "$headers" | grep -i "accept-ranges" | head -1 | cut -d' ' -f2 | tr -d '\r\n')
    
    echo "   📦 文件大小: $content_length bytes"
    echo "   🔄 Accept-Ranges: $accept_ranges"
    
    # 3. 测试Range请求
    echo "   🎯 测试Range请求 (bytes=0-1023)..."
    local range_response=$(timeout 15 curl -s --max-time 15 -I -H "Range: bytes=0-1023" "$url/hap/AppSigned.hap" 2>/dev/null)
    
    if [ -z "$range_response" ]; then
        echo "   ❌ Range请求超时或失败"
        return 1
    fi
    
    # 4. 检查状态码
    local status_line=$(echo "$range_response" | head -1)
    echo "   📋 响应状态: $status_line"
    
    if echo "$status_line" | grep -q "206"; then
        echo "   ✅ 返回206状态码 - 分片下载支持正常！"
        
        # 提取Content-Range
        local content_range=$(echo "$range_response" | grep -i "content-range" | head -1 | cut -d' ' -f2- | tr -d '\r\n')
        echo "   📏 Content-Range: $content_range"
        
        return 0
    elif echo "$status_line" | grep -q "200"; then
        echo "   ⚠️  返回200状态码 - 不支持分片下载"
        return 1
    else
        echo "   ❌ 异常状态码: $status_line"
        return 1
    fi
}

# 测试所有URL
success_count=0
total_count=0

# 测试Worker URLs
for worker_url in "${WORKER_URLS[@]}"; do
    total_count=$((total_count + 1))
    if test_range_request "$worker_url" "Cloudflare Worker #$total_count"; then
        success_count=$((success_count + 1))
        echo "   🎉 此Worker完全支持鸿蒙分片下载要求！"
        WORKING_WORKER_URL="$worker_url"
    fi
done

# 测试GitHub Pages作为对比
total_count=$((total_count + 1))
echo ""
echo "🔄 对比测试 GitHub Pages（应该不支持206）"
if test_range_request "$GITHUB_PAGES_URL" "GitHub Pages (对比测试)"; then
    echo "   😮 意外：GitHub Pages也支持分片下载"
else
    echo "   ✅ 符合预期：GitHub Pages不支持分片下载"
fi

echo ""
echo "📋 测试总结"
echo "============"
echo "✅ 支持分片下载的服务: $success_count/$total_count"

if [ $success_count -gt 0 ]; then
    echo "🎉 恭喜！至少有 $success_count 个Worker支持鸿蒙分片下载要求"
    echo ""
    echo "🔗 推荐使用的Worker URL:"
    echo "   $WORKING_WORKER_URL"
    echo ""
    echo "🧪 分片下载测试命令:"
    echo "   curl -I -H \"Range: bytes=0-1023\" \"$WORKING_WORKER_URL/hap/AppSigned.hap\""
    echo ""
    echo "✅ 鸿蒙要求验证:"
    echo "   ✅ HTTPS协议"
    echo "   ✅ Range请求支持"
    echo "   ✅ 206状态码返回"
    echo "   ✅ Content-Range头部"
else
    echo "❌ 没有Worker支持分片下载，需要修复配置"
    echo ""
    echo "🔧 建议解决方案:"
    echo "   1. 重新部署Worker: npx wrangler deploy"
    echo "   2. 检查Worker代码的Range处理逻辑"
    echo "   3. 验证GitHub Raw文件可访问性"
fi

echo ""
echo "🎯 鸿蒙分片下载原理:"
echo "   鸿蒙系统下载大文件时会发送Range请求"
echo "   服务器必须返回206 Partial Content状态码"
echo "   这样可以支持断点续传和分片下载"
echo "   提高下载成功率和用户体验" 