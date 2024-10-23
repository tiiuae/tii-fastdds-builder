# tii-fastdds-builder


## Description
This repository builds the required Fast-DDS libraries using `ros:humble-ros-base` baseimage. It has the SECURITY enabled, and has the patch for the PKCS#11.


## How to use
### Clone and build the debs locally
Platform selection can be as "linux/amd64" or "linux/arm64". The arm64 build on a amd64 will be executed with qemu. You can find the instructions online about how to enable qemu on your system.

Make sure to create the bin directory. If the script creates it, it will be owned by root and make the script fail.
```bash
mkdir -p ~/tii-fastdds-builder-ws && cd ~/tii-fastdds-builder-ws
git clone --recurse-submodules https://github.com/tiiuae/tii-fastdds-builder.git
cd tii-fastdds-builder
mkdir bin
PLATFORM=linux/amd64 ./build.sh ./bin/
```

### Copy the deb packages to your local directory
```bash
docker create --name tii-fastdds-builder ghcr.io/tiiuae/tii-fastdds-artifacts:humble
mkdir -p ~/tii-fastdds-builder-ws/bin
docker cp tii-fastdds-builder:/artifacts/. ~/tii-fastdds-builder-ws/bin/
docker rm tii-fastdds-builder
ls -la ~/tii-fastdds-builder-ws/bin
```

Keep in mind that the artifacts include both "deb" packages and "ddeb" debugsymbol messages. If installing with dpkg command, use it as "dpkg -i *.deb".

### Copy and install deb packages in Dockerfile
Modify the tag name accordingly. The baseimage is given as an example, could be used any that has the ros2 installed. If the ROS2 installation is done later, install the deb packages after the ROS2 installation.
```Dockerfile
FROM ros:humble-ros-base

RUN mkdir -p /tmp/fastdds_debs
COPY --from=ghcr.io/tiiuae/tii-fastdds-artifacts:humble /artifacts/*.deb /tmp/fastdds_debs/
RUN dpkg -i /tmp/fastdds_debs/*.deb
```

Warning: If you are running an `apt upgrade` operation later, some of the packages might be upgraded to the version in the ROS2 repo. To avoid this, you can pin the packages to the version you have installed. For example, you can pin the Fast-DDS packages as follows:
```Dockerfile
RUN apt-mark hold ros-humble-fastcdr \
    ros-humble-fastrtps \
    ros-humble-rmw-fastrtps-cpp \
    ros-humble-rmw-fastrtps-dynamic-cpp \
    ros-humble-rmw-fastrtps-shared-cpp \
    ros-humble-rosidl-typesupport-fastrtps-c \
    ros-humble-rosidl-typesupport-fastrtps-cpp \
    ros-humble-foonathan-memory-vendor \
    ros-humble-fastrtps-cmake-module
```
