# eRPC 云端编译测试指南

本文档介绍如何在云端环境编译和测试嵌入式 eRPC 代码。

## 📋 目录

- [云端测试方案概览](#云端测试方案概览)
- [方案 1：GitHub Actions (推荐)](#方案-1github-actions-推荐)
- [方案 2：Docker 容器化测试](#方案-2docker-容器化测试)
- [方案 3：CircleCI](#方案-3circleci)
- [方案 4：其他云平台](#方案-4其他云平台)
- [常见问题](#常见问题)

---

## 云端测试方案概览

eRPC 项目支持多种云端编译测试方式：

| 方案 | 优势 | 适用场景 |
|------|------|----------|
| **GitHub Actions** | 免费、易配置、与 GitHub 集成 | 开源项目、个人开发 |
| **Docker** | 跨平台、环境一致性 | 本地测试、CI/CD |
| **CircleCI** | 已配置、多平台支持 | 生产环境 CI/CD |
| **其他云平台** | Jenkins、GitLab CI、Azure Pipelines | 企业环境 |

---

## 方案 1：GitHub Actions (推荐)

### 功能特点

- ✅ 自动化 CI/CD 流程
- ✅ 支持 Linux (GCC/Clang)、macOS、Windows
- ✅ Docker 容器化测试
- ✅ 代码覆盖率分析
- ✅ 构建产物自动上传

### 使用方法

#### 1. 启用 GitHub Actions

工作流文件位置：`.github/workflows/build-and-test.yml`

每次 push 或 PR 时自动触发，也可以手动触发：

```bash
# 在 GitHub 仓库页面
Actions → Build and Test eRPC → Run workflow
```

#### 2. 查看测试结果

访问仓库的 **Actions** 标签页查看：
- 编译日志
- 测试结果
- 下载构建产物（erpcgen 二进制文件）

#### 3. 触发条件

以下情况会自动触发测试：
- 推送到 `main`、`develop` 分支
- 推送到 `claude/**` 分支
- 创建 Pull Request

---

## 方案 2：Docker 容器化测试

### 快速开始

#### 安装 Docker

```bash
# Linux
sudo apt-get install docker.io docker-compose

# macOS
brew install docker docker-compose

# Windows
# 下载并安装 Docker Desktop
```

#### 基础用法

```bash
# 1. 构建 Docker 镜像
docker build -t erpc-test .

# 2. 运行完整测试
docker run --rm erpc-test

# 3. 仅编译项目
docker run --rm erpc-test make all

# 4. 指定编译器测试
docker run --rm erpc-test python3 test/run_unit_tests.py gcc
```

#### 使用 Docker Compose (推荐)

```bash
# 1. 运行所有测试（GCC + Clang）
docker-compose up erpc-test-gcc erpc-test-clang

# 2. 仅编译
docker-compose up erpc-build-only

# 3. 进入交互式开发环境
docker-compose run erpc-dev

# 4. 运行 Python 测试
docker-compose up erpc-pytest

# 5. 清理容器和缓存
docker-compose down -v
```

### Docker 容器配置

**支持的测试环境：**

| 服务名 | 编译器 | 用途 |
|--------|--------|------|
| `erpc-test-gcc` | GCC | 完整测试套件 |
| `erpc-test-clang` | Clang | 完整测试套件 |
| `erpc-build-only` | GCC | 仅编译 |
| `erpc-dev` | GCC | 交互式开发 |
| `erpc-pytest` | N/A | Python 测试 |

---

## 方案 3：CircleCI

### 当前配置

项目已配置 CircleCI，位于 `.circleci/config.yml`

**测试矩阵：**
- Linux (Ubuntu 22.04) - GCC / Clang
- macOS (Xcode 12.5.1) - GCC / Clang
- Windows - MinGW / Visual Studio

### 查看测试结果

访问 CircleCI 仪表板：
```
https://app.circleci.com/pipelines/github/<username>/erpc
```

### 本地运行 CircleCI 测试

```bash
# 安装 CircleCI CLI
curl -fLSs https://circle.ci/cli | bash

# 验证配置文件
circleci config validate

# 本地运行任务
circleci local execute --job build-linux-gcc
```

---

## 方案 4：其他云平台

### GitLab CI

创建 `.gitlab-ci.yml`：

```yaml
stages:
  - build
  - test

build_erpc:
  stage: build
  image: ubuntu:22.04
  script:
    - apt-get update && apt-get install -y gcc g++ make bison flex python3 python3-pip
    - pip3 install pytest pyyaml
    - make clean && make all
  artifacts:
    paths:
      - Release/

test_erpc:
  stage: test
  image: ubuntu:22.04
  script:
    - apt-get update && apt-get install -y gcc g++ python3 python3-pip
    - pip3 install pytest pyyaml
    - python3 test/run_unit_tests.py gcc
```

### Jenkins

创建 `Jenkinsfile`：

```groovy
pipeline {
    agent any

    stages {
        stage('Install Dependencies') {
            steps {
                sh './install_dependencies.sh'
            }
        }

        stage('Build') {
            steps {
                sh 'make clean && make all'
            }
        }

        stage('Test') {
            steps {
                sh 'python3 test/run_unit_tests.py gcc'
                sh 'pytest erpcgen/test/'
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'Release/**/erpcgen', allowEmptyArchive: true
        }
    }
}
```

### Azure Pipelines

创建 `azure-pipelines.yml`：

```yaml
trigger:
  - main
  - develop

pool:
  vmImage: 'ubuntu-22.04'

steps:
- script: |
    chmod +x install_dependencies.sh
    ./install_dependencies.sh
  displayName: 'Install dependencies'

- script: |
    make clean && make all
  displayName: 'Build eRPC'

- script: |
    python3 test/run_unit_tests.py gcc
  displayName: 'Run tests'

- task: PublishBuildArtifacts@1
  inputs:
    pathToPublish: 'Release'
    artifactName: 'erpc-binaries'
```

---

## 本地快速测试

### Linux / macOS

```bash
# 1. 安装依赖
./install_dependencies.sh

# 2. 编译项目
make clean && make all

# 3. 运行完整测试
./run_tests.sh

# 4. 仅运行单元测试
python3 test/run_unit_tests.py

# 5. 测试特定传输层
python3 test/run_unit_tests.py --transport tcp
python3 test/run_unit_tests.py --transport serial

# 6. 测试不同客户端/服务器组合
python3 test/run_unit_tests.py --client c --server python
python3 test/run_unit_tests.py --client python --server java
```

### Windows

```powershell
# 1. 安装依赖
.\install_dependencies.ps1

# 2. 编译项目（MinGW）
.\mingw64\bin\mingw32-make all

# 3. 运行测试
.\mingw64\opt\bin\python3.exe .\test\run_unit_tests.py
```

---

## 测试配置选项

### 环境变量

```bash
# 指定编译器
export CC=gcc
export CXX=g++

# 或使用 Clang
export CC=clang
export CXX=clang++

# 指定安装路径
export PREFIX=/usr/local
```

### CMake 构建

```bash
# 使用 CMake + KConfig
cmake -B ./build
cmake --build ./build --target menuconfig  # 配置选项
cmake --build ./build

# 启用测试
cmake -B ./build -DCONFIG_ERPC_TESTS=ON
cmake --build ./build
ctest --test-dir ./build
```

---

## 常见问题

### Q1: Docker 构建失败，提示权限错误

**解决方法：**
```bash
# Linux 用户需要添加到 docker 组
sudo usermod -aG docker $USER
# 重新登录生效

# 或使用 sudo
sudo docker build -t erpc-test .
```

### Q2: 测试超时或失败

**解决方法：**
```bash
# 1. 检查端口是否被占用（TCP 测试使用端口 12345）
netstat -tuln | grep 12345

# 2. 单独运行失败的测试
cd test/test_<name>
make clean && make
./test_<name>_client &
./test_<name>_server

# 3. 查看详细日志
python3 test/run_unit_tests.py gcc -v
```

### Q3: 如何在云端测试嵌入式目标平台？

**解决方法：**

eRPC 支持多种嵌入式平台，但直接在云端测试需要硬件仿真：

1. **使用 QEMU 仿真：**
   ```bash
   # 安装 QEMU
   sudo apt-get install qemu-system-arm

   # 示例：Zephyr OS 测试
   # 参考 test/zephyr/README.rst
   ```

2. **远程硬件测试：**
   - 使用远程实验室（如 NXP MCUXpresso Cloud）
   - 配置远程调试（OpenOCD + GDB Server）

3. **主机端测试：**
   ```bash
   # 测试 C/C++ 和 Python/Java 互操作
   python3 test/run_unit_tests.py --client c --server python
   ```

### Q4: 如何添加自定义测试？

**步骤：**

1. 在 `test/` 目录创建新测试目录
2. 添加 `.erpc` IDL 文件
3. 实现客户端和服务器代码
4. 创建 `Makefile` 或 `CMakeLists.txt`
5. 运行 `erpcgen` 生成代码

**示例：**
```bash
cd test
mkdir test_my_feature
cd test_my_feature

# 创建 IDL
cat > my_feature.erpc << 'EOF'
interface MyService {
    add(int32 a, int32 b) -> int32
}
EOF

# 生成代码
../../Release/Linux/erpcgen/erpcgen my_feature.erpc

# 实现客户端/服务器
# ... 编写代码 ...

# 测试
make && ./test_my_feature_client &
./test_my_feature_server
```

---

## 性能优化建议

### Docker 构建优化

```dockerfile
# 使用多阶段构建减小镜像大小
FROM ubuntu:22.04 AS builder
# ... 构建步骤 ...

FROM ubuntu:22.04
COPY --from=builder /erpc/Release /erpc/Release
# ... 仅复制必要文件 ...
```

### CI/CD 优化

```yaml
# GitHub Actions: 使用缓存加速构建
- name: Cache build artifacts
  uses: actions/cache@v3
  with:
    path: |
      Release
      ~/.cache/pip
    key: ${{ runner.os }}-build-${{ hashFiles('**/Makefile') }}
```

---

## 相关链接

- [eRPC 官方文档](https://github.com/EmbeddedRPC/erpc)
- [测试框架说明](test/README.md)
- [Zephyr 测试指南](test/zephyr/README.rst)
- [Python 测试文档](test/python_impl_tests/README.md)
- [Java 测试文档](test/java_impl_tests/readme.md)

---

## 贡献

欢迎提交 Pull Request 改进云端测试流程！

测试相关问题请在 [GitHub Issues](https://github.com/EmbeddedRPC/erpc/issues) 反馈。
