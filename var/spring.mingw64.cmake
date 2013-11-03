# the name of the target operating system
SET(CMAKE_SYSTEM_NAME Windows)

# which compilers to use for C and C++
SET(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc)
SET(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++)

# here is the target environment located
SET(CMAKE_FIND_ROOT_PATH /home/buildserv/mingw64/x86_64-w64-mingw32)

set(WINDRES /home/buildserv/mingw64/bin/x86_64-w64-mingw32-windres)
