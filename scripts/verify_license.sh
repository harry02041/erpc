#!/bin/bash
#
# Cadence 许可证验证脚本
# 用于检查许可证服务器连接和许可证可用性
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# ============================================
# 1. 解析许可证配置
# ============================================
echo_info "检查许可证配置..."

LICENSE_CONFIG="${LM_LICENSE_FILE:-${XTENSA_LICENSE_FILE}}"

if [ -z "$LICENSE_CONFIG" ]; then
    echo_error "未设置许可证配置"
    echo "请设置环境变量:"
    echo "  export LM_LICENSE_FILE=port@hostname"
    echo "  或"
    echo "  export LM_LICENSE_FILE=/path/to/license.dat"
    exit 1
fi

echo_info "许可证配置: $LICENSE_CONFIG"

# ============================================
# 2. 区分网络许可证和文件许可证
# ============================================
if [[ "$LICENSE_CONFIG" == *"@"* ]]; then
    # 网络许可证
    LICENSE_TYPE="network"
    LICENSE_PORT=$(echo "$LICENSE_CONFIG" | cut -d'@' -f1)
    LICENSE_SERVER=$(echo "$LICENSE_CONFIG" | cut -d'@' -f2)

    echo_info "许可证类型: 网络许可证"
    echo_info "  服务器: $LICENSE_SERVER"
    echo_info "  端口: $LICENSE_PORT"

    # 检查服务器连通性
    echo_info "测试许可证服务器连接..."

    if command -v nc &> /dev/null; then
        if timeout 5 nc -zv "$LICENSE_SERVER" "$LICENSE_PORT" 2>&1 | grep -q succeeded; then
            echo_info "  ✓ 许可证服务器连接成功"
        else
            echo_error "  ✗ 无法连接到许可证服务器"
            echo "请检查:"
            echo "  1. 服务器地址是否正确"
            echo "  2. 网络连接是否正常"
            echo "  3. 防火墙是否允许 $LICENSE_PORT 端口"
            exit 1
        fi
    else
        echo_warn "nc 命令不可用，跳过连接测试"
    fi

elif [ -f "$LICENSE_CONFIG" ]; then
    # 文件许可证
    LICENSE_TYPE="file"
    echo_info "许可证类型: 文件许可证"
    echo_info "  文件: $LICENSE_CONFIG"

    # 检查文件权限
    if [ -r "$LICENSE_CONFIG" ]; then
        echo_info "  ✓ 许可证文件可读"
    else
        echo_error "  ✗ 许可证文件不可读"
        exit 1
    fi

    # 显示许可证文件内容（前几行）
    echo_debug "许可证文件内容（前5行）:"
    head -5 "$LICENSE_CONFIG" | sed 's/^/    /'

else
    echo_error "许可证配置无效: $LICENSE_CONFIG"
    exit 1
fi

# ============================================
# 3. 测试 FlexLM 工具（如果可用）
# ============================================
echo_info "检查 FlexLM 许可证管理工具..."

# 查找 lmutil 或 lmstat
LMUTIL=""
if [ -n "$XTENSA_TOOLS_ROOT" ] && [ -x "${XTENSA_TOOLS_ROOT}/bin/lmutil" ]; then
    LMUTIL="${XTENSA_TOOLS_ROOT}/bin/lmutil"
elif command -v lmutil &> /dev/null; then
    LMUTIL=$(command -v lmutil)
fi

if [ -n "$LMUTIL" ]; then
    echo_info "找到 lmutil: $LMUTIL"

    echo_info "查询许可证状态..."
    if "$LMUTIL" lmstat -c "$LICENSE_CONFIG" -a 2>&1 | head -20; then
        echo_info "  ✓ 许可证查询成功"
    else
        echo_warn "  ✗ 许可证查询失败（可能是许可证服务器问题）"
    fi
else
    echo_warn "lmutil 未找到，跳过详细许可证检查"
fi

# ============================================
# 4. 测试编译器许可证
# ============================================
if [ -n "$XTENSA_TOOLS_ROOT" ] && [ -n "$XTENSA_CORE" ]; then
    echo_info "测试 Cadence 编译器许可证..."

    TEST_FILE=$(mktemp --suffix=.c)
    cat > "$TEST_FILE" <<'EOF'
int test() { return 42; }
EOF

    XTENSA_BIN="${XTENSA_TOOLS_ROOT}/bin"

    if [ -x "${XTENSA_BIN}/xt-xcc" ]; then
        if "${XTENSA_BIN}/xt-xcc" --xtensa-core="${XTENSA_CORE}" -c "$TEST_FILE" -o /tmp/test.o 2>&1; then
            echo_info "  ✓ 编译器许可证有效"
            rm -f /tmp/test.o
        else
            echo_error "  ✗ 编译器许可证测试失败"
            echo "可能的原因:"
            echo "  1. 许可证已过期"
            echo "  2. 许可证数量不足"
            echo "  3. 许可证特性不匹配"
        fi
    else
        echo_warn "编译器不可用，跳过编译测试"
    fi

    rm -f "$TEST_FILE"
else
    echo_warn "XTENSA_TOOLS_ROOT 或 XTENSA_CORE 未设置，跳过编译器测试"
fi

# ============================================
# 5. 常见问题诊断
# ============================================
echo ""
echo_info "================================"
echo_info "许可证验证完成"
echo_info "================================"
echo ""
echo "如果遇到许可证问题，请检查:"
echo ""
echo "1. 网络许可证:"
echo "   - 确保许可证服务器运行中"
echo "   - 检查防火墙设置（通常是 27000-27009 端口）"
echo "   - 验证服务器主机名解析"
echo "   - 确保许可证未过期"
echo ""
echo "2. 文件许可证:"
echo "   - 检查文件路径是否正确"
echo "   - 确保文件权限可读"
echo "   - 验证许可证内容有效"
echo "   - 检查主机 ID 是否匹配"
echo ""
echo "3. Docker 环境:"
echo "   - 确保正确挂载许可证文件"
echo "   - 检查容器网络配置（访问许可证服务器）"
echo "   - 验证环境变量传递正确"
echo ""
echo "4. 联系 Cadence 支持:"
echo "   - 提供许可证服务器日志"
echo "   - 提供 lmstat 输出"
echo "   - 说明错误信息"
echo ""
