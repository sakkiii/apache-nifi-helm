#!/bin/bash

# 🚀 Apache NiFi Helm Chart Release Script
# This script helps with local development and testing before releases

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        log_error "Helm is not installed. Please install Helm 3.8+ first."
        exit 1
    fi
    
    # Check helm version
    HELM_VERSION=$(helm version --short | cut -d'+' -f1 | cut -d'v' -f2)
    log_info "Helm version: $HELM_VERSION"
    
    # Check if yq is installed
    if ! command -v yq &> /dev/null; then
        log_warning "yq is not installed. Some features may not work."
    fi
    
    # Check if we're in the right directory
    if [ ! -f "Chart.yaml" ]; then
        log_error "Chart.yaml not found. Please run this script from the chart root directory."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Get current chart information
get_chart_info() {
    CHART_NAME=$(yq eval '.name' Chart.yaml 2>/dev/null || grep '^name:' Chart.yaml | cut -d' ' -f2)
    CHART_VERSION=$(yq eval '.version' Chart.yaml 2>/dev/null || grep '^version:' Chart.yaml | cut -d' ' -f2)
    APP_VERSION=$(yq eval '.appVersion' Chart.yaml 2>/dev/null || grep '^appVersion:' Chart.yaml | cut -d' ' -f2 | tr -d '"')
    
    log_info "Chart: $CHART_NAME"
    log_info "Chart Version: $CHART_VERSION"
    log_info "App Version: $APP_VERSION"
}

# Lint the chart
lint_chart() {
    log_info "Linting Helm chart..."
    
    if helm lint .; then
        log_success "Chart linting passed"
    else
        log_error "Chart linting failed"
        exit 1
    fi
}

# Update dependencies
update_dependencies() {
    log_info "Updating Helm dependencies..."
    
    if helm dependency update; then
        log_success "Dependencies updated successfully"
    else
        log_error "Failed to update dependencies"
        exit 1
    fi
}

# Template validation
validate_templates() {
    log_info "Validating Helm templates..."
    
    # Test default values
    if helm template test-release . --debug > /dev/null 2>&1; then
        log_success "Default template validation passed"
    else
        log_error "Default template validation failed"
        helm template test-release . --debug
        exit 1
    fi
    
    # Test example values files
    if [ -d "examples" ]; then
        for values_file in examples/values-*.yaml; do
            if [ -f "$values_file" ]; then
                log_info "Testing template with $values_file"
                if helm template test-release . -f "$values_file" --debug > /dev/null 2>&1; then
                    log_success "Template validation passed for $values_file"
                else
                    log_error "Template validation failed for $values_file"
                    helm template test-release . -f "$values_file" --debug
                    exit 1
                fi
            fi
        done
    fi
}

# Package the chart
package_chart() {
    log_info "Packaging Helm chart..."
    
    mkdir -p dist
    
    if helm package . -d dist/; then
        PACKAGE_FILE="dist/${CHART_NAME}-${CHART_VERSION}.tgz"
        log_success "Chart packaged: $PACKAGE_FILE"
        
        # Show package info
        log_info "Package size: $(du -h "$PACKAGE_FILE" | cut -f1)"
        log_info "Package contents:"
        tar -tzf "$PACKAGE_FILE" | head -10
        if [ $(tar -tzf "$PACKAGE_FILE" | wc -l) -gt 10 ]; then
            echo "... and $(( $(tar -tzf "$PACKAGE_FILE" | wc -l) - 10 )) more files"
        fi
    else
        log_error "Failed to package chart"
        exit 1
    fi
}

# Generate index
generate_index() {
    log_info "Generating Helm repository index..."
    
    if [ -d "dist" ] && [ -n "$(ls -A dist/*.tgz 2>/dev/null)" ]; then
        helm repo index dist/ --url "https://sakkiii.github.io/apache-nifi-helm"
        log_success "Repository index generated"
    else
        log_warning "No packages found in dist/ directory"
    fi
}

# Test installation (dry-run)
test_install() {
    log_info "Testing chart installation (dry-run)..."
    
    if helm install test-release . --dry-run --debug > /dev/null 2>&1; then
        log_success "Dry-run installation test passed"
    else
        log_error "Dry-run installation test failed"
        helm install test-release . --dry-run --debug
        exit 1
    fi
}

# Security scan (if available)
security_scan() {
    log_info "Running security scans..."
    
    # Check if kubesec is available
    if command -v kubesec &> /dev/null; then
        log_info "Running kubesec scan..."
        helm template test-release . | kubesec scan -
    else
        log_warning "kubesec not found, skipping security scan"
    fi
    
    # Check if checkov is available
    if command -v checkov &> /dev/null; then
        log_info "Running checkov scan..."
        checkov -d . --framework kubernetes --quiet
    else
        log_warning "checkov not found, skipping security scan"
    fi
}

# Show usage
show_usage() {
    echo "🚀 Apache NiFi Helm Chart Release Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  check       Check prerequisites and chart info"
    echo "  lint        Lint the Helm chart"
    echo "  deps        Update Helm dependencies"
    echo "  validate    Validate Helm templates"
    echo "  package     Package the Helm chart"
    echo "  index       Generate repository index"
    echo "  test        Test chart installation (dry-run)"
    echo "  security    Run security scans"
    echo "  all         Run all checks and package"
    echo "  clean       Clean build artifacts"
    echo ""
    echo "Examples:"
    echo "  $0 all              # Run complete validation and packaging"
    echo "  $0 lint validate    # Run linting and validation only"
    echo "  $0 package          # Package the chart"
}

# Clean build artifacts
clean_artifacts() {
    log_info "Cleaning build artifacts..."
    
    rm -rf dist/
    rm -rf charts/*.tgz
    rm -f Chart.lock
    
    log_success "Build artifacts cleaned"
}

# Main execution
main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 0
    fi
    
    check_prerequisites
    get_chart_info
    
    for cmd in "$@"; do
        case $cmd in
            check)
                log_info "Chart information already displayed"
                ;;
            lint)
                lint_chart
                ;;
            deps)
                update_dependencies
                ;;
            validate)
                validate_templates
                ;;
            package)
                package_chart
                ;;
            index)
                generate_index
                ;;
            test)
                test_install
                ;;
            security)
                security_scan
                ;;
            all)
                lint_chart
                update_dependencies
                validate_templates
                test_install
                security_scan
                package_chart
                generate_index
                log_success "All checks completed successfully! 🎉"
                ;;
            clean)
                clean_artifacts
                ;;
            *)
                log_error "Unknown command: $cmd"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Run main function with all arguments
main "$@"
