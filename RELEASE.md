Upstream
========

* run the full testsuite

        bash test/docker.sh

* prepare the environment:

        export VERSION=x.y.z

* update `configure.ac` and `CHANGELOG.md`

        perl -pi -E \
           "s{^AC_INIT\(\[backupninja\],\[[0-9.\-rc]+\],}{AC_INIT([backupninja],[$VERSION],}" \
           configure.ac

        RELEASE_DATE=$(LC_ALL=C date '+%Y-%m-%d'); perl -pi -E \
           "s{^## \[Unreleased\].*}{## [$VERSION] - $RELEASE_DATE}" \
           CHANGELOG.md

* commit and created signed tag

        git commit configure.ac CHANGELOG.md \
            -m "Releasing backupninja $VERSION" && \
        git clean -fdx && \
        git tag -s "backupninja-$VERSION" \
            -m "Releasing backupninja $VERSION" && \
        ./autogen.sh && \
        ./configure && \
        make dist

* compare the content of the generated tarball with the content of the
  previous one

        diffoscope --text-color=always ../tarballs/backupninja-x.y.z.tar.gz \
            backupninja-$VERSION.tar.gz | less -R

* move the tarball outside of the Git working copy and clean up

        mkdir -p ../tarballs && \
        mv backupninja-$VERSION.tar.gz ../tarballs/ && \
        make distclean && \
        git clean -fdx

Debian
======

Prepare a new package:

        git checkout debian && \
        gbp import-orig --upstream-vcs-tag="backupninja-$VERSION" \
            ../tarballs/backupninja-$VERSION.tar.gz && \
        gbp dch --auto && \
        dch -e && \
        export DEBIAN_VERSION=$(dpkg-parsechangelog -SVersion) && \
        git commit debian/changelog \
           -m "Releasing backupninja ($DEBIAN_VERSION) to Debian unstable" && \
        gbp buildpackage

Install the `.deb` and test.

Release
=======

* push the release to GitLab

        git checkout debian && \
        gbp buildpackage --git-tag-only --git-sign-tags && \
        git push --follow-tags origin \
            master:master \
            debian:debian \
            pristine-tar:pristine-tar \
            upstream:upstream

* create a new GitLab release

* announce the release on the backupninja mailing-list,
  pointing to the milestone web page

* upload to Debian or ask someone listed in the `Uploaders` control
  field to review and upload

Open the next development cycle
===============================

* `git checkout master`

* Add an empty new section in `CHANGELOG.md`, commit and push.
