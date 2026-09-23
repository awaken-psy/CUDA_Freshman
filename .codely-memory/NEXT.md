> 记忆路径: C:\Users\chang.wei\cw\CUDA_Freshman\.codely-memory\

# Next Session

Updated: 2026-07-29 15:38

## 上次做了什么

将 CUDA_Freshman 项目从 CUDA 12.1 迁移到 CUDA 13.3，修复了 5 个文件的 API 兼容性问题（`__shfl` → `__shfl_sync`、`clockRate` → `cudaDeviceGetAttribute`、`setenv` → `_putenv_s`、`compute_35` → `sm_86`），创建了 build.bat 编译脚本和 CODELY.md 项目文档，配置了 Git 远程仓库（fork 到 awaken-psy/CUDA_Freshman）。全部 37 个示例编译通过并验证可运行。

## 从这里继续

项目已完全可用。下一步可以：
1. 开始学习 CUDA 示例（按编号顺序从 0 到 38）
2. 修改/添加自己的 CUDA 示例
3. 将改动 push 到自己的 fork 仓库

## 未完成

- 无

## 注意事项

- 编译必须通过 `build.bat` 或在 `vcvarsall.bat x64` 环境中运行，否则 CMake 会捡到 Strawberry Perl 的 GCC
- CMakeLists.txt 中 `-O3` 与 CMake Debug 模式冲突，必须用 `-DCMAKE_BUILD_TYPE=Release`
- 系统 PATH 中 CUDA 路径已从 v12.1 改为 v13.3，但旧版仍保留在磁盘上

## 相关文件

- `CMakeLists.txt` — 顶层 CMake 配置，GPU 架构 sm_86
- `build.bat` — 一键编译脚本
- `include/freshman.h` — 共享工具头文件（CHECK 宏、计时、初始化等）
- `CODELY.md` — 项目说明文档
