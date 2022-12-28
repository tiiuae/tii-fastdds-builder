#!/bin/bash -eux

# set -euxo pipefail
# set -eux

output_dir=${1:-./bin/.}

git_commit_hash=${2:-$(git rev-parse HEAD)}

git_version_string=${3:-$(git log --date=format:%Y%m%d --pretty=~git%cd.%h -n 1)}

build_number=${GITHUB_RUN_NUMBER:=0}

ros_distro=${ROS_DISTRO:=galactic}

iname=${IMAGE_NAME:=tii_fastdds_builder}

# package_path=${PACKAGE_DIR:=$iname}

iversion=${PACKAGE_VERSION:=latest}

function build_image {
  local iname=${1}
  local iversion=${2}
  local ros_distro=${3}
  docker build \
    --build-arg UID=$(id -u) \
    --build-arg GID=$(id -g) \
    --build-arg ROS_DISTRO=${ros_distro} \
    --build-arg IMAGE_NAME=${iname} \
    --pull \
    -f Dockerfile.build_env -t "${iname}:${iversion}" .
}

function build_package {
  local iname=${1}
  local iversion=${2}
	local package_path=${3}
  local package_dependencies=${4:-""}
  pushd ${package_path}
    local git_commit_hash=${5:-$(git rev-parse HEAD)}
    local git_version_string=${6:-$(git log --date=format:%Y%m%d --pretty=~git%cd.%h -n 1)}
  popd
  docker run \
    --rm \
    -v $(pwd)/${package_path}:/${iname}/sources \
    -v $(pwd)/packaging:/${iname}/packaging \
    -v $(pwd)/bin:/${iname}/bin \
    ${iname}:${iversion} \
    /${iname}/packaging/package.sh \
    -b ${build_number} \
    -g ${git_commit_hash} \
    -v ${git_version_string} \
    -t "${package_dependencies}"

    mkdir -p ${output_dir}
    /bin/cp -rf ${package_path}/*.deb ${output_dir}
    rm -Rf ${package_path}/*.deb
}

function build_all_packages {
  build_package tii_fastdds_builder ${iversion} foonathan_memory_vendor ""

  build_package tii_fastdds_builder ${iversion} Fast-CDR ""

  build_package tii_fastdds_builder ${iversion} Fast-DDS \
    "ros-${ros_distro}-foonathan-memory-vendor ros-${ros_distro}-fastcdr"

  build_package tii_fastdds_builder ${iversion} rosidl_typesupport_fastrtps/fastrtps_cmake_module \
    "ros-${ros_distro}-foonathan-memory-vendor ros-${ros_distro}-fastcdr ros-${ros_distro}-fastrtps"

  build_package tii_fastdds_builder ${iversion} rosidl_typesupport_fastrtps/rosidl_typesupport_fastrtps_cpp \
    "ros-${ros_distro}-foonathan-memory-vendor ros-${ros_distro}-fastcdr ros-${ros_distro}-fastrtps \
    ros-${ros_distro}-fastrtps-cmake-module"

  build_package tii_fastdds_builder ${iversion} rosidl_typesupport_fastrtps/rosidl_typesupport_fastrtps_c \
    "ros-${ros_distro}-foonathan-memory-vendor ros-${ros_distro}-fastcdr ros-${ros_distro}-fastrtps \
    ros-${ros_distro}-fastrtps-cmake-module ros-${ros_distro}-rosidl-typesupport-fastrtps-cpp"

  build_package tii_fastdds_builder ${iversion} rmw_fastrtps/rmw_fastrtps_shared_cpp \
    "ros-${ros_distro}-foonathan-memory-vendor ros-${ros_distro}-fastcdr ros-${ros_distro}-fastrtps \
    ros-${ros_distro}-fastrtps-cmake-module ros-${ros_distro}-rosidl-typesupport-fastrtps-cpp \
    ros-${ros_distro}-rosidl-typesupport-fastrtps-c"

  build_package tii_fastdds_builder ${iversion} rmw_fastrtps/rmw_fastrtps_cpp \
    "ros-${ros_distro}-foonathan-memory-vendor ros-${ros_distro}-fastcdr ros-${ros_distro}-fastrtps \
    ros-${ros_distro}-fastrtps-cmake-module ros-${ros_distro}-rosidl-typesupport-fastrtps-cpp \
    ros-${ros_distro}-rosidl-typesupport-fastrtps-c ros-${ros_distro}-rmw-fastrtps-shared-cpp"

  build_package tii_fastdds_builder ${iversion} rmw_fastrtps/rmw_fastrtps_dynamic_cpp \
    "ros-${ros_distro}-foonathan-memory-vendor ros-${ros_distro}-fastcdr ros-${ros_distro}-fastrtps \
    ros-${ros_distro}-fastrtps-cmake-module ros-${ros_distro}-rosidl-typesupport-fastrtps-cpp \
    ros-${ros_distro}-rosidl-typesupport-fastrtps-c ros-${ros_distro}-rmw-fastrtps-shared-cpp"
}

# not being sourced?
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  build_image ${iname} ${iversion} ${ros_distro}
	build_all_packages
fi
