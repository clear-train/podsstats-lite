SHELL := /bin/bash
BIN   := .build/release/podsstat
MOCK  := samples/mock_export.xml

.PHONY: all build install demo report mock clean test web shots

all: build

build:
	swift build -c release

mock: build
	$(BIN) --mock $(MOCK) --days 45

demo: build mock
	$(BIN) $(MOCK) --tz +08:00

report: build mock
	$(BIN) $(MOCK) --tz +08:00 --html samples/report.html --open

install: build
	install -m 755 $(BIN) /usr/local/bin/podsstat
	@echo "已安装：$$(which podsstat)"

test: build mock
	@bash scripts/verify.sh

# 生成网页版（GitHub Pages 入口）
web: build
	$(BIN) --web docs/index.html

# 用无头 Chrome 重出网页版截图（需要本机装了 Chrome）
shots: web
	@bash scripts/shots.sh

clean:
	rm -rf .build
	rm -f docs/index.html
