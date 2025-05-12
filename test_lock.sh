#!/bin/bash

# Script to test FileLock implementation in Swiftly
echo "Testing FileLock implementation with concurrent installs"

# Function to run swiftly install in background
run_install() {
    local version=$1
    echo "Starting install of Swift $version..."
    
    # Run install and capture exit code
    .build/debug/swiftly install $version
    local exit_code=$?
    
    if [ $exit_code -eq 42 ]; then
        echo "Install of Swift $version exited with code 42 (lock acquisition failure)"
    elif [ $exit_code -eq 0 ]; then
        echo "Install of Swift $version completed successfully"
    else
        echo "Install of Swift $version failed with exit code $exit_code"
    fi
}

# Run two installs concurrently
run_install "5.2" &
pid1=$!
sleep 0.5  # Small delay to ensure the first process has a chance to acquire the lock

run_install "5.1" &
pid2=$!

# Wait for both processes to complete
wait $pid1
wait $pid2

echo "Test completed"