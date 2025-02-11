default:
  @just --list
# run tests with coverage
test:
  codecrafters test

# build application
build:
  zig build

run: 
  zig build run


