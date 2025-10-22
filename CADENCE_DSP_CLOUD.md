# Cadence DSP 云端编译测试指南

本文档详细介绍如何在云端环境搭建 **ARM GCC + Cadence Xtensa DSP** 异构编译环境，用于嵌入式 eRPC 项目的开发和测试。

## 📋 目录

- [架构概览](#架构概览)
- [前置准备](#前置准备)
- [快速开始](#快速开始)
- [方案 1：Docker 本地环境](#方案-1docker-本地环境)
- [方案 2：云端 CI/CD](#方案-2云端-cicd)
- [方案 3：远程开发服务器](#方案-3远程开发服务器)
- [许可证配置](#许可证配置)
- [故障排查](#故障排查)
- [最佳实践](#最佳实践)

---

## 架构概览

### 典型的异构 SoC 架构

```
┌─────────────────────────────────────────┐
│         异构多核 SoC                      │
│                                         │
│  ┌──────────────┐    ┌──────────────┐  │
│  │   ARM Core   │<-->│ Cadence DSP  │  │
│  │   (主处理器)  │    │   (协处理器)  │  │
│  │              │    │              │  │
│  │  GCC 编译    │    │ xt-xcc 编译  │  │
│  └──────────────┘    └──────────────┘  │
│         ↓                    ↓          │
│    ┌────────────────────────────┐      │
│    │        eRPC 通信层          │      │
│    │  (RPMsg/Shared Memory)     │      │
│    └────────────────────────────┘      │
└─────────────────────────────────────────┘
```

### 编译工具链

| 组件 | 工具链 | 用途 |
|------|--------|------|
| ARM 核心 | arm-none-eabi-gcc | 主处理器代码 |
| DSP 核心 | xt-xcc / xt-clang | DSP 信号处理代码 |
| eRPC 库 | GCC / Clang | RPC 通信框架 |
| 代码生成 | erpcgen | IDL → C/C++ 生成 |

---

## 前置准备

### 1. 软件要求

**必需：**
- Docker (20.10+) 和 Docker Compose (2.0+)
- Cadence Xtensa 工具链（商业授权）
- 有效的 FlexLM 许可证

**可选：**
- ARM GCC 工具链（Docker 镜像已包含）
- Git (用于版本控制)

### 2. 获取 Cadence 工具链

Cadence Xtensa 工具链需要从 Cadence 官方获取：

1. **下载方式：**
   - Cadence 客户门户
   - SoC 供应商提供的 SDK（如 NXP、Espressif）

2. **典型安装路径：**
   ```
   /opt/cadence/xtensa/XtDevTools/
   ├── install/
   │   ├── tools/
   │   ├── builds/
   │   └── config/
   ├── bin/
   │   ├── xt-xcc
   │   ├── xt-clang
   │   └── xt-ld
   └── lib/
   ```

3. **支持的工具链版本：**
   - Xtensa Xplorer 8.x 及以上
   - RF-2016.4 及以上

### 3. 许可证配置

Cadence 工具链需要 FlexLM 许可证，支持两种方式：

**选项 A：网络许可证服务器**
```bash
export LM_LICENSE_FILE=27000@license-server.company.com
```

**选项 B：本地许可证文件**
```bash
export LM_LICENSE_FILE=/path/to/cadence.dat
```

---

## 快速开始

### 步骤 1：配置环境变量

```bash
# 复制配置模板
cp .env.dsp.example .env

# 编辑配置文件
vim .env
```

**最小配置示例：**
```bash
# .env 文件内容
XTENSA_CORE=my_hifi4_dsp
LM_LICENSE_FILE=27000@10.0.0.100
HOST_XTENSA_TOOLS=/opt/cadence/xtensa/XtDevTools
```

### 步骤 2：验证工具链

```bash
# 检查工具链是否存在
ls -la /opt/cadence/xtensa/XtDevTools/bin/xt-xcc

# 检查许可证服务器连通性
nc -zv license-server.company.com 27000
```

### 步骤 3：构建 Docker 环境

```bash
# 构建 Docker 镜像
docker build -f Dockerfile.cadence-dsp -t erpc-dsp .

# 或使用 docker-compose
docker-compose -f docker-compose.dsp.yml build
```

### 步骤 4：启动开发环境

```bash
# 进入交互式开发环境
docker-compose -f docker-compose.dsp.yml run erpc-dsp-dev

# 容器内验证配置
./scripts/verify_license.sh
./scripts/setup_dsp_toolchain.sh
```

### 步骤 5：编译项目

```bash
# 容器内执行

# 1. 加载 DSP 工具链环境
source .xtensa_env

# 2. 编译 eRPC 库
make clean && make all

# 3. 编译 ARM 代码
arm-none-eabi-gcc -c examples/arm_client.c -o arm_client.o

# 4. 编译 DSP 代码
xt-xcc --xtensa-core=$XTENSA_CORE \
       -c examples/dsp_server.c \
       -o dsp_server.o
```

---

## 方案 1：Docker 本地环境

### 架构说明

Docker 容器提供隔离的编译环境，工具链和许可证通过挂载方式访问。

```
┌─────────────────────────────────────────┐
│           宿主机 (Host)                  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │   Docker 容器                     │  │
│  │                                   │  │
│  │  ┌─────────────┐  ┌───────────┐  │  │
│  │  │ ARM GCC     │  │ Xtensa    │  │  │
│  │  │ (内置)      │  │ (挂载)    │←─┼──┼─ /opt/cadence/
│  │  └─────────────┘  └───────────┘  │  │
│  │                                   │  │
│  │  ┌─────────────────────────────┐ │  │
│  │  │      项目代码 (挂载)         │←┼──┼─ /home/user/erpc/
│  │  └─────────────────────────────┘ │  │
│  └──────────────────────────────────┘  │
│                ↓                        │
│         ┌─────────────┐                │
│         │ 许可证服务器 │←───────────────┼─ 网络访问
│         └─────────────┘                │
└─────────────────────────────────────────┘
```

### 详细配置步骤

#### 1. 修改 docker-compose.dsp.yml

```yaml
services:
  erpc-dsp-dev:
    volumes:
      # 挂载项目代码
      - .:/workspace

      # 挂载 Cadence 工具链（修改为实际路径）
      - /opt/cadence/xtensa/XtDevTools:/opt/toolchains/xtensa:ro

      # 挂载许可证文件（如果使用文件许可证）
      - /path/to/license.dat:/opt/licenses/license.dat:ro

    environment:
      # 工具链配置
      - XTENSA_TOOLS_ROOT=/opt/toolchains/xtensa
      - XTENSA_CORE=my_hifi4_dsp

      # 许可证配置（网络许可证）
      - LM_LICENSE_FILE=27000@license-server

    network_mode: host  # 使用宿主机网络访问许可证服务器
```

#### 2. 使用脚本自动化配置

**创建启动脚本：`start_dsp_env.sh`**

```bash
#!/bin/bash

# 检查配置
if [ ! -f .env ]; then
    echo "错误: .env 文件不存在"
    echo "请运行: cp .env.dsp.example .env"
    exit 1
fi

# 加载配置
source .env

# 验证工具链路径
if [ ! -d "$HOST_XTENSA_TOOLS" ]; then
    echo "错误: Cadence 工具链不存在: $HOST_XTENSA_TOOLS"
    exit 1
fi

# 启动容器
docker-compose -f docker-compose.dsp.yml run \
    -v "$HOST_XTENSA_TOOLS:/opt/toolchains/xtensa:ro" \
    erpc-dsp-dev
```

#### 3. 容器内工作流

```bash
# 1. 验证环境
./scripts/verify_license.sh

# 2. 配置工具链
./scripts/setup_dsp_toolchain.sh
source .xtensa_env

# 3. 查看工具链版本
xt-xcc --version

# 4. 编译示例
cd examples/
make

# 5. 运行测试
cd ../test/
python3 run_unit_tests.py
```

---

## 方案 2：云端 CI/CD

### GitHub Actions 配置

Cadence 工具链是商业软件，需要特殊配置才能在云端 CI 中使用。

#### 选项 A：Self-Hosted Runner（推荐）

**优势：**
- 完全控制编译环境
- 本地许可证服务器访问
- 无需上传工具链

**配置步骤：**

1. **安装 GitHub Actions Runner：**

```bash
# 在有 Cadence 工具链的服务器上
mkdir actions-runner && cd actions-runner

# 下载 runner
curl -o actions-runner-linux-x64-2.311.0.tar.gz \
  -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz

tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# 配置 runner
./config.sh --url https://github.com/your-org/erpc --token YOUR_TOKEN

# 启动 runner
./run.sh
```

2. **创建工作流：`.github/workflows/dsp-build.yml`**

```yaml
name: DSP Build and Test

on:
  push:
    branches: [ main, develop ]
  pull_request:

jobs:
  build-dsp:
    name: Build with Cadence DSP
    runs-on: [self-hosted, linux, cadence-dsp]  # 使用自托管 runner

    steps:
    - name: 检出代码
      uses: actions/checkout@v4

    - name: 配置 Cadence 环境
      run: |
        export XTENSA_TOOLS_ROOT=/opt/cadence/xtensa/XtDevTools
        export XTENSA_CORE=${{ secrets.XTENSA_CORE }}
        export LM_LICENSE_FILE=${{ secrets.LM_LICENSE_FILE }}
        ./scripts/setup_dsp_toolchain.sh

    - name: 验证许可证
      run: ./scripts/verify_license.sh

    - name: 编译 eRPC
      run: |
        source .xtensa_env
        make clean && make all

    - name: 编译 DSP 代码
      run: |
        source .xtensa_env
        xt-xcc --xtensa-core=$XTENSA_CORE -c examples/dsp_code.c

    - name: 运行测试
      run: |
        python3 test/run_unit_tests.py

    - name: 上传构建产物
      uses: actions/upload-artifact@v4
      with:
        name: dsp-binaries
        path: Release/
```

3. **配置 GitHub Secrets：**

在仓库设置中添加：
- `XTENSA_CORE`: DSP core 名称
- `LM_LICENSE_FILE`: 许可证服务器地址

#### 选项 B：Docker + Runner 组合

如果团队有多个开发者，可以使用 Docker 统一环境：

```yaml
jobs:
  build-dsp-docker:
    runs-on: [self-hosted]

    steps:
    - uses: actions/checkout@v4

    - name: 构建 Docker 环境
      run: |
        docker build -f Dockerfile.cadence-dsp -t erpc-dsp .

    - name: 运行编译
      run: |
        docker run --rm \
          -v /opt/cadence/xtensa:/opt/toolchains/xtensa:ro \
          -v $(pwd):/workspace \
          -e XTENSA_CORE=${{ secrets.XTENSA_CORE }} \
          -e LM_LICENSE_FILE=${{ secrets.LM_LICENSE_FILE }} \
          --network host \
          erpc-dsp \
          bash -c "source .xtensa_env && make all"
```

### CircleCI 配置

如果使用 CircleCI，需要配置 self-hosted executor：

```yaml
# .circleci/config.yml

version: 2.1

executors:
  dsp-builder:
    machine: true
    resource_class: your-org/cadence-dsp  # self-hosted executor

jobs:
  build-dsp:
    executor: dsp-builder
    steps:
      - checkout

      - run:
          name: 配置环境
          command: |
            export XTENSA_TOOLS_ROOT=/opt/cadence/xtensa/XtDevTools
            export XTENSA_CORE=${CIRCLE_XTENSA_CORE}
            export LM_LICENSE_FILE=${CIRCLE_LICENSE_SERVER}
            ./scripts/setup_dsp_toolchain.sh

      - run:
          name: 编译项目
          command: |
            source .xtensa_env
            make all

workflows:
  build-and-test:
    jobs:
      - build-dsp
```

---

## 方案 3：远程开发服务器

### 架构设计

适用于团队共享的开发服务器：

```
┌────────────────────────────────────────────────┐
│          远程开发服务器                         │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  Cadence 工具链 + eRPC 环境               │ │
│  │  /opt/cadence/xtensa/                    │ │
│  └──────────────────────────────────────────┘ │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  用户工作空间                             │ │
│  │  /home/user1/erpc/                       │ │
│  │  /home/user2/erpc/                       │ │
│  └──────────────────────────────────────────┘ │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  本地许可证服务器                         │ │
│  │  FlexLM @ localhost:27000                │ │
│  └──────────────────────────────────────────┘ │
└────────────────────────────────────────────────┘
         ↑
         │ SSH / VSCode Remote
         │
   开发者本地机器
```

### 服务器配置步骤

#### 1. 安装 Cadence 工具链

```bash
# 管理员操作
sudo mkdir -p /opt/cadence/xtensa
cd /opt/cadence/xtensa

# 解压工具链（示例）
sudo tar xzf XtDevTools-RI-2023.11-linux.tar.gz

# 设置权限
sudo chown -R root:cadence-users /opt/cadence/xtensa
sudo chmod -R 755 /opt/cadence/xtensa
```

#### 2. 配置许可证服务器

**安装 FlexLM：**

```bash
# 安装 FlexLM daemon
cd /opt/cadence/xtensa/flexlm
sudo ./lmgrd -c /opt/licenses/cadence.dat -l /var/log/flexlm.log

# 设置开机自启
sudo cat > /etc/systemd/system/flexlm.service <<'EOF'
[Unit]
Description=FlexLM License Server for Cadence
After=network.target

[Service]
Type=forking
ExecStart=/opt/cadence/xtensa/flexlm/lmgrd -c /opt/licenses/cadence.dat -l /var/log/flexlm.log
PIDFile=/var/run/lmgrd.pid
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable flexlm
sudo systemctl start flexlm
```

**验证许可证服务：**

```bash
# 查看许可证状态
/opt/cadence/xtensa/flexlm/lmutil lmstat -c 27000@localhost -a

# 检查可用许可证数量
/opt/cadence/xtensa/flexlm/lmutil lmstat -c 27000@localhost -f
```

#### 3. 用户环境配置

**创建团队共享脚本：`/etc/profile.d/cadence.sh`**

```bash
# Cadence Xtensa 环境配置

export XTENSA_TOOLS_ROOT=/opt/cadence/xtensa/XtDevTools
export LM_LICENSE_FILE=27000@localhost

# 添加到 PATH
export PATH="${XTENSA_TOOLS_ROOT}/bin:${PATH}"
export LD_LIBRARY_PATH="${XTENSA_TOOLS_ROOT}/lib:${LD_LIBRARY_PATH}"

# 函数：切换 DSP core
switch_core() {
    if [ -z "$1" ]; then
        echo "使用方法: switch_core <core_name>"
        echo "可用 cores:"
        ls -1 ${XTENSA_TOOLS_ROOT}/config/
        return 1
    fi

    export XTENSA_CORE="$1"
    echo "已切换到 core: $XTENSA_CORE"
}
```

#### 4. VSCode Remote 开发

**安装扩展：**
- Remote - SSH
- C/C++
- CMake Tools

**配置 `.vscode/settings.json`：**

```json
{
    "C_Cpp.default.compilerPath": "/opt/cadence/xtensa/XtDevTools/bin/xt-xcc",
    "C_Cpp.default.includePath": [
        "${workspaceFolder}/**",
        "/opt/cadence/xtensa/XtDevTools/include/**"
    ],
    "C_Cpp.default.defines": [
        "XTENSA",
        "__XTENSA__"
    ],
    "terminal.integrated.env.linux": {
        "XTENSA_TOOLS_ROOT": "/opt/cadence/xtensa/XtDevTools",
        "XTENSA_CORE": "my_hifi4_dsp",
        "LM_LICENSE_FILE": "27000@localhost"
    }
}
```

**配置任务 `.vscode/tasks.json`：**

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Build eRPC",
            "type": "shell",
            "command": "make all",
            "group": {
                "kind": "build",
                "isDefault": true
            }
        },
        {
            "label": "Build DSP Code",
            "type": "shell",
            "command": "xt-xcc --xtensa-core=${XTENSA_CORE} -c ${file}",
            "problemMatcher": []
        },
        {
            "label": "Verify License",
            "type": "shell",
            "command": "./scripts/verify_license.sh"
        }
    ]
}
```

---

## 许可证配置

### 网络许可证服务器

#### 配置格式

```bash
# 单个服务器
export LM_LICENSE_FILE=27000@license-server.company.com

# 多个服务器（冗余）
export LM_LICENSE_FILE=27000@server1.com:27001@server2.com

# 指定端口
export LM_LICENSE_FILE=27010@license-server
```

#### 防火墙配置

许可证服务器需要开放端口：

```bash
# Linux (ufw)
sudo ufw allow 27000:27009/tcp

# Linux (iptables)
sudo iptables -A INPUT -p tcp --dport 27000:27009 -j ACCEPT

# 查看连接
netstat -an | grep 27000
```

#### Docker 网络配置

```yaml
# docker-compose.dsp.yml

services:
  erpc-dsp-dev:
    # 选项 1: 使用宿主机网络（推荐）
    network_mode: host

    # 选项 2: 桥接网络 + 主机映射
    # extra_hosts:
    #   - "license-server:192.168.1.100"

    # 选项 3: 自定义网络
    # networks:
    #   - dsp-net

# networks:
#   dsp-net:
#     driver: bridge
```

### 文件许可证

#### 挂载许可证文件

```bash
# Docker 运行时挂载
docker run -it --rm \
  -v /path/to/license.dat:/opt/licenses/license.dat:ro \
  -e LM_LICENSE_FILE=/opt/licenses/license.dat \
  erpc-dsp
```

#### 许可证文件格式示例

```
SERVER license-server 001122334455 27000
VENDOR cadence

# Feature licenses
INCREMENT XTOMP cadence 1.0 permanent 10 \
    HOSTID=001122334455 SIGN=ABCD1234...
```

### 许可证故障排查

```bash
# 1. 验证许可证文件
cat /opt/licenses/license.dat

# 2. 测试服务器连接
telnet license-server 27000

# 或使用 nc
nc -zv license-server 27000

# 3. 查看许可证状态
lmutil lmstat -c 27000@license-server -a

# 4. 查看特定 feature
lmutil lmstat -c 27000@license-server -f XTOMP

# 5. 检查许可证用户
lmutil lmstat -c 27000@license-server -i

# 6. 运行诊断脚本
./scripts/verify_license.sh
```

---

## 故障排查

### 常见问题

#### 1. 许可证连接失败

**错误信息：**
```
Error: Cannot connect to license server
```

**解决方法：**

```bash
# a) 检查服务器连通性
ping license-server
nc -zv license-server 27000

# b) 检查 DNS 解析
nslookup license-server

# c) Docker 容器内测试
docker run --rm --network host \
  ubuntu nc -zv license-server 27000

# d) 使用 IP 地址代替主机名
export LM_LICENSE_FILE=27000@192.168.1.100
```

#### 2. Core 配置不存在

**错误信息：**
```
Error: Configuration 'my_core' not found
```

**解决方法：**

```bash
# 列出可用 cores
ls -la ${XTENSA_TOOLS_ROOT}/config/

# 验证 core 名称
export XTENSA_CORE=correct_core_name

# 检查 core 配置文件
ls -la ${XTENSA_TOOLS_ROOT}/config/${XTENSA_CORE}/
```

#### 3. 工具链找不到

**错误信息：**
```
bash: xt-xcc: command not found
```

**解决方法：**

```bash
# a) 检查挂载路径
docker run --rm -v /opt/cadence/xtensa:/opt/toolchains/xtensa:ro \
  erpc-dsp ls -la /opt/toolchains/xtensa/bin

# b) 手动添加到 PATH
export PATH="/opt/toolchains/xtensa/bin:${PATH}"

# c) 使用绝对路径
/opt/toolchains/xtensa/bin/xt-xcc --version

# d) 运行配置脚本
./scripts/setup_dsp_toolchain.sh
source .xtensa_env
```

#### 4. 编译器许可证错误

**错误信息：**
```
xt-xcc: error: license checkout failed
```

**解决方法：**

```bash
# a) 验证许可证配置
echo $LM_LICENSE_FILE

# b) 测试许可证
lmutil lmstat -c $LM_LICENSE_FILE -a

# c) 检查许可证数量
lmutil lmstat -c $LM_LICENSE_FILE -f XTOMP

# d) 等待许可证释放
# 如果许可证数量不足，等待其他用户完成

# e) 联系管理员增加许可证
```

#### 5. Docker 挂载权限问题

**错误信息：**
```
Permission denied: /opt/toolchains/xtensa/bin/xt-xcc
```

**解决方法：**

```bash
# a) 检查宿主机权限
ls -la /opt/cadence/xtensa/bin/xt-xcc

# b) 修复权限
sudo chmod +x /opt/cadence/xtensa/bin/xt-xcc

# c) 修改 Docker 用户
docker run --user root ...

# d) 使用只读挂载
-v /opt/cadence/xtensa:/opt/toolchains/xtensa:ro
```

---

## 最佳实践

### 1. 版本管理

```bash
# 使用 Git 管理配置
git add .env.dsp.example
git add docker-compose.dsp.yml
git add scripts/setup_dsp_toolchain.sh

# 忽略敏感信息
echo ".env" >> .gitignore
echo ".xtensa_env" >> .gitignore
```

### 2. 团队协作

**创建共享配置模板：**

```bash
# team_config/dsp_cores.json
{
  "cores": {
    "hifi4": {
      "name": "hifi4_audio_dsp",
      "toolchain_version": "RI-2023.11",
      "description": "音频处理 DSP"
    },
    "hifi5": {
      "name": "hifi5_vision_dsp",
      "toolchain_version": "RI-2024.2",
      "description": "视觉处理 DSP"
    }
  }
}
```

**文档化流程：**

```markdown
# 团队开发流程

1. 克隆仓库
   git clone https://github.com/company/erpc.git

2. 配置环境
   cp .env.dsp.example .env
   vim .env  # 修改 XTENSA_CORE

3. 启动开发环境
   ./start_dsp_env.sh

4. 验证配置
   ./scripts/verify_license.sh

5. 开始开发
   make all
```

### 3. CI/CD 流水线

```yaml
# 完整的 CI/CD 示例

stages:
  - validate
  - build-arm
  - build-dsp
  - test
  - package

validate-license:
  stage: validate
  script:
    - ./scripts/verify_license.sh

build-arm:
  stage: build-arm
  script:
    - arm-none-eabi-gcc -c src/arm/*.c

build-dsp:
  stage: build-dsp
  script:
    - source .xtensa_env
    - xt-xcc --xtensa-core=$XTENSA_CORE -c src/dsp/*.c

test-integration:
  stage: test
  script:
    - python3 test/run_unit_tests.py

package-release:
  stage: package
  script:
    - tar czf erpc-release.tar.gz Release/
  artifacts:
    paths:
      - erpc-release.tar.gz
```

### 4. 性能优化

**多阶段构建：**

```dockerfile
# Dockerfile.cadence-dsp (优化版)

# 阶段 1: 构建环境
FROM ubuntu:22.04 AS builder
# ... 安装编译依赖 ...
COPY . /build
WORKDIR /build
RUN make all

# 阶段 2: 运行环境（更小）
FROM ubuntu:22.04
COPY --from=builder /build/Release /app/Release
# ... 仅复制必要的运行时库 ...
```

**缓存优化：**

```yaml
# docker-compose.dsp.yml

volumes:
  # 持久化编译缓存
  dsp-build-cache:
  dsp-ccache:

services:
  erpc-dsp-dev:
    volumes:
      - dsp-ccache:/root/.cache/ccache
    environment:
      - CCACHE_DIR=/root/.cache/ccache
```

---

## 安全考虑

### 1. 许可证保护

```bash
# 不要将许可证文件提交到 Git
echo "*.dat" >> .gitignore
echo ".env" >> .gitignore

# 使用环境变量传递敏感信息
export LM_LICENSE_FILE=$(cat ~/.license_server)
```

### 2. Docker 安全

```yaml
# docker-compose.dsp.yml

services:
  erpc-dsp-dev:
    # 只读挂载工具链
    volumes:
      - /opt/cadence/xtensa:/opt/toolchains/xtensa:ro

    # 限制容器权限
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID

    # 使用非 root 用户
    user: "1000:1000"
```

### 3. 网络隔离

```bash
# 仅允许访问许可证服务器
docker run --rm \
  --network none \
  --add-host license-server:192.168.1.100 \
  erpc-dsp
```

---

## 附录

### A. Cadence 工具链常用命令

```bash
# 编译
xt-xcc --xtensa-core=my_core -c file.c

# 汇编
xt-xcc --xtensa-core=my_core -S file.c

# 链接
xt-ld -o app.elf file1.o file2.o

# 查看符号
xt-nm app.elf

# 反汇编
xt-objdump -d app.elf

# 查看段信息
xt-readelf -S app.elf

# 性能分析
xt-gprof app.elf gmon.out
```

### B. 支持的 DSP 架构

| 厂商 | DSP 核心 | Cadence Core | 用途 |
|------|---------|--------------|------|
| NXP | Hifi 4 | hifi4_nxp | 音频处理 |
| Qualcomm | HVX | hexagon_v68 | 图像/AI |
| Espressif | ESP32-S3 | esp32s3 | IoT/Wi-Fi |
| Synopsys | ARC DSP | arc_dsp | 嵌入式 |

### C. 常用环境变量

| 变量名 | 作用 | 示例 |
|--------|------|------|
| `XTENSA_TOOLS_ROOT` | 工具链根目录 | `/opt/cadence/xtensa/XtDevTools` |
| `XTENSA_CORE` | DSP core 名称 | `hifi4_audio_dsp` |
| `LM_LICENSE_FILE` | 许可证配置 | `27000@license-server` |
| `XTENSA_SYSTEM` | 系统配置目录 | `${XTENSA_TOOLS_ROOT}/config/${XTENSA_CORE}` |

### D. 相关资源

- [eRPC 云端测试指南](CLOUD_TESTING.md)
- [Cadence 官方文档](https://www.cadence.com/en_US/home/tools/ip/tensilica-ip.html)
- [Docker 最佳实践](https://docs.docker.com/develop/dev-best-practices/)
- [FlexLM 管理指南](https://www.flexera.com/products/software-licensing/flexnet-manager.html)

---

## 总结

通过本指南，您应该能够：

1. ✅ 在 Docker 中搭建 Cadence DSP 编译环境
2. ✅ 配置许可证服务器（网络或文件）
3. ✅ 在云端 CI/CD 中集成 DSP 工具链
4. ✅ 设置团队共享的远程开发服务器
5. ✅ 解决常见的工具链和许可证问题

如有疑问，请查阅[故障排查](#故障排查)章节或联系团队管理员。

祝开发顺利！
