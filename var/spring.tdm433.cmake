# the name of the target operating system
SET(CMAKE_SYSTEM_NAME Windows)

# which compilers to use for C and C++
SET(CMAKE_C_COMPILER i386-mingw32msvc-gcc)
SET(CMAKE_CXX_COMPILER i386-mingw32msvc-g++)

# here is the target environment located
SET(CMAKE_FIND_ROOT_PATH /home/buildserv/mingwTdm433/i386-mingw32msvc)

set(WINDRES /home/buildserv/mingwTdm433/bin/i386-mingw32msvc-windres)
