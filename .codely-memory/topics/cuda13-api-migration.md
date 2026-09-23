# CUDA 13 API 迁移

Last updated: 2026-07-29 15:38

## 概述

将 CUDA_Freshman 项目源码从 CUDA 12.1 适配到 CUDA 13.3 的 API 变更记录。CUDA 13.0 移除了多个废弃 API，需要修改源码才能编译。

## 当前状态

- 全部 5 个有兼容性问题的文件已修复并编译通过
- 修复方式均为直接改用新 API，不使用兼容性绕行

## 关键知识

- **`__shfl` 系列 → `__shfl_sync` 系列**: CUDA 12+ 要求所有 warp shuffle 函数带 mask 参数。`__shfl(val, src, width)` → `__shfl_sync(0xFFFFFFFF, val, src, width)`，同理 `__shfl_up`/`__shfl_down`/`__shfl_xor`
- **`cudaDeviceProp.clockRate` 被移除**: CUDA 13 从 struct 中移除了 `clockRate`、`memoryClockRate`、`deviceOverlap`、`computeMode` 等字段。替代方式: `cudaDeviceGetAttribute(&val, cudaDevAttrClockRate, dev)`
- **`setenv()` → `_putenv_s()`**: POSIX 函数在 Windows MSVC 下不存在，用 `_putenv_s(name, value)` 替代
- **`compute_35` → `sm_86`**: CUDA 12+ 移除 Kepler 架构支持。用 `sm_XX` (指定具体 GPU) 而非 `compute_XX` (虚拟架构) 可避免 PTX JIT 开销

## 待办/下一步

- 后续如遇 CUDA 13 其他 API 变更（如 `cudaMemAdvise`/`cudaMemPrefetchAsync` 参数变更），参考 NVIDIA 官方迁移指南
