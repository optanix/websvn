#!/usr/bin/env bash
#
# Copyright 2017, Optanix, Inc.  All Rights Reserved
#
# builds all packages or those specified on the command line.

set -e

errorLabelColor=""
errorTextColor=""
infoLabelColor=""
infoTextColor=""
timeColor=""
resetColor=""
if [[ "$TERM" == "xterm-color" || -n "$FORCE_COLOR" ]]; then
    errorLabelColor="\e[101m"
    errorTextColor="\e[91m"
    infoLabelColor="\e[46m"
    infoTextColor="\e[36m"
    timeColor="\e[93m"
    resetColor="\e[0m"
elif [[ "$TERM" == "xterm-256color" ]]; then
    errorLabelColor="\e[48;5;202m"
    errorTextColor="\e[38;5;202m"
    infoLabelColor="\e[48;5;30m"
    infoTextColor="\e[38;5;30m"
    timeColor="\e[38;5;228m"
    resetColor="\e[0m"
fi

log() {
    if [[ -n "$NO_TIMESTAMP" ]]; then
        time=""
    else
        time=`date +"$timeColor[%H:%M:%S]$resetColor "`
    fi
    echo -e "$time$1"
}

error () {
    if [[ -z "$2" ]]; then
        log "$errorTextColor $1$resetColor"
    else
        log "$errorLabelColor$1:$resetColor $errorTextColor$2$resetColor"
    fi
}

info () {
    if [[ -z "$2" ]]; then
        log "$infoTextColor$1$resetColor$resetColor"
    else
        log "$infoLabelColor$1:$resetColor $infoTextColor$2$resetColor"
    fi
}

package=boot-config
revision='HEAD'
version='2.3.3'

# jenkins needs a branch option because it works in a detached head rather than a specific branch
# when doing a multi branch pipeline
while test ${#} -gt 0
do
    case "$1" in
        --branch)
            branch=$2
            shift 2
            ;;
        --) # End of all options
            shift
            break;
            ;;
        *)
            break
            ;;
    esac
done

if [[ -z "$branch" ]]; then
    branch=`git rev-parse --abbrev-ref $revision | tr "\-_/" "~.."`
else
    branch=`echo $branch | tr "\-_/" "~.."`
fi

returnValue=0

info "Creating directories for Debian"
mkdir pkg-src/DEBIAN
mkdir -p pkg-src/usr/share/doc/websvn
mkdir -p pkg-src/usr/share/lintian/overrides
cp control pkg-src/DEBIAN/
cp license.txt pkg-src/usr/share/doc/boot-config/copyright
cp lintian.overrides pkg-src/usr/share/lintian/overrides/websvn

info "Moving websvn to dir"
mv pkg-src/websvn pkg-src/usr/share

info "Building package" $package
architecture=`grep 'Architecture:' pkg-src/DEBIAN/control | cut -d ' ' -f 2`
build='';
if [[ -n "$BUILD_NUMBER" ]]; then
  build="~$BUILD_NUMBER"
fi

packageVersion="$version+$branch$build"
packageName="$package-${packageVersion}_$architecture.deb"
echo $packageVersion

info "Updating the control file..."
sed -i "s/Version:.*/Version: $packageVersion/" pkg-src/DEBIAN/control

info "Generating changelog..."
mkdir -p pkg-src/usr/share/doc/$package
git --no-pager log --first-parent --no-color --max-count=1 \
    --format="$package ($version) unstable; urgency=low%n%n%w(74,2,4)* %B%w(0,0,0)%n%n -- %an <%ae>  %aD%n" \
    > pkg-src/usr/share/doc/$package/changelog
gzip -n -f -9 pkg-src/usr/share/doc/$package/changelog

info "Generating md5sums..."
find pkg-src -type f -not -regex '.*?DEBIAN.*' -print0 \
    | xargs -0 md5sum \
    | sed "s/pkg-src\///g" \
    > pkg-src/DEBIAN/md5sums

info "Assembling the package..."
fakeroot dpkg-deb --build pkg-src $packageName

info "Cleaning up files..."
git checkout -- control

#Skipping lintian errors for now because I can't override dir-or-file-in-opt

#info "Verifying the package..."
# NOTE: lintian returns a non zero status code if it finds issues, so ignore its exit status
issues=`lintian --show-overrides --info --pedantic $packageName \
    | tee $packageName.lintian \
    | grep '^[WE]: ' \
    | wc -l`
error "Issues Found" $issues
info "Please view '$packageName.lintian' for details!"
info "Created package $packageName"

exit $returnValue
