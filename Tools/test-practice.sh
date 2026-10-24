#!/bin/sh
set -e
cd "$(dirname "$0")/.."
mkdir -p .build
swiftc -parse-as-library -module-cache-path .build/module-cache -o .build/practice-tests \
  Tsumesho/Engine/Shogi.swift Tsumesho/Engine/Problem.swift Tsumesho/PlayMode.swift \
  Tsumesho/PracticeLibrary.swift Tsumesho/Game.swift Tools/PracticeTests/main.swift
.build/practice-tests
