# CODELY.md

## Project Overview

**CUDA_Freshman** is a collection of CUDA learning programs organized as a series of progressively advanced examples. The project accompanies a Chinese-language CUDA tutorial series published at [www.face2ai.com](http://www.face2ai.com). Many examples are drawn from the book *"Professional CUDA C Programming"*, while others were authored by the project owner.

The repository covers the full spectrum of foundational CUDA topics:

| Directory Range | Topic |
|---|---|
| `0`–`2` | CUDA programming model basics (hello world, grid/block, dimensions) |
| `3`–`9` | Array/matrix sum kernels, device info, thread indexing, 2D matrices |
| `10`–`12` | Parallel reduction (neighbored, interleaved, unrolling) |
| `13`–`14` | Dynamic parallelism (nested kernels), global variables |
| `15`–`17` | Pinned memory, zero-copy memory, Unified Virtual Addressing (UVA) |
| `18`–`21` | Array sum with offset, AoS vs SoA, unrolling with offset |
| `22`–`26` | Shared memory: matrix transforms, data loading, reduction |
| `27` | Stencil 1D with constant/read-only memory |
| `28`–`29` | Warp shuffle instructions (`__shfl`) and shuffle-based reduction |
| `30`–`38` | CUDA streams, events, concurrency, async API, stream callbacks |

Each numbered directory is a self-contained, standalone executable demonstrating one concept.

## Build System

- **Build tool:** CMake (≥ 3.9), with native CUDA language support (`project(... CXX C CUDA)`)
- **CUDA flags:** `-arch=compute_35 -g -G -O3` (target architecture: compute capability 3.5, debug + optimization)
- **Include path:** `./include` (shared header `freshman.h`)

### Building

```bash
mkdir build && cd build
cmake ..
make        # Linux/macOS
# or: cmake --build .   # cross-platform
```

### Running an Example

Each subdirectory compiles to an executable named after its `.cu` file. Run from the `build` directory:

```bash
./hello_world
./sum_arrays
./reduceInteger
# etc.
```

Some executables accept command-line arguments (e.g., `./reduceInteger 512` to set block size).

## Project Structure

```
CUDA_Freshman/
├── CMakeLists.txt          # Top-level CMake — adds all subdirectories
├── include/
│   └── freshman.h          # Shared utility header (error checking, timing, init, etc.)
├── 0_hello_world/          # Each numbered dir contains:
│   ├── CMakeLists.txt      #   A one-line add_executable()
│   └── hello_world.cu      #   The .cu source file
├── 1_check_dimension/
├── ...
└── 38_stream_call_back/
```

### Per-Directory CMakeLists Pattern

Every example directory has a minimal `CMakeLists.txt` with a single line:

```cmake
add_executable(<name> <name>.cu)
```

No per-directory flags or includes are needed — the top-level `CMakeLists.txt` sets global CUDA flags and include paths.

## Development Conventions

### Coding Style

- **Language:** CUDA C/C++ (`.cu` files)
- **Includes:** Each `.cu` file typically includes `<cuda_runtime.h>`, `<stdio.h>`, and `"freshman.h"`
- **Error handling:** All CUDA runtime API calls are wrapped in the `CHECK()` macro (defined in `freshman.h`), which prints the file, line, error code, and reason on failure, then exits
- **GPU timing:** Uses `cpuSecond()` from `freshman.h` for wall-clock timing around kernel launches (host-side `cudaDeviceSynchronize()` + timestamp); some examples use `cudaEvent`-based timing for stream examples
- **Result verification:** CPU and GPU results are compared via `checkResult()` with an epsilon of `1.0E-8`
- **Memory pattern:** `malloc`/`cudaMalloc` → `initialData` → `cudaMemcpy` H2D → kernel launch → `cudaMemcpy` D2H → `checkResult` → `free`/`cudaFree`
- **Naming:** `*_h` suffix for host pointers, `*_d` suffix for device pointers (e.g., `a_h`, `a_d`); kernel functions use `camelCase` or `snake_case` with a `GPU` suffix (e.g., `sumArraysGPU`)
- **Kernel launch config:** Typically `dim3 block(1024)` with grid computed as `(nElem - 1) / block.x + 1`
- **Comments:** Inline comments explain the "why" of CUDA-specific operations (e.g., `cudaDeviceReset()` necessity, stride calculations)
- **Platform:** Cross-platform aware — `freshman.h` provides a `gettimeofday()` shim for Windows

### Shared Utility Header (`freshman.h`)

| Function/Macro | Purpose |
|---|---|
| `CHECK(call)` | Wraps CUDA API calls; asserts success |
| `cpuSecond()` | Returns current time in seconds (for host-side timing) |
| `initialData(float*, int)` | Fills float array with random data |
| `initialData_int(int*, int)` | Fills int array with random data |
| `printMatrix(float*, int, int)` | Prints a 2D matrix |
| `initDevice(int)` | Selects and initializes a CUDA device |
| `checkResult(float*, float*, int)` | Compares host vs. GPU results with epsilon |

### Adding a New Example

1. Create a new numbered directory (e.g., `39_my_example/`)
2. Add a `.cu` source file
3. Add a `CMakeLists.txt` with: `add_executable(my_example my_example.cu)`
4. Add `add_subdirectory(39_my_example)` to the top-level `CMakeLists.txt`
5. Include `"freshman.h"` for utilities and `CHECK()` macro
