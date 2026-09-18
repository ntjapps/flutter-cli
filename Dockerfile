FROM ubuntu:noble

ENV PATH="/usr/local/flutter-cli/flutter/bin:/usr/local/android-cli/cmdline-tools/bin:/usr/local/android-cli/platform-tools:${PATH}"
ENV FLUTTER_GIT_URL="https://github.com/flutter/flutter.git"
ENV ANDROID_HOME=/usr/local/android-cli
ENV ANDROID_SDK_ROOT=/usr/local/android-cli
ENV PUB_CACHE=/opt/pub-cache
ENV GRADLE_USER_HOME=/opt/gradle

# Install Flutter Dependencies
RUN apt update && apt upgrade -y && apt autoremove -y && \
    apt install -y bash curl file git unzip xz-utils zip libglu1-mesa && \
    mkdir -p /usr/local/flutter-cli && \
    cd /tmp && \
    curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.4-stable.tar.xz -o flutter.tar.xz && \
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
    curl -L https://dl.google.com/android/repository/commandlinetools-linux-16111833_latest.zip -o android-cli.zip && \
    unzip android-cli.zip -d /usr/local/android-cli && \
    rm -rf android-cli.zip && \
    mkdir -p /root/.android && \
    touch /root/.android/repositories.cfg && \
    mkdir -p /usr/local/android-cli/cmdline-tools/latest && \
    yes | sdkmanager --licenses --sdk_root=/usr/local/android-cli && \
    sdkmanager --update --sdk_root=/usr/local/android-cli && \
    sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.1.0" "cmdline-tools;latest" "ndk;28.2.13676358" "cmake;3.31.6" --sdk_root=/usr/local/android-cli

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
