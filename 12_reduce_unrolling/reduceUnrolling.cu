#include <cuda_runtime.h>
#include <stdio.h>
#include "freshman.h"

// CPU 递归归约（用于验证 GPU 结果）
int recursiveReduce(int *data, int const size)
{
	if (size == 1) return data[0];
	int const stride = size / 2;
	if (size % 2 == 1)
	{
		for (int i = 0; i < stride; i++)
			data[i] += data[i + stride];
		data[0] += data[size - 1];  // 奇数个元素，最后一个单独处理
	}
	else
	{
		for (int i = 0; i < stride; i++)
			data[i] += data[i + stride];
	}
	return recursiveReduce(data, stride);
}


// warmup：原始相邻配对归约，用于预热 GPU（消除首次启动开销）
__global__ void warmup(int * g_idata, int * g_odata, unsigned int n)
{
	unsigned int tid = threadIdx.x;
	if (tid >= n) return;
	int *idata = g_idata + blockIdx.x * blockDim.x;

	for (int stride = 1; stride < blockDim.x; stride *= 2)
	{
		if ((tid % (2 * stride)) == 0)
			idata[tid] += idata[tid + stride];
		__syncthreads();
	}
	if (tid == 0) g_odata[blockIdx.x] = idata[0];
}


// 展开因子 2：每个 Block 处理 2 倍数据，减少一半 Block 数量
// 先把相邻两段数据合并到一段，再做常规归约
__global__ void reduceUnroll2(int * g_idata, int * g_odata, unsigned int n)
{
	unsigned int tid = threadIdx.x;
	// blockIdx.x * blockDim.x * 2：每个 Block 负责的起始位置间隔 2 倍 Block 大小
	unsigned int idx = blockDim.x * blockIdx.x * 2 + threadIdx.x;
	if (tid >= n) return;
	int *idata = g_idata + blockIdx.x * blockDim.x * 2;

	// 第一阶段：把每 Block 的第二段数据加到第一段，相当于先做了一轮 Block 间归约
	if (idx + blockDim.x < n)
		g_idata[idx] += g_idata[idx + blockDim.x];
	__syncthreads();

	// 第二阶段：Block 内做交错配对归约
	for (int stride = blockDim.x / 2; stride > 0; stride >>= 1)
	{
		if (tid < stride)
			idata[tid] += idata[tid + stride];
		__syncthreads();
	}
	if (tid == 0) g_odata[blockIdx.x] = idata[0];
}


// 展开因子 4：每个 Block 处理 4 倍数据，Block 数量减为 1/4
__global__ void reduceUnroll4(int * g_idata, int * g_odata, unsigned int n)
{
	unsigned int tid = threadIdx.x;
	unsigned int idx = blockDim.x * blockIdx.x * 4 + threadIdx.x;
	if (tid >= n) return;
	int *idata = g_idata + blockIdx.x * blockDim.x * 4;

	// 第一阶段：把 4 段数据合并到第一段
	if (idx + blockDim.x < n)
	{
		g_idata[idx] += g_idata[idx + blockDim.x];
		g_idata[idx] += g_idata[idx + blockDim.x * 2];
		g_idata[idx] += g_idata[idx + blockDim.x * 3];
	}
	__syncthreads();

	// 第二阶段：Block 内交错配对归约
	for (int stride = blockDim.x / 2; stride > 0; stride >>= 1)
	{
		if (tid < stride)
			idata[tid] += idata[tid + stride];
		__syncthreads();
	}
	if (tid == 0) g_odata[blockIdx.x] = idata[0];
}


// 展开因子 8：每个 Block 处理 8 倍数据，Block 数量减为 1/8
__global__ void reduceUnroll8(int * g_idata, int * g_odata, unsigned int n)
{
	unsigned int tid = threadIdx.x;
	unsigned int idx = blockDim.x * blockIdx.x * 8 + threadIdx.x;
	if (tid >= n) return;
	int *idata = g_idata + blockIdx.x * blockDim.x * 8;

	// 第一阶段：把 8 段数据合并到第一段
	if (idx + blockDim.x < n)
	{
		g_idata[idx] += g_idata[idx + blockDim.x];
		g_idata[idx] += g_idata[idx + blockDim.x * 2];
		g_idata[idx] += g_idata[idx + blockDim.x * 3];
		g_idata[idx] += g_idata[idx + blockDim.x * 4];
		g_idata[idx] += g_idata[idx + blockDim.x * 5];
		g_idata[idx] += g_idata[idx + blockDim.x * 6];
		g_idata[idx] += g_idata[idx + blockDim.x * 7];
	}
	__syncthreads();

	// 第二阶段：Block 内交错配对归约
	for (int stride = blockDim.x / 2; stride > 0; stride >>= 1)
	{
		if (tid < stride)
			idata[tid] += idata[tid + stride];
		__syncthreads();
	}
	if (tid == 0) g_odata[blockIdx.x] = idata[0];
}


// 展开因子 8 + 展开最后一个 Warp
// 当 stride 降到 32（一个 Warp 大小）时，手动展开归约，省掉循环和 __syncthreads
__global__ void reduceUnrollWarp8(int * g_idata, int * g_odata, unsigned int n)
{
	unsigned int tid = threadIdx.x;
	unsigned int idx = blockDim.x * blockIdx.x * 8 + threadIdx.x;
	if (tid >= n) return;
	int *idata = g_idata + blockIdx.x * blockDim.x * 8;

	// 第一阶段：把 8 段数据合并到第一段（用局部变量避免反复读写全局内存）
	if (idx + 7 * blockDim.x < n)
	{
		int a1 = g_idata[idx];
		int a2 = g_idata[idx + blockDim.x];
		int a3 = g_idata[idx + 2 * blockDim.x];
		int a4 = g_idata[idx + 3 * blockDim.x];
		int a5 = g_idata[idx + 4 * blockDim.x];
		int a6 = g_idata[idx + 5 * blockDim.x];
		int a7 = g_idata[idx + 6 * blockDim.x];
		int a8 = g_idata[idx + 7 * blockDim.x];
		g_idata[idx] = a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8;
	}
	__syncthreads();

	// 第二阶段：Block 内归约，循环到 stride > 32 时停止
	// 不再继续循环到最后，因为最后 5 轮（32→16→8→4→2→1）全部在一个 Warp 内
	for (int stride = blockDim.x / 2; stride > 32; stride >>= 1)
	{
		if (tid < stride)
			idata[tid] += idata[tid + stride];
		__syncthreads();
	}

	// 第三阶段：手动展开最后一个 Warp 的归约（stride=32→16→8→4→2→1）
	// 一个 Warp 内的线程本身就是同步的（SIMT），不需要 __syncthreads
	// volatile 防止编译器把中间结果缓存在寄存器里，强制每次都读内存
	if (tid < 32)
	{
		volatile int *vmem = idata;
		vmem[tid] += vmem[tid + 32];
		vmem[tid] += vmem[tid + 16];
		vmem[tid] += vmem[tid + 8];
		vmem[tid] += vmem[tid + 4];
		vmem[tid] += vmem[tid + 2];
		vmem[tid] += vmem[tid + 1];
	}

	if (tid == 0) g_odata[blockIdx.x] = idata[0];
}


// 展开因子 8 + 展开最后一个 Warp + 完全展开循环
// 把 for 循环拆成手写的 if 判断，编译器可以更好地优化
__global__ void reduceCompleteUnrollWarp8(int * g_idata, int * g_odata, unsigned int n)
{
	unsigned int tid = threadIdx.x;
	unsigned int idx = blockDim.x * blockIdx.x * 8 + threadIdx.x;
	if (tid >= n) return;
	int *idata = g_idata + blockIdx.x * blockDim.x * 8;

	// 第一阶段：8 段数据合并
	if (idx + 7 * blockDim.x < n)
	{
		int a1 = g_idata[idx];
		int a2 = g_idata[idx + blockDim.x];
		int a3 = g_idata[idx + 2 * blockDim.x];
		int a4 = g_idata[idx + 3 * blockDim.x];
		int a5 = g_idata[idx + 4 * blockDim.x];
		int a6 = g_idata[idx + 5 * blockDim.x];
		int a7 = g_idata[idx + 6 * blockDim.x];
		int a8 = g_idata[idx + 7 * blockDim.x];
		g_idata[idx] = a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8;
	}
	__syncthreads();

	// 第二阶段：完全展开归约循环（手动写每一轮，消除 for 循环开销）
	// 编译器在编译期就知道每轮的 stride，可以更好地优化指令调度
	if (blockDim.x >= 1024 && tid < 512) idata[tid] += idata[tid + 512];
	__syncthreads();
	if (blockDim.x >= 512  && tid < 256) idata[tid] += idata[tid + 256];
	__syncthreads();
	if (blockDim.x >= 256  && tid < 128) idata[tid] += idata[tid + 128];
	__syncthreads();
	if (blockDim.x >= 128  && tid < 64)  idata[tid] += idata[tid + 64];
	__syncthreads();

	// 第三阶段：最后一个 Warp 的手动展开
	if (tid < 32)
	{
		volatile int *vmem = idata;
		vmem[tid] += vmem[tid + 32];
		vmem[tid] += vmem[tid + 16];
		vmem[tid] += vmem[tid + 8];
		vmem[tid] += vmem[tid + 4];
		vmem[tid] += vmem[tid + 2];
		vmem[tid] += vmem[tid + 1];
	}

	if (tid == 0) g_odata[blockIdx.x] = idata[0];
}

// 模板版本：编译期确定 Block 大小，消除运行时 if 分支
// 编译器知道 iBlockSize 是常量，可以直接裁剪掉不可能的分支
template <unsigned int iBlockSize>
__global__ void reduceCompleteUnroll(int * g_idata, int * g_odata, unsigned int n)
{
	unsigned int tid = threadIdx.x;
	unsigned int idx = blockDim.x * blockIdx.x * 8 + threadIdx.x;
	if (tid >= n) return;
	int *idata = g_idata + blockIdx.x * blockDim.x * 8;

	// 第一阶段：8 段数据合并
	if (idx + 7 * blockDim.x < n)
	{
		int a1 = g_idata[idx];
		int a2 = g_idata[idx + blockDim.x];
		int a3 = g_idata[idx + 2 * blockDim.x];
		int a4 = g_idata[idx + 3 * blockDim.x];
		int a5 = g_idata[idx + 4 * blockDim.x];
		int a6 = g_idata[idx + 5 * blockDim.x];
		int a7 = g_idata[idx + 6 * blockDim.x];
		int a8 = g_idata[idx + 7 * blockDim.x];
		g_idata[idx] = a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8;
	}
	__syncthreads();

	// 第二阶段：编译期常量 iBlockSize，编译器裁剪不可能的分支
	if (iBlockSize >= 1024 && tid < 512) idata[tid] += idata[tid + 512];
	__syncthreads();
	if (iBlockSize >= 512  && tid < 256) idata[tid] += idata[tid + 256];
	__syncthreads();
	if (iBlockSize >= 256  && tid < 128) idata[tid] += idata[tid + 128];
	__syncthreads();
	if (iBlockSize >= 128  && tid < 64)  idata[tid] += idata[tid + 64];
	__syncthreads();

	// 第三阶段：最后一个 Warp 的手动展开
	if (tid < 32)
	{
		volatile int *vmem = idata;
		vmem[tid] += vmem[tid + 32];
		vmem[tid] += vmem[tid + 16];
		vmem[tid] += vmem[tid + 8];
		vmem[tid] += vmem[tid + 4];
		vmem[tid] += vmem[tid + 2];
		vmem[tid] += vmem[tid + 1];
	}

	if (tid == 0) g_odata[blockIdx.x] = idata[0];
}

int main(int argc, char **argv)
{
	initDevice(0);

	int size = 1 << 24;  // 1600 万元素
	printf("  with array size %d  ", size);

	// 执行配置
	int blocksize = 1024;
	if (argc > 1) blocksize = atoi(argv[1]);
	dim3 block(blocksize, 1);
	dim3 grid((size - 1) / block.x + 1, 1);
	printf("grid %d block %d \n", grid.x, block.x);

	// 主机端内存分配
	size_t bytes = size * sizeof(int);
	int *idata_host = (int *)malloc(bytes);
	int *odata_host = (int *)malloc(grid.x * sizeof(int));
	int *tmp = (int *)malloc(bytes);

	initialData_int(idata_host, size);
	memcpy(tmp, idata_host, bytes);

	double iStart, iElaps;
	int gpu_sum = 0;

	// 设备端显存分配
	int *idata_dev = NULL;
	int *odata_dev = NULL;
	CHECK(cudaMalloc((void **)&idata_dev, bytes));
	CHECK(cudaMalloc((void **)&odata_dev, grid.x * sizeof(int)));

	// CPU 归约（基准）
	int cpu_sum = 0;
	iStart = cpuSecond();
	for (int i = 0; i < size; i++)
		cpu_sum += tmp[i];
	iElaps = cpuSecond() - iStart;
	printf("cpu reduce                  elapsed %lf ms cpu_sum: %d\n", iElaps, cpu_sum);

	// kernel 0: warmup（消除首次启动 GPU 的开销）
	CHECK(cudaMemcpy(idata_dev, idata_host, bytes, cudaMemcpyHostToDevice));
	CHECK(cudaDeviceSynchronize());
	iStart = cpuSecond();
	warmup <<<grid.x / 2, block>>>(idata_dev, odata_dev, size);
	cudaDeviceSynchronize();
	iElaps = cpuSecond() - iStart;
	printf("gpu warmup                  elapsed %lf ms \n", iElaps);


	// kernel 1: reduceUnroll2（展开因子 2，Block 数减半）
	CHECK(cudaMemcpy(idata_dev, idata_host, bytes, cudaMemcpyHostToDevice));
	CHECK(cudaDeviceSynchronize());
	iStart = cpuSecond();
	reduceUnroll2 <<<grid.x / 2, block>>>(idata_dev, odata_dev, size);
	cudaDeviceSynchronize();
	iElaps = cpuSecond() - iStart;
	cudaMemcpy(odata_host, odata_dev, grid.x * sizeof(int), cudaMemcpyDeviceToHost);
	gpu_sum = 0;
	for (int i = 0; i < grid.x / 2; i++)
		gpu_sum += odata_host[i];
	printf("reduceUnrolling2            elapsed %lf ms gpu_sum: %d<<<grid %d block %d>>>\n",
		iElaps, gpu_sum, grid.x / 2, block.x);


	// kernel 2: reduceUnroll4（展开因子 4，Block 数减为 1/4）
	CHECK(cudaMemcpy(idata_dev, idata_host, bytes, cudaMemcpyHostToDevice));
	CHECK(cudaDeviceSynchronize());
	iStart = cpuSecond();
	reduceUnroll4 <<<grid.x / 4, block>>>(idata_dev, odata_dev, size);
	cudaDeviceSynchronize();
	iElaps = cpuSecond() - iStart;
	cudaMemcpy(odata_host, odata_dev, grid.x * sizeof(int), cudaMemcpyDeviceToHost);
	gpu_sum = 0;
	for (int i = 0; i < grid.x / 4; i++)
		gpu_sum += odata_host[i];
	printf("reduceUnrolling4            elapsed %lf ms gpu_sum: %d<<<grid %d block %d>>>\n",
		iElaps, gpu_sum, grid.x / 4, block.x);


	// kernel 3: reduceUnroll8（展开因子 8，Block 数减为 1/8）
	CHECK(cudaMemcpy(idata_dev, idata_host, bytes, cudaMemcpyHostToDevice));
	CHECK(cudaDeviceSynchronize());
	iStart = cpuSecond();
	reduceUnroll8 <<<grid.x / 8, block>>>(idata_dev, odata_dev, size);
	cudaDeviceSynchronize();
	iElaps = cpuSecond() - iStart;
	cudaMemcpy(odata_host, odata_dev, grid.x * sizeof(int), cudaMemcpyDeviceToHost);
	gpu_sum = 0;
	for (int i = 0; i < grid.x / 8; i++)
		gpu_sum += odata_host[i];
	printf("reduceUnrolling8            elapsed %lf ms gpu_sum: %d<<<grid %d block %d>>>\n",
		iElaps, gpu_sum, grid.x / 8, block.x);


	// kernel 4: reduceUnrollWarp8（展开 8 + 展开最后 Warp）
	CHECK(cudaMemcpy(idata_dev, idata_host, bytes, cudaMemcpyHostToDevice));
	CHECK(cudaDeviceSynchronize());
	iStart = cpuSecond();
	reduceUnrollWarp8 <<<grid.x / 8, block>>>(idata_dev, odata_dev, size);
	cudaDeviceSynchronize();
	iElaps = cpuSecond() - iStart;
	cudaMemcpy(odata_host, odata_dev, grid.x * sizeof(int), cudaMemcpyDeviceToHost);
	gpu_sum = 0;
	for (int i = 0; i < grid.x / 8; i++)
		gpu_sum += odata_host[i];
	printf("reduceUnrollingWarp8        elapsed %lf ms gpu_sum: %d<<<grid %d block %d>>>\n",
		iElaps, gpu_sum, grid.x / 8, block.x);

		
	// kernel 5: reduceCompleteUnrollWarp8（展开 8 + 展开 Warp + 完全展开循环）
	CHECK(cudaMemcpy(idata_dev, idata_host, bytes, cudaMemcpyHostToDevice));
	CHECK(cudaDeviceSynchronize());
	iStart = cpuSecond();
	reduceCompleteUnrollWarp8 <<<grid.x / 8, block>>>(idata_dev, odata_dev, size);
	cudaDeviceSynchronize();
	iElaps = cpuSecond() - iStart;
	cudaMemcpy(odata_host, odata_dev, grid.x * sizeof(int), cudaMemcpyDeviceToHost);
	gpu_sum = 0;
	for (int i = 0; i < grid.x / 8; i++)
		gpu_sum += odata_host[i];
	printf("reduceCompleteUnrollWarp8   elapsed %lf ms gpu_sum: %d<<<grid %d block %d>>>\n",
		iElaps, gpu_sum, grid.x / 8, block.x);

	// kernel 6: reduceCompleteUnroll（模板版，编译期确定 Block 大小）
	CHECK(cudaMemcpy(idata_dev, idata_host, bytes, cudaMemcpyHostToDevice));
	CHECK(cudaDeviceSynchronize());
	iStart = cpuSecond();
	switch (blocksize)
	{
		case 1024:
			reduceCompleteUnroll<1024><<<grid.x / 8, block>>>(idata_dev, odata_dev, size);
			break;
		case 512:
			reduceCompleteUnroll<512><<<grid.x / 8, block>>>(idata_dev, odata_dev, size);
			break;
		case 256:
			reduceCompleteUnroll<256><<<grid.x / 8, block>>>(idata_dev, odata_dev, size);
			break;
		case 128:
			reduceCompleteUnroll<128><<<grid.x / 8, block>>>(idata_dev, odata_dev, size);
			break;
	}
	cudaDeviceSynchronize();
	iElaps = cpuSecond() - iStart;
	cudaMemcpy(odata_host, odata_dev, grid.x * sizeof(int), cudaMemcpyDeviceToHost);
	gpu_sum = 0;
	for (int i = 0; i < grid.x / 8; i++)
		gpu_sum += odata_host[i];
	printf("reduceCompleteUnroll        elapsed %lf ms gpu_sum: %d<<<grid %d block %d>>>\n",
		iElaps, gpu_sum, grid.x / 8, block.x);

	// 释放内存
	free(idata_host);
	free(odata_host);
	CHECK(cudaFree(idata_dev));
	CHECK(cudaFree(odata_dev));

	cudaDeviceReset();

	if (gpu_sum == cpu_sum)
		printf("Test success!\n");

	return EXIT_SUCCESS;
}
