#ifndef FRESHMAN_H
#define FRESHMAN_H
#define CHECK(call)\
{\
  const cudaError_t error=call;\
  if(error!=cudaSuccess)\
  {\
      printf("ERROR: %s:%d,",__FILE__,__LINE__);\
      printf("code:%d,reason:%s\n",error,cudaGetErrorString(error));\
      exit(1);\
  }\
}


#include <time.h>
#ifdef _WIN32
#	include <windows.h>
#else
#	include <sys/time.h>
#endif
#ifdef _WIN32
// Windows 没有 POSIX 的 gettimeofday，用 SYSTEMTIME 手动实现
// 用于在 Windows 平台上获取微秒级时间戳
int gettimeofday(struct timeval *tp, void *tzp)
{
  time_t clock;
  struct tm tm;
  SYSTEMTIME wtm;
  GetLocalTime(&wtm);
  tm.tm_year   = wtm.wYear - 1900;  // tm_year 是从 1900 起算的偏移
  tm.tm_mon   = wtm.wMonth - 1;     // tm_mon 是 0-11
  tm.tm_mday   = wtm.wDay;
  tm.tm_hour   = wtm.wHour;
  tm.tm_min   = wtm.wMinute;
  tm.tm_sec   = wtm.wSecond;
  tm. tm_isdst  = -1;               // -1 表示让 mktime 自己判断夏令时
  clock = mktime(&tm);
  tp->tv_sec = clock;
  tp->tv_usec = wtm.wMilliseconds * 1000;  // 毫秒 → 微秒
  return (0);
}
#endif

// 返回当前时间戳（秒，浮点数），用于计算 kernel 执行耗时
// 用法：double t0 = cpuSecond(); kernel<<<...>>>(); cudaDeviceSynchronize();
//       double dt = cpuSecond() - t0;
double cpuSecond()
{
  struct timeval tp;
  gettimeofday(&tp,NULL);
  return((double)tp.tv_sec+(double)tp.tv_usec*1e-6);
}

void initialData(float* ip,int size)
{
  time_t t;
  srand((unsigned )time(&t));
  for(int i=0;i<size;i++)
  {
    ip[i]=(float)(rand()&0xffff)/1000.0f;
  }
}
void initialData_int(int* ip, int size)
{
	time_t t;
	srand((unsigned)time(&t));
	for (int i = 0; i<size; i++)
	{
		ip[i] = int(rand()&0xff);
	}
}
void printMatrix(float * C,const int nx,const int ny)
{
  float *ic=C;
  printf("Matrix<%d,%d>:\n",ny,nx);
  for(int i=0;i<ny;i++)
  {
    for(int j=0;j<nx;j++)
    {
      printf("%6f ",ic[j]);
    }
    ic+=nx;
    printf("\n");
  }
}

void initDevice(int devNum)
{
  int dev = devNum;
  cudaDeviceProp deviceProp;
  CHECK(cudaGetDeviceProperties(&deviceProp,dev));
  printf("Using device %d: %s\n",dev,deviceProp.name);
  CHECK(cudaSetDevice(dev));

}
void checkResult(float * hostRef,float * gpuRef,const int N)
{
  double epsilon=1.0E-8;
  for(int i=0;i<N;i++)
  {
    if(abs(hostRef[i]-gpuRef[i])>epsilon)
    {
      printf("Results don\'t match!\n");
      printf("%f(hostRef[%d] )!= %f(gpuRef[%d])\n",hostRef[i],i,gpuRef[i],i);
      return;
    }
  }
  printf("Check result success!\n");
}
#endif//FRESHMAN_H
