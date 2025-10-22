# Dockerfile for eRPC Cloud Testing Environment
# 嵌入式 eRPC 云端编译测试环境

FROM ubuntu:22.04

# 设置非交互式安装
ENV DEBIAN_FRONTEND=noninteractive

# 安装基础依赖
RUN apt-get update && apt-get install -y \
    # 编译工具
    gcc \
    g++ \
    clang \
    make \
    cmake \
    # 构建依赖
    bison \
    flex \
    git \
    # Python 环境
    python3 \
    python3-pip \
    # 调试工具
    gdb \
    valgrind \
    # 网络工具（用于 TCP 测试）
    netcat \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 安装 Python 测试依赖
RUN pip3 install --no-cache-dir \
    pytest \
    pyyaml \
    tornado

# 设置工作目录
WORKDIR /erpc

# 复制项目文件
COPY . .

# 预编译项目（可选，加速后续测试）
RUN make clean && make all || true

# 默认命令：运行完整测试套件
CMD ["python3", "test/run_unit_tests.py"]

# 使用示例：
# docker build -t erpc-test .
# docker run --rm erpc-test                          # 运行全部测试
# docker run --rm erpc-test make all                 # 仅编译
# docker run --rm erpc-test python3 test/run_unit_tests.py gcc  # 指定编译器测试
