#!/bin/sh
# 問題を生成して Tsumesho/Engine/Problems.swift に書き出す
set -e
cd "$(dirname "$0")/.."
mkdir -p .build
swiftc -O -o .build/gen-problems Tsumesho/Engine/Shogi.swift Tools/GenProblems/main.swift
.build/gen-problems Tsumesho/Engine/Problems.swift
