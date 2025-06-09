#!/bin/bash

# Worker测试脚本
set -e

echo "🔍 测试Cloudflare Worker状态"
echo "============================"

# 获取Worker URL
WORKER_URL="https://harmony-hap-distribution.q17626049428.workers.dev"

echo "🌐 Worker URL: $WORKER_URL"
echo ""

# 测试1: 基本连通性
echo "📡 测试1: 基本连通性"
if curl -s --max-time 10 -I "$WORKER_URL/" | head -1; then
    echo "✅ Worker可访问"
else
    echo "❌ Worker无法访问"
    echo "💡 可能的原因："
    echo "   1. Worker仍在部署中（等待几分钟）"
    echo "   2. 网络连接问题"
    echo "   3. Worker URL不正确"
    echo ""
    echo "🔧 解决方案："
    echo "   npx wrangler deploy  # 重新部署"
    echo "   npx wrangler tail    # 查看日志"
    exit 1
fi

echo ""

# 测试2: HAP文件访问
echo "📦 测试2: HAP文件访问"
if curl -s --max-time 10 -I "$WORKER_URL/hap/AppSigned.hap" | head -1; then
    echo "✅ HAP文件可访问"
else
    echo "❌ HAP文件无法访问"
fi

echo ""

# 测试3: Range请求支持
echo "🔍 测试3: Range请求支持"
RANGE_RESPONSE=$(curl -s --max-time 10 -I -H "Range: bytes=0-1023" "$WORKER_URL/hap/AppSigned.hap" | head -1)
echo "Range响应: $RANGE_RESPONSE"

if echo "$RANGE_RESPONSE" | grep -q "206"; then
    echo "✅ Range请求支持正常 - 返回206状态码"
else
    echo "⚠️  Range请求未返回206状态码"
fi

echo ""

# 测试4: manifest文件
echo "📋 测试4: Manifest文件"
if curl -s --max-time 10 "$WORKER_URL/hap/manifest-jsdelivr.json5" | head -c 50; then
    echo ""
    echo "✅ Manifest文件可访问"
else
    echo "❌ Manifest文件无法访问"
fi

echo ""
echo "🎉 测试完成！" 