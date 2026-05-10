# Contributing to lua-gdpr-iab-tcfv2

Patches are welcome! Please follow these guidelines to ensure a smooth contribution process.

## Branching Strategy (Gitflow)

- **`devel`**: Main development branch. **Never commit directly.**
- **`main`**: Production/Release branch.
- **Workflow**: Always create a feature branch (`feat/*`) or bugfix branch (`fix/*`) from `devel`.

## Development Workflow

1.  **Fork and Clone**: Fork the repository and clone it locally.
2.  **Technical Setup**: Follow the instructions in [DEVELOPMENT.md](DEVELOPMENT.md) to install dependencies and initialize the environment.
3.  **Implement and Test**: Make your changes. Ensure you add or update tests in `test/`.
4.  **Validate**: Run `make task` during development to format, lint, and test.
5.  **Commit**: Use Conventional Commits (`type(scope): description`).
6.  **Push and PR**: Push to your fork and open a Pull Request against `devel`. Assign the PR to @peczenyj.

## Code Quality

This project enforces strict formatting (StyLua) and linting (Luacheck) via CI. PRs that do not pass `make ci` will not be merged.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
