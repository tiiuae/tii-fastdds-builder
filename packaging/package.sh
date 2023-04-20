#!/bin/bash

set -eo pipefail

usage() {
	echo "
Usage: $(basename "$0") [-h] [-b nbr] [-d dist]
 -- Generate debian package from fog_sw module.
Params:
    -h  Show help text.
    -b  Build number. This will be tha last digit of version string (x.x.N).
    -d  Distribution string in debian changelog.
    -g  Git commit hash.
    -v  Git version string
"
	exit 0
}

check_arg() {
	if [ "$(echo $1 | cut -c1)" = "-" ]; then
		return 1
	else
		return 0
	fi
}

error_arg() {
	echo "$0: option requires an argument -- $1"
	usage
}

mod_dir="$(realpath $(dirname $0)/..)"
build_nbr=0
distr=""
version=""
git_commit_hash=""
git_version_string=""
dependencies=""

while getopts "hb:d:g:v:t:" opt
do
	case $opt in
		h)
			usage
			;;
		b)
			check_arg $OPTARG && build_nbr=$OPTARG || error_arg $opt
			;;
		d)
			check_arg $OPTARG && distr=$OPTARG || error_arg $opt
			;;
		g)
			check_arg $OPTARG && git_commit_hash=$OPTARG || error_arg $opt
			;;
		v)
			check_arg $OPTARG && git_version_string=$OPTARG || error_arg $opt
			;;
		t)
			check_arg $OPTARG && dependencies=$OPTARG || error_arg $opt
			;;
		\?)
			usage
			;;
	esac
done

if [[ "$git_commit_hash" == "0" || -z "$git_commit_hash" ]]; then
	git_commit_hash="$(git rev-parse HEAD)"
fi
if [[ "$git_version_string" == "0" || -z "$git_version_string" ]]; then
	git_version_string="$(git log --date=format:%Y%m%d --pretty=~git%cd.%h -n 1)"
fi

## Remove trailing '/' mark in module dir, if exists
mod_dir=$(echo $mod_dir | sed 's/\/$//')

## Debug prints
echo "[INFO] build_nbr: ${build_nbr}."
echo "[INFO] distr: ${distr}."
echo "[INFO] git_commit_hash: ${git_commit_hash}."
echo "[INFO] git_version_string: ${git_version_string}."
echo "[INFO] Dependencies: ${dependencies}."

## Generate package
echo "[INFO] Creating deb package..."
### ROS2 Packaging

### Create version string
version=$(grep "<version>" package.xml | sed 's/[^>]*>\([^<"]*\).*/\1/')

echo "[INFO] Version: ${version}."

#title="$version ($(date +%Y-%m-%d))"
#cat << EOF_CHANGELOG > CHANGELOG.rst
#$title
#$(printf '%*s' "${#title}" | tr ' ' "-")
#* commit: ${git_commit_hash}
#EOF_CHANGELOG

if [ -e ${mod_dir}/bin ]; then
	# Install any available debian packages
	for dependency in ${dependencies[@]}; do
		echo "Looking to directory ${mod_dir}/bin/${dependency}_*.deb"
		if [ -e ${mod_dir}/bin/${dependency}_*.deb ]; then
			echo "[INFO] Installing $dependency"
			sudo dpkg -i ${mod_dir}/bin/${dependency}_*.deb
		fi
	done
fi

if [ -e ${mod_dir}/debian ]; then
	cp -r debian debian_bak
fi

export DEB_BUILD_OPTIONS="parallel=`nproc` nocheck"

bloom-generate rosdebian --os-name ubuntu --os-version jammy --ros-distro ${ROS_DISTRO} --place-template-files \
    && sed -i 's/^export DEB_CXXFLAGS_MAINT_APPEND=-DNDEBUG/export DEB_CXXFLAGS_MAINT_APPEND=-DNDEBUG -DSECURITY=ON/g' debian/rules.em \
    && sed -i 's/^\t\t$(BUILD_TESTING_ARG)/\t\t$(BUILD_TESTING_ARG) \\\n\t\t-DINSTALL_EXAMPLES=OFF \\\n\t\t-DSECURITY=ON \\\n\t\t-DCMAKE_BUILD_TYPE=Release/g' debian/rules.em \
    && sed -i "s/@(DebianInc)@(Distribution)/@(DebianInc)/" debian/changelog.em \
    && [ ! "$distr" = "" ] && sed -i "s/@(Distribution)/${distr}/" debian/changelog.em || : \
    && bloom-generate rosdebian --os-name ubuntu --os-version jammy --ros-distro ${ROS_DISTRO} --process-template-files -i ${build_nbr}${git_version_string} \
    && sed -i 's/^\tdh_shlibdeps.*/& --dpkg-shlibdeps-params=--ignore-missing-info/g' debian/rules \
    && sed -i "s/\=\([0-9]*\.[0-9]*\.[0-9]*\*\)//g" debian/control \
    && fakeroot debian/rules clean \
    && fakeroot debian/rules "binary --parallel" || exit 1

echo "[INFO] Clean up."

rm -rf ${mod_dir}/sources/.obj-x86_64-linux-gnu debian

if [ -e ${mod_dir}/debian_bak ]; then
	cp -r debian_bak debian
	rm -rf debian_bak
fi


echo "[INFO] Move debian packages to volume."
mv ${mod_dir}/*.deb ${mod_dir}/sources

echo "[INFO] Done."
exit 0
