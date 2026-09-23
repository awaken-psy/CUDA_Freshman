@echo off
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvarsall.bat" x64
if not exist build mkdir build
cd build
if not exist build.ninja (
    cmake .. -G Ninja -Wno-dev -DCMAKE_BUILD_TYPE=Release
)
cmake --build .
