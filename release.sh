#!/bin/bash
# release.sh - A script to update versions and create a release tag

# Check if a version argument was provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 0.4.0"
  exit 1
fi

VERSION=$1

# Validate version format (simple semver check)
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: Version must be in format X.Y.Z (e.g., 0.4.0)"
  exit 1
fi

echo "Updating to version $VERSION..."

# Update version in mix.exs
sed -i.bak "s/version: \"[0-9]*\.[0-9]*\.[0-9]*\"/version: \"$VERSION\"/" mix.exs
rm mix.exs.bak

# Update version and appVersion in Chart.yaml
sed -i.bak "s/version: [0-9]*\.[0-9]*\.[0-9]*/version: $VERSION/" chart/Chart.yaml
sed -i.bak "s/appVersion: \"[0-9]*\.[0-9]*\.[0-9]*\"/appVersion: \"$VERSION\"/" chart/Chart.yaml
rm chart/Chart.yaml.bak

# Commit the changes
git add mix.exs chart/Chart.yaml
git commit -m "Release version $VERSION"

# Create and push the tag
git tag -a "v$VERSION" -m "Release version $VERSION"
git push origin main
git push origin "v$VERSION"

echo "✅ Version $VERSION has been released!"
echo "The Docker image will be built and tagged as :latest and :$VERSION"