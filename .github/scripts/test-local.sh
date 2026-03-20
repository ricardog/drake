#!/bin/bash
# Script to help with local testing of drake

echo "Setting up local test environment..."

# Install dependencies (Ubuntu/Debian)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    sudo apt-get update
    sudo apt-get install -y libgtk-3-dev libx11-dev libxpm-dev libjpeg-dev libpng-dev libgif-dev libtiff-dev libncurses-dev libxft-dev libxaw7-dev libxext-dev libxt-dev pkg-config libgccjit-dev curl clang cmake gnuplot
fi

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"

# Build the Rust module
cd rust
cargo build --release
cp target/release/libdrake_rust_module.so ../drake-rust-module.so
cd ..

# Build and run tests with CMake
mkdir -p build
cd build
cmake ..
make
make check
cd ..

echo "Local testing complete!"