# Makefile for Heterogeneous ARM + DSP Build
# 异构多核编译示例：ARM GCC + Cadence Xtensa DSP

# ============================================
# 工具链配置
# ============================================

# ARM 工具链
ARM_CC      := arm-none-eabi-gcc
ARM_CXX     := arm-none-eabi-g++
ARM_LD      := arm-none-eabi-ld
ARM_AR      := arm-none-eabi-ar
ARM_OBJCOPY := arm-none-eabi-objcopy

# Cadence DSP 工具链
DSP_CC      := xt-xcc
DSP_CXX     := xt-clang
DSP_LD      := xt-ld
DSP_AR      := xt-ar

# DSP Core 配置（从环境变量获取）
XTENSA_CORE ?= my_dsp_core

# ============================================
# 编译选项
# ============================================

# ARM 编译选项
ARM_CFLAGS  := -mcpu=cortex-m7 -mthumb -O2 -g
ARM_CFLAGS  += -I../../erpc_c/config
ARM_CFLAGS  += -I../../erpc_c/infra
ARM_CFLAGS  += -I../../erpc_c/port
ARM_CFLAGS  += -I../../erpc_c/setup
ARM_CFLAGS  += -I../../erpc_c/transports
ARM_CFLAGS  += -Iarm/include

ARM_LDFLAGS := -mcpu=cortex-m7 -mthumb
ARM_LDFLAGS += -Wl,--gc-sections

# DSP 编译选项
DSP_CFLAGS  := --xtensa-core=$(XTENSA_CORE) -O3 -g
DSP_CFLAGS  += -I../../erpc_c/config
DSP_CFLAGS  += -I../../erpc_c/infra
DSP_CFLAGS  += -I../../erpc_c/port
DSP_CFLAGS  += -I../../erpc_c/setup
DSP_CFLAGS  += -I../../erpc_c/transports
DSP_CFLAGS  += -Idsp/include

DSP_LDFLAGS := --xtensa-core=$(XTENSA_CORE)

# ============================================
# 源文件定义
# ============================================

# ARM 源文件（客户端）
ARM_SOURCES := arm/arm_client_main.c \
               arm/arm_rpmsg_transport.c \
               arm/arm_system_init.c

# DSP 源文件（服务器）
DSP_SOURCES := dsp/dsp_server_main.c \
               dsp/dsp_rpmsg_transport.c \
               dsp/dsp_audio_processing.c

# eRPC 生成的代码（ARM 客户端）
ARM_ERPC_GEN := generated/arm_client.cpp \
                generated/erpc_audio_client.cpp

# eRPC 生成的代码（DSP 服务器）
DSP_ERPC_GEN := generated/dsp_server.cpp \
                generated/erpc_audio_server.cpp

# eRPC 库路径
ERPC_LIB := ../../Release/Linux/erpc/liberpc.a

# ============================================
# 目标文件
# ============================================

ARM_OBJECTS := $(ARM_SOURCES:.c=.o)
ARM_OBJECTS += $(ARM_ERPC_GEN:.cpp=.o)

DSP_OBJECTS := $(DSP_SOURCES:.c=.o)
DSP_OBJECTS += $(DSP_ERPC_GEN:.cpp=.o)

# ============================================
# 输出文件
# ============================================

ARM_ELF := build/arm_client.elf
ARM_BIN := build/arm_client.bin

DSP_ELF := build/dsp_server.elf
DSP_BIN := build/dsp_server.bin

# ============================================
# 构建规则
# ============================================

.PHONY: all clean arm dsp erpc-gen

all: erpc-gen arm dsp

# 生成 eRPC 代码
erpc-gen: audio_service.erpc
	@echo "生成 eRPC 代码..."
	@mkdir -p generated
	../../Release/Linux/erpcgen/erpcgen -o generated/ audio_service.erpc

# 编译 ARM 客户端
arm: $(ARM_ELF) $(ARM_BIN)
	@echo "ARM 客户端编译完成: $(ARM_ELF)"

$(ARM_ELF): $(ARM_OBJECTS) $(ERPC_LIB)
	@echo "链接 ARM 客户端..."
	@mkdir -p build
	$(ARM_LD) $(ARM_LDFLAGS) -o $@ $(ARM_OBJECTS) $(ERPC_LIB)

$(ARM_BIN): $(ARM_ELF)
	@echo "生成 ARM 二进制文件..."
	$(ARM_OBJCOPY) -O binary $< $@

# ARM C 文件编译
arm/%.o: arm/%.c
	@echo "编译 ARM C: $<"
	$(ARM_CC) $(ARM_CFLAGS) -c $< -o $@

# ARM C++ 文件编译（eRPC 生成的代码）
generated/%.o: generated/%.cpp
	@echo "编译 ARM C++: $<"
	$(ARM_CXX) $(ARM_CFLAGS) -c $< -o $@

# 编译 DSP 服务器
dsp: $(DSP_ELF) $(DSP_BIN)
	@echo "DSP 服务器编译完成: $(DSP_ELF)"

$(DSP_ELF): $(DSP_OBJECTS) $(ERPC_LIB)
	@echo "链接 DSP 服务器..."
	@mkdir -p build
	$(DSP_LD) $(DSP_LDFLAGS) -o $@ $(DSP_OBJECTS) $(ERPC_LIB)

$(DSP_BIN): $(DSP_ELF)
	@echo "生成 DSP 二进制文件..."
	xt-objcopy -O binary $< $@

# DSP C 文件编译
dsp/%.o: dsp/%.c
	@echo "编译 DSP C: $<"
	$(DSP_CC) $(DSP_CFLAGS) -c $< -o $@

# DSP C++ 文件编译（eRPC 生成的代码）
generated/%_server.o: generated/%_server.cpp
	@echo "编译 DSP C++: $<"
	$(DSP_CXX) $(DSP_CFLAGS) -c $< -o $@

# ============================================
# 清理
# ============================================

clean:
	@echo "清理编译文件..."
	rm -rf build/
	rm -rf generated/
	rm -f arm/*.o
	rm -f dsp/*.o

# ============================================
# 调试和信息
# ============================================

info:
	@echo "=========================================="
	@echo "异构编译配置信息"
	@echo "=========================================="
	@echo "ARM 工具链:"
	@echo "  CC:  $(ARM_CC)"
	@echo "  CXX: $(ARM_CXX)"
	@which $(ARM_CC) || echo "  [未找到]"
	@echo ""
	@echo "DSP 工具链:"
	@echo "  CC:  $(DSP_CC)"
	@echo "  CXX: $(DSP_CXX)"
	@echo "  Core: $(XTENSA_CORE)"
	@which $(DSP_CC) || echo "  [未找到 - 请配置 Cadence 环境]"
	@echo ""
	@echo "eRPC 库: $(ERPC_LIB)"
	@test -f $(ERPC_LIB) && echo "  [存在]" || echo "  [不存在 - 请先编译 eRPC]"
	@echo "=========================================="

# 检查工具链
check-toolchain:
	@echo "检查 ARM 工具链..."
	@$(ARM_CC) --version || (echo "错误: ARM GCC 未安装"; exit 1)
	@echo ""
	@echo "检查 DSP 工具链..."
	@$(DSP_CC) --version || (echo "错误: Cadence DSP 工具链未配置"; exit 1)
	@echo ""
	@echo "检查 XTENSA_CORE..."
	@test -n "$(XTENSA_CORE)" || (echo "错误: XTENSA_CORE 未设置"; exit 1)
	@echo "  Core: $(XTENSA_CORE)"

# ============================================
# 辅助目标
# ============================================

# 查看编译命令（调试用）
verbose: ARM_CFLAGS += -v
verbose: DSP_CFLAGS += -v
verbose: all

# 仅编译，不链接
compile-only: $(ARM_OBJECTS) $(DSP_OBJECTS)

# 显示文件大小
size: $(ARM_ELF) $(DSP_ELF)
	@echo "ARM 客户端大小:"
	@arm-none-eabi-size $(ARM_ELF)
	@echo ""
	@echo "DSP 服务器大小:"
	@xt-size $(DSP_ELF)

# ============================================
# 使用说明
# ============================================

help:
	@echo "异构编译 Makefile 使用说明"
	@echo ""
	@echo "前置准备:"
	@echo "  1. 安装 ARM GCC 工具链"
	@echo "  2. 配置 Cadence Xtensa 环境:"
	@echo "     export XTENSA_TOOLS_ROOT=/path/to/xtensa/tools"
	@echo "     export XTENSA_CORE=your_dsp_core"
	@echo "     export PATH=\$$XTENSA_TOOLS_ROOT/bin:\$$PATH"
	@echo "  3. 编译 eRPC 库: cd ../.. && make all"
	@echo ""
	@echo "常用目标:"
	@echo "  make all             - 生成代码并编译 ARM + DSP"
	@echo "  make erpc-gen        - 仅生成 eRPC 代码"
	@echo "  make arm             - 仅编译 ARM 客户端"
	@echo "  make dsp             - 仅编译 DSP 服务器"
	@echo "  make clean           - 清理编译文件"
	@echo "  make info            - 显示配置信息"
	@echo "  make check-toolchain - 检查工具链"
	@echo "  make size            - 显示二进制文件大小"
	@echo "  make help            - 显示此帮助"
	@echo ""
	@echo "Docker 使用:"
	@echo "  docker-compose -f ../../docker-compose.dsp.yml run erpc-dsp-dev"
	@echo "  cd /workspace/examples/heterogeneous"
	@echo "  source ../../.xtensa_env"
	@echo "  make all"
	@echo ""
