FROM archlinux/base

WORKDIR /usr/src/app

RUN pacman-key --init && \
    pacman -Sy --noconfirm archlinux-keyring && \
    pacman -Su --noconfirm base-devel && \
    pacman -Scc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/*

# prerequisite: jdk8 for Android, python for QML, ...
RUN pacman -S --noconfirm jdk8-openjdk git python && \
    pacman -Scc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/*

# Android sdk
RUN git clone https://aur.archlinux.org/android-sdk.git && \
    cd android-sdk && \
    chown -R nobody.root . && \
    echo "nobody ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/nobody && \
    sudo -u nobody -- makepkg --noconfirm -i -s && \
    cd ..  && \
    rm -rf android-sdk && \
    rm /etc/sudoers.d/nobody

RUN echo -e "y\ny\ny\ny\ny\ny\ny\n" | /opt/android-sdk/tools/bin/sdkmanager --licenses && \
    /opt/android-sdk/tools/bin/sdkmanager --install "platform-tools" "platforms;android-29" "build-tools;29.0.2" "ndk-bundle"

# Qt
ARG QTVERS=5.15.0

RUN curl -O -L https://download.qt.io/official_releases/qt/${QTVERS%.*}/${QTVERS}/single/qt-everywhere-src-${QTVERS}.tar.xz && \
    tar xJf qt-everywhere-src-${QTVERS}.tar.xz && \

    # https://doc.qt.io/qt-5/android-openssl-support.html
    git clone https://github.com/KDAB/android_openssl && \

    # Compile and install Qt for Android
    cd qt-everywhere-src-${QTVERS} && \
    ./configure -confirm-license -opensource -xplatform android-clang --disable-rpath -nomake tests -nomake examples -android-ndk /opt/android-sdk/ndk-bundle/ -android-sdk /opt/android-sdk/ -no-warnings-are-errors -skip qtserialport -skip qtwebengine -openssl-runtime -I/usr/src/app/android_openssl/static/include/ -android-abis armeabi-v7a -recheck-all && \
    make -j$(nproc) && \
    make -j$(nproc) install && \

    # Clean up
    cd .. && \
    rm -rf qt-everywhere-src-${QTVERS}.tar.xz qt-everywhere-src-${QTVERS} android_openssl

ENV PATH "/usr/local/Qt-${QTVERS}/bin/:$PATH"

# test it !
COPY helloworld.* helloworld/

RUN cd helloworld && \
    qmake && \
    make -j$(nproc) apk && \
    make distclean && \
    rm -rf android-build armeabi-v7a *.json
