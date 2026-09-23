#include <cuda_runtime.h>
#include <stdio.h>

int main(int argc,char ** argv)
{
  int nElem=1024;

  // 演示：相同数据量，用不同的 Block 大小划分，观察 Grid 数量的变化
  // 公式 (nElem-1)/block.x+1 等价于向上取整 ceil(nElem / block.x)

  dim3 block(1024);
  dim3 grid((nElem-1)/block.x+1);
  printf("grid.x %d block.x %d\n",grid.x,block.x);

  block.x=512;
  grid.x=(nElem-1)/block.x+1;
  printf("grid.x %d block.x %d\n",grid.x,block.x);

  block.x=256;
  grid.x=(nElem-1)/block.x+1;
  printf("grid.x %d block.x %d\n",grid.x,block.x);

  block.x=128;
  grid.x=(nElem-1)/block.x+1;
  printf("grid.x %d block.x %d\n",grid.x,block.x);

  cudaDeviceReset();
  return 0;
}
