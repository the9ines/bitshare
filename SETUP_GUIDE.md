# BitShare Testing Setup Guide

## Overview
This guide will help you set up and test BitShare on a computer that can run the latest version of Xcode.

## Requirements
- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 15.0 or later (free from Mac App Store)
- **Hardware**: Mac with Apple Silicon or Intel processor
- **Memory**: At least 8GB RAM recommended
- **Storage**: At least 10GB free space

## Step 1: Copy BitShare Project

1. **Copy the entire bitshare folder** from this computer to your target computer
2. **Recommended methods:**
   - AirDrop (fastest for local transfer)
   - USB drive
   - Cloud storage (iCloud, Dropbox, etc.)
   - Git repository

## Step 2: Install Xcode

1. **Open Mac App Store** on the target computer
2. **Search for "Xcode"** and install it (free, ~7GB download)
3. **Launch Xcode** and accept the license agreement
4. **Install additional components** when prompted

## Step 3: Configure BitShare Project

1. **Open BitShare project:**
   ```bash
   open bitshare.xcodeproj
   ```

2. **Update Development Team:**
   - Select the project in the navigator
   - Go to "Signing & Capabilities"
   - Change "Team" to your Apple ID
   - Do this for all targets (bitshare, bitshareTests, bitshareShareExtension)

3. **Update Bundle Identifiers (if needed):**
   - Change from `chat.bitchat` to something unique like `com.yourname.bitshare`
   - Update for all targets

## Step 4: Run Tests

### Option A: Run All Tests
```bash
# In Terminal, navigate to the project folder
cd /path/to/bitshare

# Run all tests
xcodebuild test -scheme bitshare -destination 'platform=macOS'
```

### Option B: Run Tests in Xcode
1. **Open bitshare.xcodeproj** in Xcode
2. **Press `Cmd+U`** to run all tests
3. **View results** in the Test Navigator

### Option C: Run Individual Test Suites
In Xcode, you can run specific test files:
- `FileTransferProtocolTests.swift`
- `FileTransferManagerTests.swift`
- `FileChunkOptimizerTests.swift`
- `FileTransferIntegrationTests.swift`
- `FileTransferPerformanceTests.swift`

## Step 5: Build and Run BitShare

1. **Build the app:**
   ```bash
   xcodebuild -scheme bitshare -destination 'platform=macOS' build
   ```

2. **Or in Xcode:**
   - Press `Cmd+R` to build and run
   - The BitShare app should launch

## Step 6: Test File Transfer Features

### Basic UI Testing
1. **Launch BitShare**
2. **Test drag-and-drop:**
   - Drag a file onto the app
   - Verify it appears in the transfer queue
3. **Test file selection:**
   - Click "Select File" button
   - Choose a test file
4. **Test transfer history:**
   - Check the history view shows transfers

### Performance Testing
1. **Test small files** (< 1KB)
2. **Test medium files** (1KB - 1MB)
3. **Test large files** (> 1MB, up to 100MB)

### Error Handling Testing
1. **Test with invalid files**
2. **Test with files that are too large**
3. **Test cancellation and pause/resume**

## Step 7: Multi-Device Testing (Optional)

If you have two computers with BitShare:

1. **Enable Bluetooth** on both computers
2. **Launch BitShare** on both
3. **Test peer discovery:**
   - Apps should find each other
   - Peers should appear in the peer list
4. **Test file transfers:**
   - Send a file from one to the other
   - Monitor progress and completion

## Expected Test Results

### Unit Tests
- **FileTransferProtocolTests**: Should pass all protocol encoding/decoding tests
- **FileTransferManagerTests**: Should pass all transfer management tests
- **FileChunkOptimizerTests**: Should pass all optimization tests
- **FileTransferIntegrationTests**: Should pass all end-to-end tests
- **FileTransferPerformanceTests**: Should meet performance benchmarks

### Performance Benchmarks
- **Chunking**: > 2MB/s throughput
- **Encoding**: > 200 chunks/s
- **Memory**: < 50MB increase for 10MB files
- **Cache**: > 1000 operations/s

### App Functionality
- ✅ File selection and drag-drop
- ✅ Transfer progress tracking
- ✅ Transfer history display
- ✅ Error handling and recovery
- ✅ UI responsiveness

## Troubleshooting

### Common Issues

1. **"No code signing identities found"**
   - Solution: Update Development Team in project settings

2. **"Bundle identifier already exists"**
   - Solution: Change bundle identifier to something unique

3. **"Swift compiler error"**
   - Solution: Ensure Xcode 15.0+ is installed

4. **Tests fail to run**
   - Solution: Build the project first, then run tests

5. **Bluetooth not working**
   - Solution: Enable Bluetooth in System Preferences

### Debug Information

If tests fail, check:
- Console output for detailed error messages
- Xcode Issue Navigator for build errors
- System Console for runtime errors

## Test Results Template

Copy this template to record your results:

```
# BitShare Test Results

## Environment
- macOS Version: 
- Xcode Version: 
- Hardware: 
- Date: 

## Unit Tests
- FileTransferProtocolTests: ✅/❌
- FileTransferManagerTests: ✅/❌
- FileChunkOptimizerTests: ✅/❌
- FileTransferIntegrationTests: ✅/❌
- FileTransferPerformanceTests: ✅/❌

## Performance Results
- Chunking Throughput: ___ MB/s
- Encoding Speed: ___ chunks/s
- Memory Usage: ___ MB
- Cache Performance: ___ ops/s

## App Functionality
- File Selection: ✅/❌
- Transfer Progress: ✅/❌
- Transfer History: ✅/❌
- Error Handling: ✅/❌
- UI Responsiveness: ✅/❌

## Multi-Device Testing (if applicable)
- Peer Discovery: ✅/❌
- File Transfer: ✅/❌
- Transfer Speed: ___ KB/s
- Error Recovery: ✅/❌

## Notes
(Add any additional observations or issues)
```

## Next Steps

After successful testing:
1. Document any issues found
2. Report performance metrics
3. Consider additional features or improvements
4. Prepare for production deployment

## Support

If you encounter issues:
1. Check the console output for error messages
2. Review the TESTING_PLAN.md for detailed test scenarios
3. Consult the project documentation files
4. Run the basic protocol tests to verify core functionality

The BitShare project is ready for comprehensive testing on a compatible computer!