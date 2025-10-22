#!/bin/bash
#
# Cadence DSP 工具链环境配置脚本
# 用于验证和配置 Cadence Xtensa 工具链环境
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================
# 1. 检查环境变量
# ============================================
echo_info "检查 Cadence 工具链环境变量..."

if [ -z "$XTENSA_TOOLS_ROOT" ]; then
    echo_error "XTENSA_TOOLS_ROOT 未设置"
    echo "请设置: export XTENSA_TOOLS_ROOT=/path/to/xtensa/tools"
    exit 1
fi

if [ ! -d "$XTENSA_TOOLS_ROOT" ]; then
    echo_error "工具链目录不存在: $XTENSA_TOOLS_ROOT"
    exit 1
fi

echo_info "工具链路径: $XTENSA_TOOLS_ROOT"

# ============================================
# 2. 检查 XTENSA_CORE 配置
# ============================================
if [ -z "$XTENSA_CORE" ]; then
    echo_warn "XTENSA_CORE 未设置"

    # 尝试列出可用的 core
    CORES_DIR="${XTENSA_TOOLS_ROOT}/config"
    if [ -d "$CORES_DIR" ]; then
        echo_info "可用的 Xtensa cores:"
        ls -1 "$CORES_DIR" 2>/dev/null || echo "  (无)"
    fi

    echo ""
    echo "请设置: export XTENSA_CORE=<your_core_name>"
    exit 1
fi

echo_info "Xtensa Core: $XTENSA_CORE"

# 验证 core 配置是否存在
CORE_CONFIG="${XTENSA_TOOLS_ROOT}/config/${XTENSA_CORE}"
if [ ! -d "$CORE_CONFIG" ]; then
    echo_error "Core 配置不存在: $CORE_CONFIG"
    exit 1
fi

# ============================================
# 3. 检查许可证配置
# ============================================
echo_info "检查许可证配置..."

if [ -z "$LM_LICENSE_FILE" ] && [ -z "$XTENSA_LICENSE_FILE" ]; then
    echo_error "许可证配置未设置"
    echo "请设置以下之一:"
    echo "  export LM_LICENSE_FILE=27000@license-server"
    echo "  export LM_LICENSE_FILE=/path/to/license.dat"
    exit 1
fi

# 显示许可证配置
if [ -n "$LM_LICENSE_FILE" ]; then
    echo_info "LM_LICENSE_FILE: $LM_LICENSE_FILE"
fi

if [ -n "$XTENSA_LICENSE_FILE" ]; then
    echo_info "XTENSA_LICENSE_FILE: $XTENSA_LICENSE_FILE"
fi

# ============================================
# 4. 检查工具链可执行文件
# ============================================
echo_info "检查 Cadence 编译器..."

XTENSA_BIN="${XTENSA_TOOLS_ROOT}/bin"

# 检查常用工具
TOOLS=("xt-xcc" "xt-clang" "xt-ld" "xt-ar" "xt-objdump")
FOUND_TOOLS=0

for tool in "${TOOLS[@]}"; do
    if [ -x "${XTENSA_BIN}/${tool}" ]; then
        echo_info "  ✓ ${tool} 找到"
        FOUND_TOOLS=$((FOUND_TOOLS + 1))
    else
        echo_warn "  ✗ ${tool} 未找到"
    fi
done

if [ $FOUND_TOOLS -eq 0 ]; then
    echo_error "未找到任何 Cadence 工具"
    exit 1
fi

# ============================================
# 5. 测试编译器
# ============================================
echo_info "测试编译器..."

# 创建临时测试文件
TEST_FILE=$(mktemp --suffix=.c)
cat > "$TEST_FILE" <<'EOF'
#include <stdio.h>
int main() {
    printf("Cadence DSP Compiler Test\n");
    return 0;
}
EOF

# 尝试编译
if "${XTENSA_BIN}/xt-xcc" --xtensa-core="${XTENSA_CORE}" -c "$TEST_FILE" -o /tmp/test.o 2>/dev/null; then
    echo_info "  ✓ 编译器测试通过"
    rm -f /tmp/test.o
else
    echo_error "  ✗ 编译器测试失败"
    echo_warn "这可能是许可证问题，请检查许可证服务器"
fi

rm -f "$TEST_FILE"

# ============================================
# 6. 设置 PATH 和 LD_LIBRARY_PATH
# ============================================
echo_info "配置环境变量..."

export PATH="${XTENSA_BIN}:${PATH}"
export LD_LIBRARY_PATH="${XTENSA_TOOLS_ROOT}/lib:${LD_LIBRARY_PATH}"

# ============================================
# 7. 显示工具链版本信息
# ============================================
echo_info "工具链版本信息:"

if [ -x "${XTENSA_BIN}/xt-xcc" ]; then
    "${XTENSA_BIN}/xt-xcc" --version 2>/dev/null | head -1 || echo "  (无法获取版本)"
fi

# ============================================
# 8. 生成环境配置文件
# ============================================
ENV_FILE="${PWD}/.xtensa_env"
cat > "$ENV_FILE" <<EOF
# Cadence Xtensa 工具链环境配置
# 由 setup_dsp_toolchain.sh 自动生成
# 使用方法: source ${ENV_FILE}

export XTENSA_TOOLS_ROOT="${XTENSA_TOOLS_ROOT}"
export XTENSA_CORE="${XTENSA_CORE}"
export LM_LICENSE_FILE="${LM_LICENSE_FILE}"
export PATH="${XTENSA_BIN}:\${PATH}"
export LD_LIBRARY_PATH="${XTENSA_TOOLS_ROOT}/lib:\${LD_LIBRARY_PATH}"

echo "Cadence Xtensa 工具链环境已加载"
echo "  工具链: \${XTENSA_TOOLS_ROOT}"
echo "  Core: \${XTENSA_CORE}"
EOF

echo_info "环境配置文件已生成: $ENV_FILE"
echo_info "使用 'source $ENV_FILE' 加载配置"

# ============================================
# 9. 总结
# ============================================
echo ""
echo_info "================================"
echo_info "Cadence 工具链配置完成！"
echo_info "================================"
echo ""
echo "下一步:"
echo "  1. source $ENV_FILE"
echo "  2. 编译 eRPC: make all"
echo "  3. 编译 DSP 代码: xt-xcc -c your_code.c"
echo ""
