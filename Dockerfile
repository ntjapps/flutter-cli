# Supply-chain pins. Every downloaded artifact is verified with sha256sum -c
# and the build fails on a mismatch. To bump, change the version/URL and its
# checksum together in ONE commit (never bump one without the other):
#   * Base image: `docker buildx imagetools inspect ubuntu:noble` -> copy the
#     top-level "Digest:" (the multi-arch index digest) into FROM below.
#   * Flutter SDK: pick the release in
#     https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json
#     and set FLUTTER_VERSION plus FLUTTER_SHA256 (the release's "sha256" field).
#   * Android cmdline-tools: take the newest commandlinetools-linux-<N>_latest.zip
#     from https://dl.google.com/android/repository/repository2-1.xml. Google only
#     publishes a SHA-1 there: download the zip, check it against that SHA-1, then
#     pin the zip's SHA-256 (`sha256sum`) as ANDROID_CMDLINE_TOOLS_SHA256 and set
#     ANDROID_CMDLINE_TOOLS_BUILD to <N>.
# Not covered by these pins: apt packages, `flutter precache` engine artifacts and
# `sdkmanager` packages (the latter two are fetched over HTTPS and verified by
# their own tools).
FROM ubuntu:noble@sha256:534baea6a22c03a63003dbc8dbe78fe34bc0d7e595d9a9dc9834884ff530eb55

ENV PATH="/usr/local/flutter-cli/flutter/bin:/usr/local/android-cli/cmdline-tools/bin:/usr/local/android-cli/platform-tools:${PATH}"
ENV FLUTTER_GIT_URL="https://github.com/flutter/flutter.git"
ENV ANDROID_HOME=/usr/local/android-cli
ENV ANDROID_SDK_ROOT=/usr/local/android-cli
ENV PUB_CACHE=/opt/pub-cache
ENV GRADLE_USER_HOME=/opt/gradle

ARG FLUTTER_VERSION=3.47.7
ARG FLUTTER_SHA256=af7455f540df951184c7953fbe3cf884766e7541dacf8571f9f582db03dd6230
ARG ANDROID_CMDLINE_TOOLS_BUILD=16111833
ARG ANDROID_CMDLINE_TOOLS_SHA256=0877a1d048fe4a24efe2eff536ca4223f7adeb58648bb81909d33c446918cfa8

# Install Flutter Dependencies
RUN apt update && apt upgrade -y && apt autoremove -y && \
    apt install -y bash curl file git unzip xz-utils zip libglu1-mesa && \
    mkdir -p /usr/local/flutter-cli && \
    cd /tmp && \
    curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -o flutter.tar.xz && \
    echo "${FLUTTER_SHA256}  flutter.tar.xz" | sha256sum -c - && \
    tar xf flutter.tar.xz -C /usr/local/flutter-cli && \
    rm -rf flutter.tar.xz && \
    git config --global --add safe.directory /usr/local/flutter-cli/flutter && \
    flutter config --no-analytics && \
    flutter --disable-analytics && \
    flutter precache

# Set up shared pub/Gradle caches so `--rm` runs (with only $PWD bind-mounted
# by the host wrapper) don't re-download the world on every invocation. The
# host wrapper mounts its own persistent directories at these same paths, so
# they must be writable regardless of which UID the container runs as.
RUN mkdir -p "$PUB_CACHE" "$GRADLE_USER_HOME" && \
    chmod -R 777 "$PUB_CACHE" "$GRADLE_USER_HOME"

# Install Java
RUN apt install -y openjdk-21-jdk && \
    update-alternatives --set java /usr/lib/jvm/java-21-openjdk-amd64/bin/java && \
    update-alternatives --set javac /usr/lib/jvm/java-21-openjdk-amd64/bin/javac

ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

# Install Android SDK
RUN cd /tmp && \
    curl -fsSL "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_BUILD}_latest.zip" -o android-cli.zip && \
    echo "${ANDROID_CMDLINE_TOOLS_SHA256}  android-cli.zip" | sha256sum -c - && \
    unzip android-cli.zip -d /usr/local/android-cli && \
    rm -rf android-cli.zip && \
    mkdir -p /root/.android && \
    touch /root/.android/repositories.cfg && \
    mkdir -p /usr/local/android-cli/cmdline-tools/latest && \
    yes | sdkmanager --licenses --sdk_root=/usr/local/android-cli && \
    sdkmanager --update --sdk_root=/usr/local/android-cli && \
    sdkmanager "platform-tools" "platforms;android-34" "platforms;android-35" "platforms;android-36" "platforms;android-37.0" "build-tools;36.0.0" "build-tools;37.0.0" "cmdline-tools;latest" "ndk;28.2.13676358" "cmake;4.1.2" "cmake;3.22.1" --sdk_root=/usr/local/android-cli

# Privilege drop
RUN adduser --disabled-password --gecos '' flutter && \
    chown -R flutter:flutter /usr/local/flutter-cli && \
    chown -R flutter:flutter /usr/local/android-cli && \
    chown -R flutter:flutter /root/.android && \
    chown -R flutter:flutter "$PUB_CACHE" "$GRADLE_USER_HOME"

USER flutter

# Check Flutter Version
RUN flutter doctor -v

ENTRYPOINT ["flutter"]
