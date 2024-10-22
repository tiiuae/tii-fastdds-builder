#!/bin/bash -eu

output_dir=${1:-./bin/.}

git_commit_hash=${2:-$(git rev-parse HEAD)}

git_version_string=${3:-$(git log --date=format:%Y%m%d --pretty=~git%cd.%h -n 1)}

build_number=${GITHUB_RUN_NUMBER:=0}

ros_distro=${ROS_DISTRO:=humble}

iname=${IMAGE_NAME:=tii_fastdds_builder}

# package_path=${PACKAGE_DIR:=$iname}

iversion=${PACKAGE_VERSION:=latest}

# Determine platform argument
if [ -z "${PLATFORM}" ]; then
  platform_arg="--platform linux/amd64"
else
  platform_arg="--platform ${PLATFORM}"
fi

function build_image {
  local iname=${1}
  local iversion=${2}
  local ros_distro=${3}
  docker build \
    ${platform_arg} \
    --build-arg ROS_DISTRO=${ros_distro} \
    --build-arg IMAGE_NAME=${iname} \
    --pull \
    --progress=plain \
    --output type=docker \
    -f Dockerfile.build_env -t "${iname}:${iversion}" .
}

function patch_packages {
  local patches_dir=$(realpath ${1})
  local target_dir=$(realpath ${2})
  local patched_components=()
  
  for package_dir in ${patches_dir}/*; do
    if [ -d "${package_dir}" ]; then
      local package_name=$(basename ${package_dir})
      
      if [ -d "${target_dir}/${package_name}" ]; then
        echo "Found directory ${package_name} in ${target_dir}. Applying patches..."  >&2
        
        for patch in ${package_dir}/*.patch; do
          pushd ${target_dir}/${package_name} > /dev/null
            echo "Applying patch ${patch}"  >&2
            git_am_output=$(git am "${patch}" 2>&1)
            if [ $? -eq 0 ]; then
              echo "${git_am_output}" >&2
              patched_components+=("${package_name}:git_am")
            else
              echo "${git_am_output}" >&2
              echo "git am failed for ${patch}, aborting git am and applying with patch command"  >&2
              git am --abort
              patch -p1 < "${patch}"
              patched_components+=("${package_name}:patch")
            fi
          popd > /dev/null
        done
      else
        echo "Directory ${package_name} does not exist in ${target_dir}. Skipping..."  >&2
      fi
    fi
  done
  
  echo "${patched_components[@]}"
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
  if [ -e packaging/module_specific_files/${package_path} ]; then
    /bin/cp -rf packaging/module_specific_files/${package_path}/* ${package_path}
  fi

  if [ -e packaging/module_specific_patches/${package_path} ]; then
    # /bin/cp -rf packaging/module_specific_patches/${package_path}/* ${package_path}
    for patch in packaging/module_specific_patches/${package_path}/*.patch; do
      pushd ${package_path}/..
        pwd
        echo "Applying patch ${patch}"
        git am "../$patch"
      popd
    done
  fi
  docker run \
    ${platform_arg} \
    --rm \
    -v $(pwd)/${package_path}:/${iname}/sources \
    -v $(pwd)/packaging:/${iname}/packaging \
    -v $(pwd)/${output_dir}:/${iname}/${output_dir} \
    ${iname}:${iversion} \
    /${iname}/packaging/package.sh \
    -b ${build_number} \
    -g ${git_commit_hash} \
    -v ${git_version_string} \
    -t "${package_dependencies}" \
    -o ${output_dir}

    mkdir -p ${output_dir}
    /bin/cp -rf ${package_path}/*deb ${output_dir}
    rm -Rf ${package_path}/*deb

    if [ -e packaging/module_specific_patches/${package_path} ]; then
      pushd ${package_path}
        git reset --hard HEAD~1
      popd
    fi
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
  patched_components=$(patch_packages "packaging/module_specific_patches" ".")
  build_image ${iname} ${iversion} ${ros_distro}
  build_all_packages

  git submodule foreach git reset --hard
  git submodule update --init
fi
