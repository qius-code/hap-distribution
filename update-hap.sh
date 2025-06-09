#!/bin/bash

# HAP包快速更新工具
# 用于快速替换HAP文件并更新配置

set -e

echo "📱 HAP包快速更新工具"
echo "====================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查参数
if [ $# -eq 0 ]; then
    echo -e "${YELLOW}用法: $0 <HAP文件路径> [版本号]${NC}"
    echo -e "${BLUE}示例: $0 /path/to/new/AppSigned.hap 1.0.32${NC}"
    exit 1
fi

HAP_FILE_PATH="$1"
NEW_VERSION="$2"

# 检查输入文件是否存在
if [ ! -f "$HAP_FILE_PATH" ]; then
    echo -e "${RED}❌ 错误: 文件不存在 - $HAP_FILE_PATH${NC}"
    exit 1
fi

# 检查文件是否为HAP格式
if [[ ! "$HAP_FILE_PATH" =~ \.hap$ ]]; then
    echo -e "${YELLOW}⚠️  警告: 文件似乎不是.hap格式${NC}"
    read -p "是否继续？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "操作已取消"
        exit 1
    fi
fi

echo -e "${BLUE}🔍 检查新HAP文件...${NC}"
NEW_HAP_SIZE=$(du -h "$HAP_FILE_PATH" | cut -f1)
NEW_HAP_HASH=$(sha256sum "$HAP_FILE_PATH" | cut -d' ' -f1)

echo -e "${GREEN}📦 新HAP文件大小: $NEW_HAP_SIZE${NC}"
echo -e "${GREEN}🔐 新HAP文件哈希: $NEW_HAP_HASH${NC}"

# 备份旧文件
if [ -f "hap/AppSigned.hap" ]; then
    OLD_HAP_SIZE=$(du -h "hap/AppSigned.hap" | cut -f1)
    OLD_HAP_HASH=$(sha256sum "hap/AppSigned.hap" | cut -d' ' -f1)
    
    echo -e "${BLUE}📋 当前HAP文件信息:${NC}"
    echo -e "   大小: $OLD_HAP_SIZE"
    echo -e "   哈希: $OLD_HAP_HASH"
    
    # 检查是否为相同文件
    if [ "$NEW_HAP_HASH" = "$OLD_HAP_HASH" ]; then
        echo -e "${YELLOW}⚠️  新文件与当前文件相同，无需更新${NC}"
        exit 0
    fi
    
    # 备份旧文件
    BACKUP_NAME="hap/AppSigned.hap.backup.$(date +%Y%m%d_%H%M%S)"
    cp "hap/AppSigned.hap" "$BACKUP_NAME"
    echo -e "${GREEN}💾 已备份旧文件到: $BACKUP_NAME${NC}"
fi

# 复制新文件
echo -e "${BLUE}📁 复制新HAP文件...${NC}"
cp "$HAP_FILE_PATH" "hap/AppSigned.hap"

# 获取仓库信息
REPO_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [ ! -z "$REPO_URL" ] && [[ $REPO_URL =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
    USERNAME="${BASH_REMATCH[1]}"
    REPO_NAME="${BASH_REMATCH[2]}"
    REPO_NAME="${REPO_NAME%.git}"
    
    echo -e "${GREEN}👤 GitHub用户: $USERNAME${NC}"
    echo -e "${GREEN}📁 仓库名称: $REPO_NAME${NC}"
    
    # 更新manifest配置
    echo -e "${BLUE}📝 更新manifest配置...${NC}"
    
    CDN_BASE_URL="https://cdn.jsdelivr.net/gh/$USERNAME/$REPO_NAME@main"
    PACKAGE_URL="$CDN_BASE_URL/hap/AppSigned.hap"
    
    # 更新所有manifest文件
    for manifest_file in hap/manifest*.json5; do
        if [ -f "$manifest_file" ]; then
            echo -e "${BLUE}   更新 $manifest_file${NC}"
            
            # 备份
            cp "$manifest_file" "$manifest_file.bak"
            
            # 更新哈希值
            sed -i.tmp "s|\"packageHash\":\"[^\"]*\"|\"packageHash\":\"$NEW_HAP_HASH\"|g" "$manifest_file"
            
            # 更新版本号（如果提供了）
            if [ ! -z "$NEW_VERSION" ]; then
                # 提取版本号中的数字部分
                if [[ $NEW_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    # 计算版本代码 (例如: 1.0.32 -> 1000032)
                    IFS='.' read -ra VERSION_PARTS <<< "$NEW_VERSION"
                    VERSION_CODE=$((${VERSION_PARTS[0]} * 1000000 + ${VERSION_PARTS[1]} * 1000 + ${VERSION_PARTS[2]}))
                    
                    sed -i.tmp "s|\"versionName\":\"[^\"]*\"|\"versionName\":\"$NEW_VERSION\"|g" "$manifest_file"
                    sed -i.tmp "s|\"versionCode\":[0-9]*|\"versionCode\":$VERSION_CODE|g" "$manifest_file"
                    
                    echo -e "${GREEN}   ✅ 已更新版本: $NEW_VERSION (code: $VERSION_CODE)${NC}"
                fi
            fi
            
            # 清理临时文件
            rm -f "$manifest_file.tmp"
            
            echo -e "${GREEN}   ✅ $manifest_file 更新完成${NC}"
        fi
    done
else
    echo -e "${YELLOW}⚠️  无法获取GitHub仓库信息，请手动更新manifest文件${NC}"
fi

# 显示更新摘要
echo -e "${GREEN}🎉 HAP包更新完成！${NC}"
echo -e "${BLUE}================${NC}"
echo -e "${GREEN}📊 更新摘要:${NC}"
echo -e "   📦 文件大小: $OLD_HAP_SIZE → $NEW_HAP_SIZE"
echo -e "   🔐 文件哈希: ${OLD_HAP_HASH:0:16}... → ${NEW_HAP_HASH:0:16}..."
if [ ! -z "$NEW_VERSION" ]; then
    echo -e "   🏷️  版本号: $NEW_VERSION"
fi
echo

# 询问是否立即提交
echo -e "${BLUE}📤 接下来的操作:${NC}"
echo -e "   1. 检查更新是否正确"
echo -e "   2. 提交更改: git add . && git commit -m '📱 Update HAP package'"
echo -e "   3. 推送到GitHub: git push origin main"
echo

read -p "是否立即提交并推送更改？(y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}📤 提交更改...${NC}"
    
    git add .
    
    COMMIT_MSG="📱 Update HAP package to ${NEW_VERSION:-'new version'}

- File hash: ${NEW_HAP_HASH:0:16}...
- File size: $NEW_HAP_SIZE"
    
    if [ ! -z "$NEW_VERSION" ]; then
        COMMIT_MSG="$COMMIT_MSG
- Version: $NEW_VERSION"
    fi
    
    git commit -m "$COMMIT_MSG"
    
    echo -e "${BLUE}🚀 推送到GitHub...${NC}"
    git push origin main
    
    echo -e "${GREEN}✅ 更新已推送到GitHub${NC}"
    echo -e "${BLUE}🌐 新版本将在以下地址可用:${NC}"
    if [ ! -z "$USERNAME" ] && [ ! -z "$REPO_NAME" ]; then
        echo -e "   🚀 jsDelivr CDN: https://cdn.jsdelivr.net/gh/$USERNAME/$REPO_NAME@main/hap/AppSigned.hap"
        echo -e "   🏠 GitHub Pages: https://$USERNAME.github.io/$REPO_NAME/"
        echo -e "   🔄 缓存刷新: https://purge.jsdelivr.net/gh/$USERNAME/$REPO_NAME@main/hap/AppSigned.hap"
    fi
    echo -e "${YELLOW}⏰ 注意: jsDelivr CDN可能需要5-10分钟同步更新${NC}"
else
    echo -e "${YELLOW}📝 手动提交命令:${NC}"
    echo -e "   git add ."
    echo -e "   git commit -m '📱 Update HAP package'"
    echo -e "   git push origin main"
fi

echo -e "${GREEN}🚀 HAP包更新工具执行完成！${NC}" 