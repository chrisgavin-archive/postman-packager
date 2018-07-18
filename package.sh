#!/usr/bin/env sh
set -eu
cd $(dirname "$0")

# Make the temporary locations.
working_directory=$(mktemp --directory --suffix=postman-packager-working)
trap 'rm -rf "$working_directory"' EXIT
download_file=$(mktemp --suffix=postman-packager-tar)
trap 'rm -f "$download_file"' EXIT
extracted_directory=$(mktemp --directory --suffix=postman-packager-extracted)
trap 'rm -rf "$extracted_directory"' EXIT

# Create directory structure.
cp --recursive "template/"* "$working_directory/"

# Download Postman.
curl -o "$download_file" "https://dl.pstmn.io/download/latest/linux64"
tar -xf "$download_file" -C "$extracted_directory"
mkdir -p "$working_directory/usr/lib/"
mv "$extracted_directory/Postman/app/" "$working_directory/usr/lib/postman/"
mkdir -p "$working_directory/usr/share/icons/"
cp "$working_directory/usr/lib/postman/resources/app/assets/icon.png" "$working_directory/usr/share/icons/postman.png"

# Set permissions.
chmod --recursive go-w "$working_directory/"

# Create package.
version=$(cat "$working_directory/usr/lib/postman/version" | cut -c 2-)
rm -rf "./output/"
mkdir -p "./output/"
fpm \
	--chdir "$working_directory" \
	--input-type "dir" \
	--output-type "deb" \
	--package "./output/" \
	--name "postman" \
	--version "$version" \
	--vendor "Postman <info@getpostman.com>" \
	--maintainer "Chris Gavin <chris@chrisgavin.me>" \
	--architecture "x86_64" \
	--url "https://www.getpostman.com/" \
	--description "Postman is an API development environment and debugger." \
	--category "net" \
	--license "Proprietary" \
	--deb-no-default-config-files \
	"."

# Push package.
if [ -z "${PACKAGECLOUD_TOKEN:-}" ]; then
	>&2 echo "Not pushing the package as there is no token availiable."
else
	for release in "xenial" "bionic"; do
		>&2 echo "Pushing release ubuntu/$release."
		release_status=0
		push_status=`package_cloud push "chrisgavin/postman/ubuntu/$release" "./output/"*".deb" || release_status=$?`
		if [ "$release_status" -ne "0" ]; then
			if [[ "$push_status" == *"filename: has already been taken"* ]]; then
				>&2 echo "This package has already been pushed."
			else
				>&2 echo "Pushing the package failed. $push_status"
				exit "$release_status"
			fi
		fi
	done
fi
