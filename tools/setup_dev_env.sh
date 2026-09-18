#!/usr/bin/env bash
# Bootstraps a Flutter + Android build toolchain for the LifeRPG project on a
# bare Ubuntu machine. Installs Flutter and the Android SDK into $HOME (no
# root needed for those), and uses sudo only for the apt packages that are
# missing system-wide (a JDK, unzip, zip).
#
# Usage:
#   bash tools/setup_dev_env.sh
# Then either open a new shell or `source ~/.bashrc` to pick up PATH/env
# changes before running flutter/adb.
set -euo pipefail

FLUTTER_DIR="$HOME/flutter"
ANDROID_SDK_DIR="$HOME/Android/Sdk"
CMDLINE_TOOLS_ZIP_URL="https://dl.google.com/android/repository/commandlinetools-linux-15859902_latest.zip"
JAVA_HOME_PATH="/usr/lib/jvm/java-17-openjdk-amd64"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> [1/6] Installing system packages (needs sudo)..."
MISSING_PKGS=()
command -v java >/dev/null 2>&1 || MISSING_PKGS+=(openjdk-17-jdk)
command -v unzip >/dev/null 2>&1 || MISSING_PKGS+=(unzip)
command -v zip >/dev/null 2>&1 || MISSING_PKGS+=(zip)
if [ "${#MISSING_PKGS[@]}" -gt 0 ]; then
  sudo apt-get update
  sudo apt-get install -y "${MISSING_PKGS[@]}"
else
  echo "    all required apt packages already present, skipping"
fi

echo "==> [2/6] Installing Flutter SDK (stable channel) into $FLUTTER_DIR..."
if [ ! -d "$FLUTTER_DIR" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
else
  echo "    $FLUTTER_DIR already exists, skipping clone"
fi

echo "==> [3/6] Installing Android SDK command-line tools into $ANDROID_SDK_DIR..."
mkdir -p "$ANDROID_SDK_DIR/cmdline-tools"
if [ ! -d "$ANDROID_SDK_DIR/cmdline-tools/latest" ]; then
  TMP_ZIP="$(mktemp --suffix=.zip)"
  curl -fsSL -o "$TMP_ZIP" "$CMDLINE_TOOLS_ZIP_URL"
  unzip -q "$TMP_ZIP" -d "$ANDROID_SDK_DIR/cmdline-tools"
  # The zip extracts to cmdline-tools/cmdline-tools; sdkmanager expects .../cmdline-tools/latest
  mv "$ANDROID_SDK_DIR/cmdline-tools/cmdline-tools" "$ANDROID_SDK_DIR/cmdline-tools/latest"
  rm -f "$TMP_ZIP"
else
  echo "    cmdline-tools already installed, skipping download"
fi

echo "==> [4/6] Persisting environment variables in ~/.bashrc..."
BASHRC="$HOME/.bashrc"
add_line() { grep -qxF "$1" "$BASHRC" 2>/dev/null || echo "$1" >> "$BASHRC"; }
add_line "export JAVA_HOME=$JAVA_HOME_PATH"
add_line "export ANDROID_HOME=$ANDROID_SDK_DIR"
add_line "export ANDROID_SDK_ROOT=$ANDROID_SDK_DIR"
add_line "export PATH=\"$FLUTTER_DIR/bin:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$PATH\""

# Also export for the rest of *this* script run.
export JAVA_HOME="$JAVA_HOME_PATH"
export ANDROID_HOME="$ANDROID_SDK_DIR"
export ANDROID_SDK_ROOT="$ANDROID_SDK_DIR"
export PATH="$FLUTTER_DIR/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
export CI=true   # keeps flutter's first-run analytics prompt from blocking

echo "==> [5/6] Accepting Android SDK licenses and installing platform-tools..."
yes | sdkmanager --licenses >/dev/null 2>&1 || true
sdkmanager --install "platform-tools" >/dev/null
# Deliberately not pinning a platforms/build-tools version here: the Android
# Gradle Plugin auto-downloads whatever compileSdk/build-tools the project
# needs (see android/app/build.gradle.kts's flutter.compileSdkVersion) on
# the first `flutter build`, now that licenses are accepted and sdkmanager
# is reachable on PATH.

echo "==> [6/6] flutter doctor + project pub get..."
flutter config --no-analytics >/dev/null
flutter doctor -v
(cd "$PROJECT_DIR" && flutter pub get)

cat <<EOF

Done. Flutter: $FLUTTER_DIR
      Android SDK: $ANDROID_SDK_DIR
      JAVA_HOME: $JAVA_HOME_PATH

Open a new shell (or run: source ~/.bashrc) so PATH/env changes apply, then:
  cd $PROJECT_DIR
  flutter analyze
  flutter test

Note: 'flutter build apk' additionally needs android/app/google-services.json
and lib/firebase_options.dart, which are gitignored secrets not created by
this script -- see .claude/skills/installing-app/SKILL.md.
EOF
