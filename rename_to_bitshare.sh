#!/bin/bash

# BitShare Renaming Script
# Renames all instances of "bitchat" to "BitShare" while preserving functionality

set -e  # Exit on any error

echo "🔄 Starting BitShare renaming process..."

# Backup the original project
echo "📦 Creating backup..."
cp -r bitchat.xcodeproj bitchat.xcodeproj.backup
cp project.yml project.yml.backup
cp README.md README.md.backup

# 1. Rename directories
echo "📁 Renaming directories..."
if [ -d "bitchat" ]; then
    mv bitchat bitshare
fi
if [ -d "bitchatShareExtension" ]; then
    mv bitchatShareExtension bitshareShareExtension  
fi
if [ -d "bitchatTests" ]; then
    mv bitchatTests bitshareTests
fi
if [ -d "bitchat.xcodeproj" ]; then
    mv bitchat.xcodeproj bitshare.xcodeproj
fi

# 2. Update project.yml (XcodeGen configuration)
echo "⚙️  Updating project configuration..."
sed -i '' 's/name: bitchat/name: BitShare/g' project.yml
sed -i '' 's/bundleIdPrefix: chat.bitchat/bundleIdPrefix: share.bitshare/g' project.yml
sed -i '' 's/bitchat_iOS/bitshare_iOS/g' project.yml
sed -i '' 's/bitchat_macOS/bitshare_macOS/g' project.yml
sed -i '' 's/bitchatShareExtension/bitshareShareExtension/g' project.yml
sed -i '' 's/bitchatTests_iOS/bitshareTests_iOS/g' project.yml
sed -i '' 's/bitchatTests_macOS/bitshareTests_macOS/g' project.yml
sed -i '' 's/CFBundleDisplayName: bitchat/CFBundleDisplayName: BitShare/g' project.yml
sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER: chat.bitchat/PRODUCT_BUNDLE_IDENTIFIER: share.bitshare/g' project.yml
sed -i '' 's/PRODUCT_NAME: bitchat/PRODUCT_NAME: BitShare/g' project.yml
sed -i '' 's/bitchat uses Bluetooth/BitShare uses Bluetooth/g' project.yml
sed -i '' 's/other bitchat users/other BitShare users/g' project.yml
sed -i '' 's/bitchat (iOS)/BitShare (iOS)/g' project.yml
sed -i '' 's/bitchat (macOS)/BitShare (macOS)/g' project.yml
sed -i '' 's/- bitchat/- bitshare/g' project.yml
sed -i '' 's/executable: bitchat_iOS/executable: bitshare_iOS/g' project.yml
sed -i '' 's/executable: bitchat_macOS/executable: bitshare_macOS/g' project.yml
sed -i '' 's/- bitchatTests_iOS/- bitshareTests_iOS/g' project.yml
sed -i '' 's/- bitchatTests_macOS/- bitshareTests_macOS/g' project.yml
sed -i '' 's/bitchat\/bitchat.entitlements/bitshare\/bitshare.entitlements/g' project.yml
sed -i '' 's/bitchatShareExtension\/bitchatShareExtension.entitlements/bitshareShareExtension\/bitshareShareExtension.entitlements/g' project.yml

# 3. Update Swift files
echo "🔧 Updating Swift source code..."

# Update main app file
sed -i '' 's/\/\/ BitchatApp.swift/\/\/ BitShareApp.swift/g' bitshare/BitchatApp.swift
sed -i '' 's/\/\/ bitchat/\/\/ BitShare/g' bitshare/BitchatApp.swift
sed -i '' 's/struct BitchatApp: App/struct BitShareApp: App/g' bitshare/BitchatApp.swift
sed -i '' 's/url.scheme == "bitchat"/url.scheme == "bitshare"/g' bitshare/BitchatApp.swift
sed -i '' 's/group.chat.bitchat/group.share.bitshare/g' bitshare/BitchatApp.swift
sed -i '' 's/BitchatMessage(/BitShareMessage(/g' bitshare/BitchatApp.swift
mv bitshare/BitchatApp.swift bitshare/BitShareApp.swift

# Update protocol files
find bitshare/Protocols -name "*.swift" -exec sed -i '' 's/\/\/ bitchat/\/\/ BitShare/g' {} \;
find bitshare/Protocols -name "*.swift" -exec sed -i '' 's/BitchatProtocol/BitShareProtocol/g' {} \;
find bitshare/Protocols -name "*.swift" -exec sed -i '' 's/BitchatMessage/BitShareMessage/g' {} \;
mv bitshare/Protocols/BitchatProtocol.swift bitshare/Protocols/BitShareProtocol.swift

# Update all other Swift files
find bitshare -name "*.swift" -exec sed -i '' 's/\/\/ bitchat/\/\/ BitShare/g' {} \;
find bitshare -name "*.swift" -exec sed -i '' 's/BitchatMessage/BitShareMessage/g' {} \;
find bitshare -name "*.swift" -exec sed -i '' 's/bitchat\*/BitShare\*/g' {} \;
find bitshare -name "*.swift" -exec sed -i '' 's/secure mesh chat/secure file sharing/g' {} \;

# Update Share Extension
find bitshareShareExtension -name "*.swift" -exec sed -i '' 's/\/\/ bitchat/\/\/ BitShare/g' {} \;
find bitshareShareExtension -name "*.swift" -exec sed -i '' 's/group.chat.bitchat/group.share.bitshare/g' {} \;

# Update Test files
find bitshareTests -name "*.swift" -exec sed -i '' 's/\/\/ bitchat/\/\/ BitShare/g' {} \;
find bitshareTests -name "*.swift" -exec sed -i '' 's/BitchatMessage/BitShareMessage/g' {} \;

# 4. Update Info.plist files
echo "📄 Updating Info.plist files..."
sed -i '' 's/<string>bitchat<\/string>/<string>BitShare<\/string>/g' bitshare/Info.plist
sed -i '' 's/bitchat uses Bluetooth/BitShare uses Bluetooth/g' bitshare/Info.plist
sed -i '' 's/other bitchat users/other BitShare users/g' bitshare/Info.plist

sed -i '' 's/<string>bitchat<\/string>/<string>BitShare<\/string>/g' bitshareShareExtension/Info.plist

# 5. Update entitlements files
echo "🔐 Updating entitlements..."
if [ -f "bitshare/bitchat.entitlements" ]; then
    mv bitshare/bitchat.entitlements bitshare/bitshare.entitlements
fi
if [ -f "bitshareShareExtension/bitchatShareExtension.entitlements" ]; then
    mv bitshareShareExtension/bitchatShareExtension.entitlements bitshareShareExtension/bitshareShareExtension.entitlements
fi

# 6. Regenerate Xcode project
echo "🔨 Regenerating Xcode project..."
if command -v xcodegen &> /dev/null; then
    xcodegen generate
    echo "✅ Xcode project regenerated successfully"
else
    echo "⚠️  XcodeGen not found. Install with: brew install xcodegen"
    echo "   Then run: xcodegen generate"
fi

echo ""
echo "✅ BitShare renaming completed successfully!"
echo ""
echo "📝 Next steps:"
echo "   1. Update your Apple Developer Team ID in project.yml (currently: L3N5LHJD5Y)"
echo "   2. Run 'xcodegen generate' if you haven't installed XcodeGen yet"
echo "   3. Open bitshare.xcodeproj in Xcode"
echo "   4. Update README.md with new project information"
echo ""
echo "🔄 Backup files created:"
echo "   - bitchat.xcodeproj.backup"
echo "   - project.yml.backup" 
echo "   - README.md.backup"