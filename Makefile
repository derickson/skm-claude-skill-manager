BIN_DIR := $(HOME)/.local/bin
SCRIPT   := $(abspath skill_manager.py)
LINK     := $(BIN_DIR)/skill-manager

.PHONY: install uninstall

install:
	mkdir -p $(BIN_DIR)
	ln -sf $(SCRIPT) $(LINK)
	@echo "Installed: $(LINK) -> $(SCRIPT)"
	@echo "Make sure $(BIN_DIR) is on your PATH."

uninstall:
	rm -f $(LINK)
	@echo "Removed: $(LINK)"
