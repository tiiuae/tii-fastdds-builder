#!/bin/bash

set -eo pipefail

mod_dir=${1}

echo "[INFO] Building dependencies using underlay.repos."
if [ ! -e ${mod_dir} ]; then
    mkdir -p ${mod_dir}
fi
cd ${mod_dir}

echo "[INFO] Get package dependencies."
# Dependencies from fog-sw repo
if [ -e ${mod_dir}/ros2_ws/src ]; then
    echo "[INFO] Use dependencies from fog_sw."
    pushd ${mod_dir}/ros2_ws > /dev/null
    source /opt/ros/${ROS_DISTRO}/setup.bash
else
    echo "[INFO] Use dependencies from local repository."
    mkdir -p ${mod_dir}/deps_ws/src
    cp ${mod_dir}/packaging/colcon.meta ${mod_dir}/deps_ws/
    pushd ${mod_dir}/deps_ws > /dev/null
    vcs import src < ${mod_dir}/packaging/underlay.repos
    rosdep install --from-paths src --ignore-src -r -y --rosdistro ${ROS_DISTRO}
    source /opt/ros/${ROS_DISTRO}/setup.bash
fi

# Not possible to have generic dependency build script
# when the repo contains part of the dependencies.
PKGS_TO_BUILD="fastcdr fastrtps fastrtps_cmake_module foonathan_memory_vendor rosidl_typesupport_fastrtps_c rosidl_typesupport_fastrtps_cpp rmw_fastrtps_shared_cpp"
echo "[INFO] Packages to build: $PKGS_TO_BUILD"

echo "[INFO] Build package dependencies."
colcon build \
    --packages-select ${PKGS_TO_BUILD}
popd > /dev/null
