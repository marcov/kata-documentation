#!/bin/bash
#
# Copyright (c) 2018 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0

set -e

info()
{
	msg="$*"
	echo "INFO: $msg"
}

# Detect if any installation documents changed. If so, run the
# kata manager to "execute" the install guide to ensure the
# commands it specified result in a working system.
check_install_guides()
{
	[ -n "$TRAVIS" ] && info "Not testing install guide as Travis lacks modern distro support and VT-x" && return 

	# List of filters used to restrict the types of file changes.
	# See git-diff-tree(1) for further info.
	local filters=""

	# Added file
	filters+="A"

	# Copied file
	filters+="C"

	# Modified file
	filters+="M"

	# Renamed file
	filters+="R"

	# Unmerged (U) and Unknown (X) files. These particular filters
	# shouldn't be necessary but just in case...
	filters+="UX"

	# List of changed files
	local files=$(git diff-tree \
		--name-only \
		--no-commit-id \
		--diff-filter="${filters}" \
		-r \
		origin/master HEAD || true)

	# No files were changed
	[ -z "$files" ] && return

	changed=$(echo "$files" | grep "^install/.*\.md$" || true)

	[ -z "$changed" ] && info "No install guides modified" && return

	info "Found modified install guides: $changed"

	# Regardless of which distro install guide(s) were changed, we test
	# them all where possible.

	local -r GOPATH=$(go env GOPATH)
	[ -z "$GOPATH" ] && die "cannot determine GOPATH"

	local -r mgr="${GOPATH}/src/github.com/kata-containers/tests/cmd/kata-manager/kata-manager.sh"

	[ ! -e "$GOPATH" ] && die "cannot find $mgr"

	source /etc/os-release

	info "Installing system from the $ID install guide"

	$mgr install-docker-system

	$mgr configure-image
	$mgr enable-debug

	msg="INFO: Successfully tested install guide for distro '$ID' $VERSION"

	# Perform a basic test
	sudo -E docker run --rm -i --runtime "kata-runtime" busybox echo "$msg"
}

check_install_guides
