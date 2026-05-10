# Contributing to lua-gdpr-iab-tcfv2

Patches are welcome! This project enforces strict code quality and formatting standards via CI.

## Prerequisites

Before you start, ensure you have the following installed:

1.  **Lua (5.1, 5.2, 5.3, 5.4, or LuaJIT)**:
    - Ubuntu: `sudo apt install lua5.4`
    - macOS: `brew install lua`
2.  **LuaRocks**:
    - Ubuntu: `sudo apt install luarocks`
    - macOS: `brew install luarocks`
3.  **StyLua** (Code Formatter):
    - StyLua is a Rust-based tool and is **not** available via LuaRocks.
    - **Installation**:
        - **macOS**: `brew install stylua`
        - **Rust/Cargo**: `cargo install stylua`
        - **Linux (Manual)**: Download the latest binary from the [StyLua Releases](https://github.com/JohnnyMorganz/StyLua/releases) page, unzip it, and move it to your `/usr/local/bin/`.
        - **GitHub Action**: Handled automatically in CI.

## Development Workflow

### 1. Setup Local Environment
Initialize the local dependencies folder (`.rocks/`):
```bash
make setup
```
This installs `busted`, `luacheck`, and `luacov` locally. The `Makefile` will automatically detect and use this folder.

### 2. Branching Strategy (Gitflow)
- **`devel`**: Main development branch. **Never** commit directly.
- **`main`**: Production branch. Tagged releases only.
- Always create a branch for your work:
  ```bash
  git checkout devel
  git pull origin devel
  git checkout -b feat/my-new-feature
  ```

### 3. Implement and Validate
This project uses two main orchestration targets in the `Makefile`:

- **`make task`**: Use this during active development. It will **format** your code, run the **linter**, and execute the **tests**.
- **`make ci`**: Use this to simulate what happens in GitHub Actions. It **verifies** formatting (fails if incorrect), runs the **linter**, and executes the **tests** with coverage.

### 4. Committing and Pushing
- Use **Conventional Commits** (`feat:`, `fix:`, `docs:`, etc.).
- Ensure `make ci` passes before pushing.
- Open a Pull Request against `devel` and assign it to @peczenyj.

## Tooling Reference

- `make setup`: Initialize local LuaRocks dependencies.
- `make test`: Run the test suite (Busted).
- `make lint`: Run the linter (Luacheck).
- `make format`: Apply code formatting (StyLua).
- `make check-format`: Verify code formatting without changing files.
- `make coverage`: Generate a coverage report (Luacov).
- `make ci`: Run all quality checks (used by GitHub Actions).
- `make task`: Run development cycle (Format + Lint + Test).

## License
By contributing, you agree that your contributions will be licensed under the MIT License.
