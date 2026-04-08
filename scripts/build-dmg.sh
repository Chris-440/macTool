#!/bin/bash

# CPU Monitor DMG 打包脚本

set -e

# 配置
APP_NAME="CPU Monitor"
APP_BUNDLE="macTool.app"
DMG_NAME="CPU-Monitor"
VERSION="1.0.0"
BUILD_DIR="build/Release"
DMG_DIR="build/DMG"
RESOURCES_DIR="Resources"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}开始构建 ${APP_NAME} DMG 安装包...${NC}"

# 清理旧构建
echo -e "${YELLOW}清理旧构建...${NC}"
rm -rf "${BUILD_DIR}"
rm -rf "${DMG_DIR}"
rm -rf "build/${DMG_NAME}-${VERSION}.dmg"
rm -rf "build/${DMG_NAME}-${VERSION}.dmg.sha256"
mkdir -p "${DMG_DIR}"

# 构建 Release 版本
echo -e "${YELLOW}构建 Release 版本...${NC}"
xcodebuild -project macTool.xcodeproj \
    -scheme macTool \
    -configuration Release \
    -derivedDataPath build/DerivedData \
    clean build

# 检查构建结果
if [ ! -d "build/DerivedData/Build/Products/Release/${APP_BUNDLE}" ]; then
    echo -e "${RED}构建失败！${NC}"
    exit 1
fi

# 复制应用到 DMG 目录
echo -e "${YELLOW}准备 DMG 内容...${NC}"
cp -R "build/DerivedData/Build/Products/Release/${APP_BUNDLE}" "${DMG_DIR}/${APP_NAME}.app"

# 创建 Applications 快捷方式
ln -s /Applications "${DMG_DIR}/Applications"

# 创建 DMG
echo -e "${YELLOW}创建 DMG 文件...${NC}"
DMG_FILE="${DMG_NAME}-${VERSION}.dmg"
TEMP_DMG="build/${DMG_FILE}.temp"

# 创建临时 DMG
hdiutil create \
    -srcfolder "${DMG_DIR}" \
    -volname "${APP_NAME}" \
    -fs HFS+ \
    -format UDRW \
    -size 50m \
    "${TEMP_DMG}"

# 获取挂载点信息
echo -e "${YELLOW}挂载 DMG...${NC}"
MOUNT_INFO=$(hdiutil attach "${TEMP_DMG}" -noverify -nobrowse | grep "/Volumes/")
MOUNT_POINT=$(echo "${MOUNT_INFO}" | awk '{print $3}')

if [ -z "${MOUNT_POINT}" ]; then
    echo -e "${RED}挂载 DMG 失败！${NC}"
    exit 1
fi

echo -e "${YELLOW}DMG 挂载在: ${MOUNT_POINT}${NC}"

# 等待 Finder 识别
sleep 2

# 设置应用和 Applications 文件夹的位置
osascript <<EOF
tell application "Finder"
    set dmgWindow to window of disk "${APP_NAME}"
    set current view of dmgWindow to icon view
    set toolbar visible of dmgWindow to false
    set statusbar visible of dmgWindow to false
    set bounds of dmgWindow to {100, 100, 600, 400}
    
    try
        set appItem to item "${APP_NAME}.app" of disk "${APP_NAME}"
        set position of appItem to {150, 200}
        
        set appsItem to item "Applications" of disk "${APP_NAME}"
        set position of appsItem to {400, 200}
        
        update dmgWindow
    on error errMsg
        display dialog "Error: " & errMsg
    end try
end tell
EOF

# 等待设置生效
sleep 2

# 卸载 DMG
echo -e "${YELLOW}卸载 DMG...${NC}"
hdiutil detach "${MOUNT_POINT}" -force

# 转换为压缩的 DMG
echo -e "${YELLOW}压缩 DMG...${NC}"
hdiutil convert "${TEMP_DMG}" \
    -format UDZO \
    -o "build/${DMG_FILE}"

# 清理临时文件
rm -f "${TEMP_DMG}"
rm -rf "${DMG_DIR}"

# 计算文件大小
DMG_SIZE=$(du -h "build/${DMG_FILE}" | cut -f1)

echo -e "${GREEN}✓ DMG 打包完成！${NC}"
echo -e "${GREEN}文件: build/${DMG_FILE}${NC}"
echo -e "${GREEN}大小: ${DMG_SIZE}${NC}"

# 生成校验和
echo -e "${YELLOW}生成校验和...${NC}"
cd build && shasum -a 256 "${DMG_FILE}" > "${DMG_FILE}.sha256" && cd ..
echo -e "${GREEN}校验和文件: build/${DMG_FILE}.sha256${NC}"

echo -e "${GREEN}完成！${NC}"