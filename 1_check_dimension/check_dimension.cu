#include <cuda_runtime.h>
#include <stdio.h>

// 核函数：每个线程打印自己的坐标和维度信息
__global__ void checkIndex(void)
{
  // threadIdx — 当前线程在 Block 中的位置
  // blockIdx  — 当前 Block 在 Grid 中的位置
  // blockDim  — 每个 Block 有多少线程
  // gridDim   — Grid 有多少个 Block
  printf("threadIdx:(%d,%d,%d) blockIdx:(%d,%d,%d) blockDim:(%d,%d,%d) gridDim(%d,%d,%d)\n",
  threadIdx.x,threadIdx.y,threadIdx.z,
  blockIdx.x,blockIdx.y,blockIdx.z,
  blockDim.x,blockDim.y,blockDim.z,
  gridDim.x,gridDim.y,gridDim.z);
}

int main(int argc,char **argv)
{
  int nElem=6;

  // dim3 在主机端配置线程组织形状，只传一个参数时 y/z 默认为 1
  dim3 block(3);                                                    // 每 Block 3 个线程
  dim3 grid((nElem+block.x-1)/block.x);                            // 向上取整算 Block 数：(6+3-1)/3 = 2

  printf("grid.x %d grid.y %d grid.z %d\n",grid.x,grid.y,grid.z);
  printf("block.x %d block.y %d block.z %d\n",block.x,block.y,block.z);

  // 启动 2 个 Block × 3 个 Thread = 6 个线程
  checkIndex<<<grid,block>>>();

  cudaDeviceReset();
  return 0;
}
