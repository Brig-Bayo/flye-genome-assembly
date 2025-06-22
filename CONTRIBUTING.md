# Contributing to Flye Genome Assembly Pipeline

Thank you for your interest in contributing to the Flye Genome Assembly Pipeline! This document provides guidelines for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Bug Reports](#bug-reports)
- [Feature Requests](#feature-requests)

## Code of Conduct

This project adheres to a Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

### Our Pledge

- Be respectful and inclusive
- Focus on constructive feedback
- Help create a welcoming environment for all contributors
- Respect differing viewpoints and experiences

## Getting Started

### Prerequisites

- Git
- Conda or Miniconda
- Basic knowledge of Bash scripting
- Basic knowledge of Python (for Python components)
- Understanding of bioinformatics workflows

### Development Setup

1. **Fork the repository**
   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/yourusername/flye-genome-assembly.git
   cd flye-genome-assembly
   ```

2. **Set up development environment**
   ```bash
   make setup-dev
   conda activate flye-assembly
   ```

3. **Verify installation**
   ```bash
   make check-deps
   make test
   ```

## Making Changes

### Branch Strategy

- `main`: Stable, production-ready code
- `develop`: Integration branch for new features
- Feature branches: `feature/your-feature-name`
- Bugfix branches: `bugfix/issue-description`

### Workflow

1. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Follow coding standards
   - Add tests for new functionality
   - Update documentation

3. **Test your changes**
   ```bash
   make lint
   make test
   ```

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add new feature description"
   ```

5. **Push and create PR**
   ```bash
   git push origin feature/your-feature-name
   # Create pull request on GitHub
   ```

## Coding Standards

### Shell Scripts

- Use `bash` as the shebang (`#!/bin/bash`)
- Set strict error handling: `set -euo pipefail`
- Use meaningful variable names in `UPPER_CASE`
- Include comprehensive help documentation
- Add colored output for better user experience
- Include progress indicators for long-running operations

**Example:**
```bash
#!/bin/bash
set -euo pipefail

# Good variable naming
INPUT_FILE=""
OUTPUT_DIR=""
THREAD_COUNT=$(nproc)

# Good function structure
validate_input() {
    if [[ ! -f "$INPUT_FILE" ]]; then
        print_error "Input file not found: $INPUT_FILE"
        exit 1
    fi
}
```

### Python Scripts

- Follow PEP 8 style guide
- Use type hints where appropriate
- Include comprehensive docstrings
- Handle errors gracefully
- Use logging instead of print for debug information

**Example:**
```python
#!/usr/bin/env python3
"""
Module docstring describing the purpose.
"""

import argparse
import logging
from pathlib import Path
from typing import List, Optional

def process_assembly(assembly_path: Path, output_dir: Optional[Path] = None) -> List[str]:
    """
    Process assembly file and return statistics.
    
    Args:
        assembly_path: Path to assembly FASTA file
        output_dir: Optional output directory
        
    Returns:
        List of statistics strings
        
    Raises:
        FileNotFoundError: If assembly file doesn't exist
    """
    if not assembly_path.exists():
        raise FileNotFoundError(f"Assembly file not found: {assembly_path}")
    
    # Implementation here
    return []
```

### Documentation

- Use clear, concise language
- Include examples for all major functions
- Update README.md for new features
- Document all command-line options
- Include troubleshooting sections

## Testing

### Test Requirements

- All new functionality must include tests
- Tests should cover both success and failure cases
- Use realistic test data when possible
- Tests should run quickly (< 5 minutes total)

### Running Tests

```bash
# Run all tests
make test

# Run specific tests
make lint              # Code quality checks
make check-deps        # Dependency verification
make create-test-data  # Generate test datasets
```

### Test Structure

- Place test scripts in `tests/` directory
- Use descriptive test names
- Include both unit tests and integration tests
- Test with different data types and edge cases

### Adding New Tests

1. Create test data:
   ```bash
   # Add to create-test-data target in Makefile
   # or create in tests/fixtures/
   ```

2. Write test script:
   ```bash
   # tests/test_new_feature.sh
   #!/bin/bash
   
   test_new_feature() {
       # Test implementation
       ./scripts/new_script.sh -i test_input -o test_output
       
       # Verify results
       [[ -f test_output ]] || { echo "FAIL: Output not created"; exit 1; }
       echo "PASS: New feature test"
   }
   ```

3. Add to main test suite in Makefile

## Submitting Changes

### Pull Request Process

1. **Ensure tests pass**
   ```bash
   make lint
   make test
   ```

2. **Update documentation**
   - Update README.md if needed
   - Update help text in scripts
   - Add/update examples

3. **Create descriptive PR**
   - Clear title summarizing the change
   - Detailed description of what was changed
   - Reference any related issues
   - Include testing notes

### Commit Message Format

Use conventional commit format:

```
type(scope): description

body (optional)

footer (optional)
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(assembly): add support for PacBio HiFi reads

- Add pacbio-hifi option to read type selection
- Update polishing pipeline for HiFi data
- Add HiFi-specific quality thresholds

Closes #123
```

## Bug Reports

### Before Submitting

1. Check existing issues
2. Try the latest version
3. Gather system information
4. Create minimal reproduction case

### Bug Report Template

```markdown
**Bug Description**
Clear description of the bug

**To Reproduce**
Steps to reproduce the behavior:
1. Run command '...'
2. With input file '...'
3. See error

**Expected Behavior**
What you expected to happen

**Environment**
- OS: [e.g., Ubuntu 20.04]
- Conda environment: [output of `conda list`]
- Script version: [e.g., git commit hash]

**Additional Context**
- Log files
- Input data characteristics
- Error messages
```

## Feature Requests

### Before Submitting

1. Check if feature already exists
2. Review existing feature requests
3. Consider if it fits project scope
4. Think about implementation complexity

### Feature Request Template

```markdown
**Feature Description**
Clear description of the proposed feature

**Motivation**
Why is this feature needed?

**Proposed Solution**
How should this feature work?

**Alternatives Considered**
Other approaches you've considered

**Implementation Notes**
Technical considerations or suggestions
```

## Release Process

### Version Numbering

We use semantic versioning (MAJOR.MINOR.PATCH):
- MAJOR: Incompatible API changes
- MINOR: New functionality (backward compatible)
- PATCH: Bug fixes (backward compatible)

### Release Checklist

1. Update version numbers
2. Update CHANGELOG.md
3. Run full test suite
4. Update documentation
5. Create release tag
6. Update installation instructions

## Getting Help

### Resources

- Documentation: README.md and inline help
- Examples: `config/` directory and Makefile targets
- Issues: GitHub issue tracker
- Discussions: GitHub discussions

### Contact

- Open an issue for bugs or feature requests
- Start a discussion for questions or ideas
- Email maintainers for security issues

## Recognition

Contributors are recognized in:
- Git commit history
- CONTRIBUTORS.md file
- Release notes for significant contributions

Thank you for contributing to make genome assembly more accessible and reliable!
