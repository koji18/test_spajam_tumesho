#!/bin/sh
# ルールエンジンと問題のテストを実行する
set -e
cd "$(dirname "$0")/.."
mkdir -p .build
swiftc -O -o .build/engine-tests Tsumesho/Engine/Shogi.swift Tsumesho/Engine/Problem.swift Tsumesho/Engine/Generator.swift Tools/EngineTests/main.swift
.build/engine-tests
