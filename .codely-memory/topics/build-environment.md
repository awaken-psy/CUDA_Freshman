# CUDA 构建环境

Last updated: 2026-07-29 15:38

## 概述

CUDA_Freshman 项目在 Windows 上的构建环境配置。项目使用 CMake + Ninja + MSVC + CUDA Toolkit 编译一系列 `.cu` CUDA 学习示例。

## 当前状态

- CUDA Toolkit 13.3.1 已安装（路径 `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.3`）
- 旧的 CUDA 12.1 仍存在但不再使用（PATH 已切到 v13.3）
- GPU: RTX 3060 Ti, compute capability 8.6 (sm_86)
- VS 2026 (v18) Community 已安装，MSVC 19.51 原生受 CUDA 13.3 支持
- 全部 37 个示例编译链接成功，已验证 hello_world.exe 可运行
- `build.bat` 脚本已创建，一行命令完成编译

## 关键知识

- **编译命令**: 在项目根目录运行 `build.bat`，或手动在 vcvarsall 环境中执行 `cmake --build build`
- **build.bat 做了什么**: 调用 `vcvarsall.bat x64` → 进入 build 目录 → 首次运行 `cmake -G Ninja -DCMAKE_BUILD_TYPE=Release` → `cmake --build .`
- **Strawberry Perl 干扰**: 系统中 Strawberry Perl 自带 GCC 和 Ninja，若不在 vcvarsall 环境中运行，CMake 会捡到 GCC 导致 nvcc 找不到 cl.exe
- **CMake 构建类型必须用 Release**: CMakeLists.txt 中的 `-O3` 与 Debug 模式的 `/RTC1 /Od` 冲突
- **运行示例**: `./build/0_hello_world/hello_world.exe`，部分示例支持传参如 `./build/10_reduceInteger/reduceInteger.exe 512`

## 待办/下一步

- 若新增示例，在 CMakeLists.txt 中 `add_subdirectory(新目录)` 并在新目录中创建单行 CMakeLists.txt
