#include<stdio.h>

// __global__ 修饰符表示该函数由 CPU 调用、在 GPU 上执行（即 kernel 函数）
__global__ void hello_world(void)
{
  // kernel 内的 printf 由每个 GPU 线程各自执行
  printf("GPU: Hello world!\n");
}

int main(int argc,char **argv)
{
  printf("CPU: Hello world!\n");

  // <<<gridDim, blockDim>>> 配置 kernel 启动参数
  // 1 个 block，每 block 10 个线程 → 共启动 10 个 GPU 线程
  hello_world<<<1,10>>>();

  // cudaDeviceReset 销毁当前设备上的所有 CUDA 上下文
  // GPU 的 printf 输出是异步的，需要在此处同步刷新才能在终端看到结果
  cudaDeviceReset();//if no this line ,it can not output hello world from gpu
  return 0;
}
