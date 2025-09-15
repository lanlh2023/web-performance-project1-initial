#!/bin/bash

# Demo script for Jenkins pipeline testing
echo "🧪 Jenkins Pipeline Demo"
echo "========================"

case "$1" in
    "lint-error")
        echo "❌ Creating LINT error..."
        # This will create a performance issue that ESLint should catch
        sed -i '' 's|//.*Simulate heavy operation|    // Simulate heavy operation|' js/products.js 2>/dev/null || true
        echo "✅ Lint error created. Run 'npm run lint' to see the error."
        ;;
    "fix-lint")
        echo "✅ Fixing LINT error..."
        sed -i '' 's|    // Simulate heavy operation|//     // Simulate heavy operation|' js/products.js 2>/dev/null || true
        echo "✅ Lint error fixed."
        ;;
    "test-error")
        echo "❌ Creating TEST error..."
        sed -i '' 's|let vat = 20|let vat = 200|' js/main.js
        echo "✅ Test error created. VAT changed to 200. Tests will fail."
        ;;
    "fix-test")
        echo "✅ Fixing TEST error..."
        sed -i '' 's|let vat = 200|let vat = 20|' js/main.js
        echo "✅ Test error fixed. VAT changed back to 20."
        ;;
    "status")
        echo "📋 Current status:"
        echo "VAT value:"
        grep "let vat" js/main.js
        echo ""
        echo "Running tests..."
        npm run test:ci
        ;;
    *)
        echo "Usage: $0 {lint-error|fix-lint|test-error|fix-test|status}"
        echo ""
        echo "Examples:"
        echo "  $0 lint-error   # Create lint error"
        echo "  $0 fix-lint     # Fix lint error"  
        echo "  $0 test-error   # Create test error"
        echo "  $0 fix-test     # Fix test error"
        echo "  $0 status       # Show current status"
        ;;
esac