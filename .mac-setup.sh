#!/usr/bin/env bash
set -e

# -----------------------------------------
# Homebrew (sudo-aware, non-interactive)
# -----------------------------------------
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
else
  echo "Homebrew already installed"
fi

eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"

# -----------------------------------------
# Formulae and Casks
# -----------------------------------------
FORMULAE=(
  fish
  starship
  frum
  fnm
  pyenv
  duti
)

CASKS=(
  orbstack
  ghostty
  slack
  discord
  google-chrome
  1password
  firefox
  mullvad-vpn
)

# -----------------------------------------
# DDEV
# -----------------------------------------
if brew list --formula | grep -q "^ddev\$"; then
  echo "ddev already installed"
else
  echo "Installing ddev..."
  brew install ddev/ddev/ddev
fi

# -----------------------------------------
# Lando (non-interactive official installer)
# -----------------------------------------
# -----------------------------------------
# Lando (non-interactive official installer)
# -----------------------------------------
if command -v lando &>/dev/null; then
  echo "Lando already installed"
else
  echo "Installing Lando (auto-detects Apple Silicon vs Intel)..."
  yes "" | /bin/bash -c "$(curl -fsSL https://get.lando.dev/setup-lando.sh)"
fi

# Ensure Lando is available immediately for this script
if [ -d "$HOME/.lando/bin" ]; then
  export PATH="$HOME/.lando/bin:$PATH"
fi

# Add Lando shellenv to Fish config for persistence
FISH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fish"
mkdir -p "$FISH_CONFIG_DIR"
CONFIG_FILE="$FISH_CONFIG_DIR/config.fish"

if ! grep -q "lando shellenv" "$CONFIG_FILE" 2>/dev/null; then
  cat <<'EOF' >> "$CONFIG_FILE"

# Lando environment
status is-interactive; and eval (/Users/matthewcrist/.lando/bin/lando shellenv | psub)
EOF
fi

# -----------------------------------------
# Other formulae
# -----------------------------------------
for pkg in "${FORMULAE[@]}"; do
  if brew list --formula | grep -q "^${pkg}\$"; then
    echo "$pkg already installed"
  else
    echo "Installing $pkg..."
    brew install "$pkg"
  fi
done

# -----------------------------------------
# Casks
# -----------------------------------------
for pkg in "${CASKS[@]}"; do
  if brew list --cask | grep -q "^${pkg}\$"; then
    echo "$pkg already installed"
  else
    echo "Installing $pkg..."
    brew install --cask "$pkg"
  fi
done

# -----------------------------------------
# Cursor (via official API)
# -----------------------------------------
if [ ! -d "/Applications/Cursor.app" ]; then
  echo "Installing Cursor via API..."
  TMP_JSON="/tmp/cursor_meta.json"
  TMP_FILE="/tmp/Cursor_download"

  curl -fsSL "https://cursor.com/api/download?platform=darwin-arm64&releaseTrack=stable" -o "$TMP_JSON"
  CURSOR_URL=$(grep -oE '"url":[[:space:]]*"[^"]+"' "$TMP_JSON" | sed -E 's/"url":[[:space:]]*"([^"]+)"/\1/')
  CURSOR_NAME=$(grep -oE '"name":[[:space:]]*"[^"]+"' "$TMP_JSON" | sed -E 's/"name":[[:space:]]*"([^"]+)"/\1/')

  if [ -n "$CURSOR_URL" ]; then
    echo "Downloading Cursor: $CURSOR_NAME..."
    curl -fL "$CURSOR_URL" -o "$TMP_FILE"

    EXT="${CURSOR_NAME##*.}"
    if [ "$EXT" = "zip" ]; then
      unzip -q "$TMP_FILE" -d /tmp/
      cp -R /tmp/Cursor.app /Applications/
    elif [ "$EXT" = "dmg" ]; then
      MNT_DIR=$(hdiutil attach "$TMP_FILE" -nobrowse | grep "/Volumes/" | awk '{print $3}')
      cp -R "$MNT_DIR/Cursor.app" /Applications/
      hdiutil detach "$MNT_DIR"
    fi

    rm -f "$TMP_FILE" "$TMP_JSON"
    sudo xattr -cr "/Applications/Cursor.app"
    echo "Cursor installed successfully"
  else
    echo "⚠️ Could not get Cursor download URL."
  fi
else
  echo "Cursor already installed"
fi

# -----------------------------------------
# Nerd Font
# -----------------------------------------
FONT="font-fira-code-nerd-font"
if brew list --cask | grep -q "^${FONT}\$"; then
  echo "Nerd Font already installed"
else
  echo "Installing Nerd Font..."
  brew install --cask "$FONT"
fi

# -----------------------------------------
# Fish Default Shell
# -----------------------------------------
FISH_PATH="$(brew --prefix)/bin/fish"
if ! grep -q "$FISH_PATH" /etc/shells; then
  echo "Adding Fish to /etc/shells..."
  echo "$FISH_PATH" | sudo tee -a /etc/shells
fi

if [ "$SHELL" != "$FISH_PATH" ]; then
  echo "Changing default shell to Fish..."
  chsh -s "$FISH_PATH"
else
  echo "Fish already set as default"
fi

# -----------------------------------------
# Configure Fish (Starship, Frum, FNM, Pyenv, Rust)
# -----------------------------------------
FISH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fish"
mkdir -p "$FISH_CONFIG_DIR"

# Starship
if ! grep -q "starship init fish" "$FISH_CONFIG_DIR/config.fish" 2>/dev/null; then
  cat <<'EOF' >> "$FISH_CONFIG_DIR/config.fish"

# Starship prompt setup
starship init fish | source
EOF
fi

# Frum
if ! grep -q "frum init fish" "$FISH_CONFIG_DIR/config.fish" 2>/dev/null; then
  cat <<'EOF' >> "$FISH_CONFIG_DIR/config.fish"

# Frum Ruby version manager
status is-interactive; and source (frum init fish | psub)
EOF
fi

# FNM
if ! grep -q "fnm env" "$FISH_CONFIG_DIR/config.fish" 2>/dev/null; then
  cat <<'EOF' >> "$FISH_CONFIG_DIR/config.fish"

# FNM Node.js version manager
status is-interactive; and fnm env --use-on-cd | source
EOF
fi

# Pyenv
if ! grep -q "pyenv init" "$FISH_CONFIG_DIR/config.fish" 2>/dev/null; then
  cat <<'EOF' >> "$FISH_CONFIG_DIR/config.fish"

# Pyenv Python version manager
status is-interactive; and pyenv init - | source
EOF
fi

# Rust
if ! grep -q "cargo/bin" "$FISH_CONFIG_DIR/config.fish" 2>/dev/null; then
  cat <<'EOF' >> "$FISH_CONFIG_DIR/config.fish"

# Rust setup for Fish
if test -d $HOME/.cargo/bin
    fish_add_path $HOME/.cargo/bin
end
EOF
fi

# -----------------------------------------
# Rust Installation (via rustup)
# -----------------------------------------
if ! command -v rustc &>/dev/null; then
  echo "Installing Rust via rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
else
  echo "Rust already installed"
fi

# -----------------------------------------
# Ruby build dependencies
# -----------------------------------------
echo "Installing Ruby build dependencies..."
brew install openssl@3 readline libyaml zlib gmp libffi

# -----------------------------------------
# Install latest runtimes
# -----------------------------------------

# Node.js (latest LTS, guarded)
echo "Ensuring latest LTS Node.js is installed..."
LATEST_NODE=$(fnm ls-remote | grep "Latest LTS" | awk '{print $1}' | tail -1)
if fnm ls | grep -q "$LATEST_NODE"; then
  echo "Node.js $LATEST_NODE already installed"
else
  fnm install --lts
fi
fnm default "$LATEST_NODE"

# Ruby (3.4.1 pinned, guarded)
echo "Ensuring Ruby 3.4.1 is installed..."
if frum versions | grep -q "3.4.1"; then
  echo "Ruby 3.4.1 already installed"
else
  frum install 3.4.1
fi
frum global 3.4.1

# Python (latest stable 3.x, guarded)
echo "Ensuring latest Python 3 is installed..."
LATEST_PY=$(pyenv install -l | grep -E "^\s*3\.[0-9]+\.[0-9]+$" | tail -1 | tr -d ' ')
if pyenv versions --bare | grep -q "$LATEST_PY"; then
  echo "Python $LATEST_PY already installed"
else
  pyenv install -v "$LATEST_PY"
fi
pyenv global "$LATEST_PY"

# -----------------------------------------
# Ghostty Defaults
# -----------------------------------------
GHOSTTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
mkdir -p "$GHOSTTY_DIR"

cat > "$GHOSTTY_DIR/config" <<EOF
# Ghostty default config
shell = "$FISH_PATH"
font-family = "FiraCode Nerd Font"
font-size = 14
theme = "Catppuccin-Mocha"
window-padding-x = 8
window-padding-y = 8
EOF

# -----------------------------------------
# Make Ghostty default terminal app
# -----------------------------------------
echo "Configuring Ghostty as default terminal..."
duti -s com.mitchellh.ghostty public.shell-script all
duti -s com.mitchellh.ghostty com.apple.terminal.shell-script all

# -----------------------------------------
# Sanity Checks
# -----------------------------------------
echo "🔎 Running sanity checks..."
fish --version
starship --version
frum --version
fnm --version
pyenv --version
rustc --version
ddev --version
lando version || true
[ -d "/Applications/Cursor.app" ] && echo "Cursor installed ✅" || echo "Cursor missing ⚠️"

echo "✅ Setup complete!"
echo "👉 Restart your Mac or log out/in for shell + app defaults to apply."
echo "🚀 Open Ghostty — Fish + Starship + Nerd Font + Frum + FNM + Pyenv + Rust + runtimes will be ready to go."
echo "💻 Cursor installed at /Applications/Cursor.app"
echo "🌊 Lando installed using official Apple Silicon/Intel aware installer"
