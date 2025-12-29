.PHONY: build release test run clean help install uninstall

# デフォルトターゲット
.DEFAULT_GOAL := help

# 変数
BINARY_NAME := ptp-tool
INSTALL_PATH := /usr/local/bin
BUILD_DIR := .build

# ビルド（デバッグ）
build:
	swift build

# リリースビルド
release:
	swift build -c release

# テスト実行
test:
	swift test

# 実行（引数は ARGS で渡す: make run ARGS="list"）
run:
	swift run $(BINARY_NAME) $(ARGS)

# クリーン
clean:
	swift package clean
	rm -rf $(BUILD_DIR)

# リリースビルドをインストール
install: release
	cp $(BUILD_DIR)/release/$(BINARY_NAME) $(INSTALL_PATH)/$(BINARY_NAME)
	@echo "Installed $(BINARY_NAME) to $(INSTALL_PATH)"

# アンインストール
uninstall:
	rm -f $(INSTALL_PATH)/$(BINARY_NAME)
	@echo "Uninstalled $(BINARY_NAME) from $(INSTALL_PATH)"

# 依存関係を更新
update:
	swift package update

# 依存関係を解決
resolve:
	swift package resolve

# Package.swift を表示
dump:
	swift package dump-package

# ヘルプ
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build     デバッグビルド"
	@echo "  release   リリースビルド"
	@echo "  test      テスト実行"
	@echo "  run       実行 (例: make run ARGS=\"list\")"
	@echo "  clean     ビルド成果物を削除"
	@echo "  install   リリースビルドをインストール"
	@echo "  uninstall アンインストール"
	@echo "  update    依存関係を更新"
	@echo "  resolve   依存関係を解決"
	@echo "  dump      Package.swift を表示"
	@echo "  help      このヘルプを表示"
