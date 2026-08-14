SHELL := /usr/bin/env bash

.PHONY: help install-deps install start stop restart status health doctor set-vnc-password validate lint test

help:
	@echo "Hermes Shared Browser targets"
	@echo ""
	@echo "  make install-deps       Install Debian/Ubuntu package dependencies"
	@echo "  make install            Install systemd user units and generate config"
	@echo "  make start              Enable and start all services"
	@echo "  make stop               Stop all services"
	@echo "  make restart            Restart all services"
	@echo "  make status             Show systemd service status"
	@echo "  make health             Run health/security checks"
	@echo "  make doctor             Alias for health"
	@echo "  make set-vnc-password   Prompt for a VNC password (required before start)"
	@echo "  make lint               bash -n + shellcheck"
	@echo "  make test               Run automated tests"
	@echo "  make validate           lint + test (+ systemd-analyze if available)"

install-deps:
	bash ./scripts/install-debian-packages.sh

install:
	bash ./scripts/install-systemd-user.sh

start:
	systemctl --user enable --now hermes-browser-xvfb.service
	systemctl --user enable --now hermes-browser-chromium.service
	systemctl --user enable --now hermes-browser-vnc.service
	systemctl --user enable --now hermes-browser-novnc.service

stop:
	-systemctl --user stop hermes-browser-novnc.service hermes-browser-vnc.service hermes-browser-chromium.service hermes-browser-xvfb.service

restart:
	systemctl --user restart hermes-browser-xvfb.service
	systemctl --user restart hermes-browser-chromium.service
	systemctl --user restart hermes-browser-vnc.service
	systemctl --user restart hermes-browser-novnc.service

status:
	systemctl --user --no-pager --lines=30 status hermes-browser-xvfb.service hermes-browser-chromium.service hermes-browser-vnc.service hermes-browser-novnc.service

health doctor:
	bash ./scripts/check-health.sh

set-vnc-password:
	bash ./scripts/set-vnc-password.sh

lint:
	bash -n scripts/*.sh tests/*.sh
	@if command -v shellcheck >/dev/null 2>&1; then \
	  shellcheck -x -e SC1091 scripts/*.sh tests/*.sh; \
	else \
	  echo "note: shellcheck not installed; skipped (CI installs it)"; \
	fi

test:
	bash ./tests/run.sh

validate: lint test
	@if command -v systemd-analyze >/dev/null 2>&1; then \
	  systemd-analyze --user verify systemd/user/*.service || \
	    echo "note: systemd-analyze --user verify reported issues (may need a user session)"; \
	else \
	  echo "note: systemd-analyze not available; skipped"; \
	fi
