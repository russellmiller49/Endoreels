#!/bin/bash

# EndoReels Video Processing Debug Script
# This script helps you test the video processing fixes and debug NaN issues

echo "🎬 EndoReels Video Processing Debug Helper"
echo "=========================================="

# Get the bundle ID from the project
BUNDLE_ID=$(grep -o 'PRODUCT_BUNDLE_IDENTIFIER = [^;]*' EndoReels.xcodeproj/project.pbxproj | head -1 | cut -d' ' -f3)
echo "📱 Bundle ID: $BUNDLE_ID"

echo ""
echo "🔧 Available Commands:"
echo "1. Enable passthrough mode (bypass custom compositor)"
echo "2. Disable passthrough mode (use custom compositor)"
echo "3. Enable Core Graphics NaN backtrace"
echo "4. Disable Core Graphics NaN backtrace"
echo "5. Show current settings"
echo "6. Run full test sequence"

read -p "Choose an option (1-6): " choice

case $choice in
    1)
        echo "🎛️ Enabling passthrough mode..."
        defaults write $BUNDLE_ID EndoEditForcePassthrough -bool YES
        echo "✅ Passthrough mode enabled. Custom compositor will be bypassed."
        ;;
    2)
        echo "🎛️ Disabling passthrough mode..."
        defaults write $BUNDLE_ID EndoEditForcePassthrough -bool NO
        echo "✅ Passthrough mode disabled. Custom compositor will be used."
        ;;
    3)
        echo "🔍 Enabling Core Graphics NaN backtrace..."
        defaults write $BUNDLE_ID CG_NUMERICS_SHOW_BACKTRACE -bool YES
        echo "✅ NaN backtrace enabled. You'll see stack traces for NaN errors."
        ;;
    4)
        echo "🔍 Disabling Core Graphics NaN backtrace..."
        defaults write $BUNDLE_ID CG_NUMERICS_SHOW_BACKTRACE -bool NO
        echo "✅ NaN backtrace disabled."
        ;;
    5)
        echo "📊 Current Settings:"
        PASSTHROUGH=$(defaults read $BUNDLE_ID EndoEditForcePassthrough 2>/dev/null || echo "not set")
        BACKTRACE=$(defaults read $BUNDLE_ID CG_NUMERICS_SHOW_BACKTRACE 2>/dev/null || echo "not set")
        echo "   Passthrough Mode: $PASSTHROUGH"
        echo "   NaN Backtrace: $BACKTRACE"
        ;;
    6)
        echo "🧪 Running full test sequence..."
        echo ""
        echo "Step 1: Enable passthrough mode"
        defaults write $BUNDLE_ID EndoEditForcePassthrough -bool YES
        defaults write $BUNDLE_ID CG_NUMERICS_SHOW_BACKTRACE -bool YES
        echo "✅ Debug settings configured"
        echo ""
        echo "📋 Next Steps:"
        echo "1. Build and run your app in Xcode"
        echo "2. Import a video and try to export it"
        echo "3. Check the Xcode console for debug messages"
        echo "4. Look for these log patterns:"
        echo "   🎛️ EndoEditService.export: Forcing passthrough"
        echo "   📈 Export progress: X%"
        echo "   ✅ Export completed"
        echo "   ❌ Export failed (if issues persist)"
        echo ""
        echo "5. If passthrough works, disable it and test with compositor:"
        echo "   defaults write $BUNDLE_ID EndoEditForcePassthrough -bool NO"
        ;;
    *)
        echo "❌ Invalid option. Please choose 1-6."
        ;;
esac

echo ""
echo "💡 Tips:"
echo "- Run this script from your project root directory"
echo "- Check Xcode console for detailed debug output"
echo "- Test on both simulator and device"
echo "- Look for NaN backtraces if Core Graphics errors occur"

