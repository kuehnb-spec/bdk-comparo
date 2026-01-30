#!/bin/bash
# Build script for BDK Comparo app

echo "Building BDK Comparo..."
swiftc -parse-as-library -o BDKComparo BDKComparo.swift -framework SwiftUI -framework AppKit

if [ $? -eq 0 ]; then
    echo "Build successful!"
    echo "Run with: ./BDKComparo"
else
    echo "Build failed!"
    exit 1
fi
