#!/bin/bash

# SwiftCMS Release Automation Script
# Usage: ./.github/release.sh

set -e

echo "🚀 SwiftCMS Release Script"
echo "=========================="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if working directory is clean
check_clean_working_directory() {
    echo "🔍 Checking working directory..."
    if ! git diff --quiet; then
        print_error "Working directory has uncommitted changes. Please commit or stash them first."
        exit 1
    fi

    if ! git diff --cached --quiet; then
        print_error "There are staged changes waiting to be committed."
        exit 1
    fi

    print_success "Working directory is clean"
}

# Prompt for version number
get_version_number() {
    echo ""
    echo "📋 Current version: $(grep -o 'version: ".*"' Package.swift | head -1 | cut -d'"' -f2)"
    read -p "Enter new version number (e.g., 1.0.0): " VERSION

    if [[ ! $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Invalid version format. Please use semantic versioning (e.g., 1.0.0)"
        exit 1
    fi
}

# Update version in Package.swift
update_package_version() {
    echo ""
    echo "📝 Updating Package.swift..."

    # Backup original file
    cp Package.swift Package.swift.bak

    # Update version using sed
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/version: \".*\"/version: \"$VERSION\"/" Package.swift
    else
        # Linux
        sed -i "s/version: ".*"/version: "$VERSION"/" Package.swift
    fi

    if grep -q "$VERSION" Package.swift; then
        print_success "Package.swift updated with version $VERSION"
    else
        print_error "Failed to update Package.swift"
        mv Package.swift.bak Package.swift
        exit 1
    fi
}

# Update CHANGELOG.md
update_changelog() {
    echo ""
    echo "📝 Updating CHANGELOG.md..."

    if [[ ! -f CHANGELOG.md ]]; then
        print_warning "CHANGELOG.md not found. Creating new one..."
        touch CHANGELOG.md
    fi

    # Backup original file
    cp CHANGELOG.md CHANGELOG.md.bak

    # Add new release entry at the top
    TEMP_FILE=$(mktemp)
    cat > "$TEMP_FILE" << EOF
## [$VERSION] - $(date +%Y-%m-%d)

### Added
- New features and improvements

### Changed
- Updated dependencies

### Fixed
- Bug fixes

### Security
- Security improvements

$(cat CHANGELOG.md)
EOF

    mv "$TEMP_FILE" CHANGELOG.md
    print_success "CHANGELOG.md updated"
}

# Run tests
run_tests() {
    echo ""
    echo "🧪 Running test suite..."

    if swift test; then
        print_success "All tests passed"
    else
        print_error "Tests failed. Aborting release."
        # Restore backups
        mv Package.swift.bak Package.swift 2>/dev/null || true
        mv CHANGELOG.md.bak CHANGELOG.md 2>/dev/null || true
        exit 1
    fi
}

# Build the project
build_project() {
    echo ""
    echo "🏗️  Building project..."

    if swift build; then
        print_success "Build successful"
    else
        print_error "Build failed. Aborting release."
        # Restore backups
        mv Package.swift.bak Package.swift 2>/dev/null || true
        mv CHANGELOG.md.bak CHANGELOG.md 2>/dev/null || true
        exit 1
    fi
}

# Create git tag
create_git_tag() {
    echo ""
    echo "🏷️  Creating git tag..."

    git add Package.swift CHANGELOG.md
    git commit -m "chore: release version $VERSION"

git tag -a "v$VERSION" -m "Release version $VERSION"

    print_success "Git tag v$VERSION created"
}

# Build Docker image
build_docker_image() {
    echo ""
    echo "🐳 Building Docker image..."

    if command -v docker &> /dev/null; then
        docker build -t "swiftcms:$VERSION" .
        docker tag "swiftcms:$VERSION" "swiftcms:latest"
        print_success "Docker image built: swiftcms:$VERSION"
    else
        print_warning "Docker not found. Skipping Docker build."
    fi
}

# Push to git remote
push_to_remote() {
    echo ""
    echo "☁️  Pushing to remote..."

    read -p "Push to origin? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git push origin "v$VERSION"
        git push origin main  # or your main branch name
        print_success "Pushed to remote"
    else
        print_warning "Skipping git push"
    fi
}

# Push Docker image
push_docker_image() {
    if command -v docker &> /dev/null; then
        echo ""
        read -p "Push Docker image to registry? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "📤 Pushing Docker image..."
            docker push "swiftcms:$VERSION"
            docker push "swiftcms:latest"
            print_success "Docker image pushed"
        else
            print_warning "Skipping Docker push"
        fi
    fi
}

# Main execution
main() {
    check_clean_working_directory
    get_version_number

    echo ""
    echo "📊 Release Summary:"
    echo "=================="
    echo "Version: $VERSION"
    echo "Package update: Yes"
    echo "Changelog update: Yes"
    echo "Tests: Will run"
    echo "Docker build: Yes (if Docker available)"
    echo ""

    read -p "Proceed with release? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Release cancelled"
        exit 0
    fi

    update_package_version
    update_changelog
    run_tests
    build_project
    create_git_tag
    build_docker_image
    push_to_remote
    push_docker_image

    # Clean up backups
    rm -f Package.swift.bak CHANGELOG.md.bak

    echo ""
    print_success "🎉 Release $VERSION completed successfully!"
    echo ""
    echo "Next steps:"
    echo "- Verify the release on GitHub"
    echo "- Update documentation if needed"
    echo "- Announce the release"
}

# Run main function
main
