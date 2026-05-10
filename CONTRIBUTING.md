# Contributing to lua-gdpr-iab-tcfv2

Patches are welcome! Please follow these guidelines to ensure a smooth contribution process.

## Branching Strategy (Gitflow)

This project follows a Gitflow-like branching model:

- **`devel`**: The main development branch. All feature branches (`feat/*`) and bugfix branches (`fix/*`) should be branched from and merged into `devel`.
- **`main`**: The production branch. It contains only tagged releases. Merges to `main` come from `devel` or `hotfix/*` branches.

## Development Workflow

1.  **Fork and Clone**: Fork the repository on GitHub and clone it locally.
2.  **Setup Dependencies**: Ensure you have `luarocks` installed.
    - **Ubuntu/Debian**: `sudo apt install luarocks`
    - **macOS**: `brew install luarocks`
    - **Others**: See [luarocks.org](https://luarocks.org/)

    Then initialize the local environment:
    ```bash
    make setup
    # Follow the instructions printed by make setup to update your PATH and LUA_PATH
    ```
3.  **Create a Branch**: Branch off from `devel`.
    ```bash
    git checkout devel
    git pull origin devel
    git checkout -b feat/my-new-feature
    ```
4.  **Implement and Test**: Make your changes. Ensure you add tests in `test/` (using Busted).
5.  **Lint and Format**: Before committing, run the linter and formatter.
    ```bash
    make lint
    make format
    ```
6.  **Commit**: Use Conventional Commits (`type(scope): description`).
    ```bash
    git commit -m "feat(parser): add support for new segment"
    ```
7.  **Push and PR**: Push your branch to your fork and open a Pull Request against the `devel` branch.

## Tooling

This project uses a `Makefile` to orchestrate development tasks:

- `make setup`: Install development dependencies locally via LuaRocks.
- `make test`: Run the test suite (requires Busted).
- `make lint`: Check code quality (requires Luacheck).
- `make format`: Format code (requires StyLua).
- `make coverage`: Generate a coverage report (requires Luacov).

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
