// Bitshare App - Interactive JavaScript
// Simulates the bitshare app functionality with realistic behavior

class BitShareApp {
    constructor() {
        this.peers = [
            { id: 'peer-a1b2', name: 'Alice-iPhone', transport: 'Noise+BLE', signal: 'excellent', connected: true },
            { id: 'peer-c3d4', name: 'Bob-MacBook', transport: 'WiFi Direct', signal: 'good', connected: true },
            { id: 'peer-e5f6', name: 'Charlie-iPad', transport: 'Noise+BLE', signal: 'fair', connected: true }
        ];
        
        this.activeTransfers = [];
        this.transferHistory = [];
        this.sessionStats = {
            totalTransfers: 47,
            bytesTransferred: 2.3 * 1024 * 1024 * 1024, // 2.3 GB
            avgSpeed: 1.2 * 1024 * 1024, // 1.2 MB/s
            sessionStart: new Date(Date.now() - 83 * 60 * 1000) // 1h 23m ago
        };
        
        this.currentTransport = 'bluetooth';
        this.isWiFiDirectAvailable = true;
        this.consoleOpen = false;
        this.sidebarOpen = false;
        
        this.init();
    }
    
    init() {
        this.setupEventListeners();
        this.renderPeers();
        this.updateStats();
        this.updateTransportStatus();
        this.simulateBackgroundActivity();
        this.addConsoleMessage('[BitShareApp] Ready for file transfers');
    }
    
    setupEventListeners() {
        // File drop zone
        const dropZone = document.getElementById('fileDropZone');
        const fileInput = document.getElementById('fileInput');
        
        dropZone.addEventListener('click', () => fileInput.click());
        dropZone.addEventListener('dragover', this.handleDragOver.bind(this));
        dropZone.addEventListener('dragleave', this.handleDragLeave.bind(this));
        dropZone.addEventListener('drop', this.handleFileDrop.bind(this));
        
        fileInput.addEventListener('change', this.handleFileSelect.bind(this));
        
        // Transport controls
        document.getElementById('bluetoothBtn').addEventListener('click', () => this.switchTransport('bluetooth'));
        document.getElementById('wifiDirectBtn').addEventListener('click', () => this.switchTransport('wifiDirect'));
        
        // Header buttons
        document.getElementById('settingsBtn').addEventListener('click', () => this.toggleSidebar());
        document.getElementById('historyBtn').addEventListener('click', () => this.showTransferHistory());
        document.getElementById('closeSidebarBtn').addEventListener('click', () => this.toggleSidebar());
        
        // Console toggle
        document.getElementById('consoleToggle').addEventListener('click', () => this.toggleConsole());
        
        // Transport status click
        document.getElementById('transportStatus').addEventListener('click', () => this.showTransportDetails());
        
        // Simulate peer connections
        setInterval(() => this.simulatePeerActivity(), 5000);
    }
    
    handleDragOver(e) {
        e.preventDefault();
        document.getElementById('fileDropZone').classList.add('drag-over');
    }
    
    handleDragLeave(e) {
        e.preventDefault();
        document.getElementById('fileDropZone').classList.remove('drag-over');
    }
    
    handleFileDrop(e) {
        e.preventDefault();
        document.getElementById('fileDropZone').classList.remove('drag-over');
        
        const files = Array.from(e.dataTransfer.files);
        this.processFiles(files);
    }
    
    handleFileSelect(e) {
        const files = Array.from(e.target.files);
        this.processFiles(files);
    }
    
    processFiles(files) {
        if (files.length === 0) return;
        
        this.addConsoleMessage(`[FileTransferManager] Processing ${files.length} file(s)`);
        
        files.forEach(file => {
            // Select a random peer as recipient
            const recipient = this.peers[Math.floor(Math.random() * this.peers.length)];
            
            // Determine transport based on file size
            const transport = this.selectOptimalTransport(file.size);
            
            const transfer = {
                id: this.generateTransferId(),
                filename: file.name,
                size: file.size,
                recipient: recipient,
                transport: transport,
                progress: 0,
                status: 'initializing',
                startTime: new Date(),
                speed: 0,
                type: this.getFileType(file.name)
            };
            
            this.activeTransfers.push(transfer);
            this.startTransfer(transfer);
            this.renderTransfers();
        });
    }
    
    selectOptimalTransport(fileSize) {
        const threshold = 1024 * 1024; // 1MB
        const batteryLevel = 0.8; // Simulated 80% battery
        
        if (fileSize > threshold && this.isWiFiDirectAvailable && batteryLevel > 0.5) {
            return 'wifiDirect';
        } else {
            return 'bluetooth';
        }
    }
    
    startTransfer(transfer) {
        this.addConsoleMessage(`[NoiseTransport] Starting transfer: ${transfer.filename} to ${transfer.recipient.name}`);
        
        // Simulate handshake
        setTimeout(() => {
            transfer.status = 'connecting';
            this.addConsoleMessage(`[NoiseTransport] Establishing session with ${transfer.recipient.id}`);
            this.renderTransfers();
            
            // Start actual transfer
            setTimeout(() => {
                transfer.status = 'transferring';
                this.simulateTransferProgress(transfer);
                this.addConsoleMessage(`[NoiseTransport] Transfer started via ${transfer.transport}`);
                this.renderTransfers();
            }, 1000);
        }, 500);
    }
    
    simulateTransferProgress(transfer) {
        const interval = setInterval(() => {
            if (transfer.progress >= 100) {
                clearInterval(interval);
                transfer.status = 'completed';
                transfer.endTime = new Date();
                
                // Move to history
                this.transferHistory.push(transfer);
                this.activeTransfers = this.activeTransfers.filter(t => t.id !== transfer.id);
                
                this.addConsoleMessage(`[NoiseTransport] Transfer completed: ${transfer.filename}`);
                this.updateStats();
                this.renderTransfers();
                return;
            }
            
            // Simulate realistic transfer speed
            const baseSpeed = transfer.transport === 'wifiDirect' ? 15 : 1; // MB/s
            const variation = 0.8 + (Math.random() * 0.4); // ±20% variation
            const currentSpeed = baseSpeed * variation;
            
            const increment = (currentSpeed * 1024 * 1024) / transfer.size * 100 * 0.5; // 0.5s intervals
            transfer.progress = Math.min(100, transfer.progress + increment);
            transfer.speed = currentSpeed;
            
            this.renderTransfers();
        }, 500);
    }
    
    renderTransfers() {
        const container = document.getElementById('transfersList');
        
        if (this.activeTransfers.length === 0) {
            container.innerHTML = '<div class="no-transfers">No active transfers</div>';
            return;
        }
        
        container.innerHTML = this.activeTransfers.map(transfer => `
            <div class="transfer-item">
                <div class="transfer-icon">${this.getFileIcon(transfer.type)}</div>
                <div class="transfer-info">
                    <div class="transfer-filename">${transfer.filename}</div>
                    <div class="transfer-details">
                        <span>${this.formatFileSize(transfer.size)}</span>
                        <span>•</span>
                        <span>${transfer.status === 'transferring' ? '→' : '↔'} ${transfer.recipient.name}</span>
                        <span>•</span>
                        <span>${transfer.transport === 'wifiDirect' ? 'WiFi Direct' : 'Noise+BLE'}</span>
                    </div>
                </div>
                <div class="transfer-progress">
                    <div class="transfer-percentage">${Math.round(transfer.progress)}%</div>
                    <div class="transfer-status">${this.getTransferStatus(transfer)}</div>
                    <div class="progress-bar">
                        <div class="progress-fill" style="width: ${transfer.progress}%"></div>
                    </div>
                </div>
            </div>
        `).join('');
    }
    
    renderPeers() {
        const container = document.getElementById('peersList');
        
        container.innerHTML = this.peers.map(peer => `
            <div class="peer-item">
                <div class="peer-signal ${peer.signal}"></div>
                <div class="peer-name">${peer.name}</div>
                <div class="peer-transport">${peer.transport}</div>
            </div>
        `).join('');
        
        document.getElementById('peerCount').textContent = this.peers.length;
    }
    
    updateStats() {
        const now = new Date();
        const sessionTime = Math.floor((now - this.sessionStats.sessionStart) / 1000 / 60);
        
        document.getElementById('totalTransfers').textContent = this.sessionStats.totalTransfers;
        document.getElementById('bytesTransferred').textContent = this.formatFileSize(this.sessionStats.bytesTransferred);
        document.getElementById('avgSpeed').textContent = this.formatSpeed(this.sessionStats.avgSpeed);
        document.getElementById('sessionTime').textContent = `${Math.floor(sessionTime / 60)}h ${sessionTime % 60}m`;
    }
    
    updateTransportStatus() {
        const transportName = document.getElementById('transportName');
        const transportIcon = document.getElementById('transportIcon');
        const speedMultiplier = document.getElementById('speedMultiplier');
        
        if (this.currentTransport === 'wifiDirect') {
            transportName.textContent = 'WiFi Direct';
            transportIcon.textContent = '📶';
            speedMultiplier.style.display = 'flex';
        } else {
            transportName.textContent = 'Noise Protocol';
            transportIcon.textContent = '📡';
            speedMultiplier.style.display = 'none';
        }
        
        // Update button states
        document.getElementById('bluetoothBtn').classList.toggle('active', this.currentTransport === 'bluetooth');
        document.getElementById('wifiDirectBtn').classList.toggle('active', this.currentTransport === 'wifiDirect');
    }
    
    switchTransport(transport) {
        if (this.currentTransport === transport) return;
        
        this.currentTransport = transport;
        this.updateTransportStatus();
        
        this.addConsoleMessage(`[TransportManager] Switched to ${transport === 'wifiDirect' ? 'WiFi Direct' : 'Noise Protocol'}`);
        
        // Show loading overlay briefly
        this.showLoadingOverlay(transport === 'wifiDirect' ? 'Activating WiFi Direct...' : 'Establishing Noise Protocol Sessions...');
    }
    
    showLoadingOverlay(message) {
        const overlay = document.getElementById('loadingOverlay');
        const text = overlay.querySelector('.loading-text');
        
        text.textContent = message;
        overlay.classList.add('show');
        
        setTimeout(() => {
            overlay.classList.remove('show');
        }, 2000);
    }
    
    toggleSidebar() {
        this.sidebarOpen = !this.sidebarOpen;
        document.getElementById('sidebar').classList.toggle('open', this.sidebarOpen);
    }
    
    toggleConsole() {
        this.consoleOpen = !this.consoleOpen;
        document.getElementById('console').classList.toggle('open', this.consoleOpen);
        document.getElementById('consoleToggle').textContent = this.consoleOpen ? '−' : '_';
    }
    
    showTransferHistory() {
        this.addConsoleMessage('[UI] Transfer history requested');
        alert('Transfer History: ' + this.transferHistory.length + ' completed transfers');
    }
    
    showTransportDetails() {
        this.addConsoleMessage('[TransportManager] Transport details requested');
        
        const details = [
            `Current Transport: ${this.currentTransport === 'wifiDirect' ? 'WiFi Direct' : 'Noise Protocol'}`,
            `Connected Peers: ${this.peers.length}`,
            `Session Uptime: ${Math.floor((new Date() - this.sessionStats.sessionStart) / 1000 / 60)}m`,
            `Active Transfers: ${this.activeTransfers.length}`
        ];
        
        alert(details.join('\n'));
    }
    
    simulatePeerActivity() {
        // Randomly connect/disconnect peers
        if (Math.random() < 0.3) {
            const peer = this.peers[Math.floor(Math.random() * this.peers.length)];
            peer.connected = !peer.connected;
            
            if (peer.connected) {
                this.addConsoleMessage(`[NoiseTransport] Peer reconnected: ${peer.name}`);
            } else {
                this.addConsoleMessage(`[NoiseTransport] Peer disconnected: ${peer.name}`);
            }
            
            this.renderPeers();
        }
    }
    
    simulateBackgroundActivity() {
        // Simulate periodic background activity
        setInterval(() => {
            const activities = [
                '[NoiseTransport] Session rekey performed',
                '[BatteryOptimizer] Battery level: 78%',
                '[TransportManager] Peer discovery sweep',
                '[FileTransferManager] Cache cleanup completed',
                '[NoiseTransport] Forward secrecy rotation'
            ];
            
            if (Math.random() < 0.4) {
                const activity = activities[Math.floor(Math.random() * activities.length)];
                this.addConsoleMessage(activity);
            }
        }, 10000);
    }
    
    addConsoleMessage(message) {
        const output = document.getElementById('consoleOutput');
        const line = document.createElement('div');
        line.className = 'console-line';
        line.textContent = `[${new Date().toLocaleTimeString()}] ${message}`;
        
        output.appendChild(line);
        output.scrollTop = output.scrollHeight;
        
        // Keep only last 100 messages
        if (output.children.length > 100) {
            output.removeChild(output.firstChild);
        }
    }
    
    // Utility functions
    generateTransferId() {
        return 'transfer-' + Math.random().toString(36).substr(2, 9);
    }
    
    getFileType(filename) {
        const ext = filename.split('.').pop().toLowerCase();
        const types = {
            'pdf': 'document',
            'doc': 'document',
            'docx': 'document',
            'txt': 'document',
            'jpg': 'image',
            'jpeg': 'image',
            'png': 'image',
            'gif': 'image',
            'mp4': 'video',
            'avi': 'video',
            'mov': 'video',
            'mp3': 'audio',
            'wav': 'audio',
            'zip': 'archive',
            'rar': 'archive',
            'tar': 'archive'
        };
        return types[ext] || 'file';
    }
    
    getFileIcon(type) {
        const icons = {
            'document': '📄',
            'image': '🖼️',
            'video': '🎬',
            'audio': '🎵',
            'archive': '📦',
            'file': '📁'
        };
        return icons[type] || '📁';
    }
    
    getTransferStatus(transfer) {
        switch (transfer.status) {
            case 'initializing': return 'Starting...';
            case 'connecting': return 'Connecting...';
            case 'transferring': return `${this.formatSpeed(transfer.speed * 1024 * 1024)}`;
            case 'completed': return 'Completed';
            case 'error': return 'Error';
            default: return 'Unknown';
        }
    }
    
    formatFileSize(bytes) {
        if (bytes === 0) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
    }
    
    formatSpeed(bytesPerSecond) {
        return this.formatFileSize(bytesPerSecond) + '/s';
    }
}

// Initialize the app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.bitshareApp = new BitShareApp();
});

// Add some demo transfers on load
document.addEventListener('DOMContentLoaded', () => {
    setTimeout(() => {
        // Simulate some demo file transfers
        const demoFiles = [
            { name: 'presentation.pdf', size: 2.5 * 1024 * 1024 },
            { name: 'vacation-photos.zip', size: 15 * 1024 * 1024 },
            { name: 'demo-video.mp4', size: 45 * 1024 * 1024 }
        ];
        
        // Add a demo transfer every 3 seconds
        demoFiles.forEach((file, index) => {
            setTimeout(() => {
                if (window.bitshareApp) {
                    window.bitshareApp.processFiles([file]);
                }
            }, (index + 1) * 3000);
        });
    }, 2000);
});

// Add keyboard shortcuts
document.addEventListener('keydown', (e) => {
    if (e.ctrlKey || e.metaKey) {
        switch (e.key) {
            case 'k':
                e.preventDefault();
                window.bitshareApp?.toggleConsole();
                break;
            case ',':
                e.preventDefault();
                window.bitshareApp?.toggleSidebar();
                break;
            case 'h':
                e.preventDefault();
                window.bitshareApp?.showTransferHistory();
                break;
        }
    }
});

// Add touch gestures for mobile
let touchStartX = 0;
let touchStartY = 0;

document.addEventListener('touchstart', (e) => {
    touchStartX = e.touches[0].clientX;
    touchStartY = e.touches[0].clientY;
});

document.addEventListener('touchend', (e) => {
    const touchEndX = e.changedTouches[0].clientX;
    const touchEndY = e.changedTouches[0].clientY;
    
    const deltaX = touchEndX - touchStartX;
    const deltaY = touchEndY - touchStartY;
    
    // Swipe right to left (open sidebar)
    if (deltaX < -100 && Math.abs(deltaY) < 50) {
        window.bitshareApp?.toggleSidebar();
    }
    
    // Swipe up (open console)
    if (deltaY < -100 && Math.abs(deltaX) < 50) {
        window.bitshareApp?.toggleConsole();
    }
});