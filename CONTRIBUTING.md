# Contributing Guide

Thank you for your interest in contributing to CppExec!

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and harassment-free environment for everyone participating in our project and community.

### Our Standards

Behaviors that contribute to a positive environment include:

- Using welcoming and inclusive language
- Respecting differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

## How to Contribute

### Reporting Issues

1. Search existing issues before submitting a new one
2. Use a clear and descriptive title
3. Provide steps to reproduce the issue
4. Include screenshots if applicable
5. Describe your environment (OS, Docker version, etc.)

### Submitting Code

#### Setting Up Development Environment

```bash
# Clone the repository
git clone https://github.com/yourusername/CppExec.git
cd CppExec

# Build Docker image
docker build -t cpp-exec:dev .

# Start development container
docker run -d -p 4002:4002 -v $(pwd):/app --name cpp-exec-dev cpp-exec:dev
```

#### Pull Request Process

1. Fork the project
2. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Commit your changes:
   ```bash
   git commit -m "Add some feature"
   ```
   - Commit messages should clearly describe the changes
4. Push to the branch:
   ```bash
   git push origin feature/your-feature-name
   ```
5. Open a Pull Request

#### Coding Standards

**C++ Code Standards**

- Follow C++11 or later standards
- Use 4-space indentation
- Variable names: snake_case
- Function names: camelCase
- Class names: PascalCase
- Keep code concise, avoid unnecessary nesting
- Add comments for complex logic

**Python Code Standards**

- Follow PEP 8 guidelines
- Use 4-space indentation
- Variable and function names: snake_case
- Class names: PascalCase
- Organize imports: standard library, third-party, local
- Use type hints

**Dockerfile Standards**

- Use official base images
- Minimize image layers (combine RUN commands)
- Use --no-cache-dir to avoid caching
- Order commands: install dependencies -> copy files -> build -> cleanup
- Use .dockerignore to exclude unnecessary files

### Documentation Contributions

- Improve README.md
- Add usage examples
- Enhance API documentation
- Translate documentation

## License

By contributing code, you agree that your contributions will be licensed under the MIT License.

## Questions?

If you have any questions, please contact us:

- Submit an Issue
- Email: cobola@gmail.com

Thank you for contributing!
