BitShare Product Requirements Document (PRD)
Executive Summary
BitShare is a native iOS/macOS file sharing application designed to facilitate secure, offline file transfers leveraging the Bluetooth mesh network established by Jack Dorsey's Bitchat. It is built for privacy-conscious individuals, emergency responders, and anyone operating in connectivity-constrained environments. BitShare matters now more than ever as it provides a critical, decentralized alternative for data exchange, ensuring communication and collaboration even when traditional infrastructure fails. Its key differentiators include complete offline functionality, 100% visual and technical consistency with the proven Bitchat protocol, multi-hop file transfer capabilities, and robust end-to-end encryption, all developed rapidly by forking and extending an existing battle-tested open-source codebase.
1. Introduction
This document outlines the comprehensive Product Requirements Document for BitShare, a native iOS/macOS file sharing application designed to operate entirely offline via Bluetooth mesh networking. BitShare is the inaugural expansion of the "bit ecosystem," leveraging the proven Bluetooth mesh protocol and visual design established by Jack Dorsey's "Bitchat" decentralized messaging app. Crucially, BitShare will be developed by forking and modifying the existing open-source Bitchat codebase, ensuring unparalleled consistency and accelerating development. This PRD serves as a complete blueprint for the development, testing, and launch of BitShare, ensuring its seamless integration into the broader offline-first application ecosystem.
2. Background & Context
2.1 The Bit Ecosystem Vision
Jack Dorsey's "Bitchat" has demonstrated the viability and critical need for decentralized, offline messaging over Bluetooth Low Energy (BLE) mesh networks. Its core features, including end-to-end encryption, automatic peer discovery, and multi-hop message relaying, provide a robust communication solution in scenarios where internet connectivity is absent or compromised (e.g., natural disasters, censorship, remote areas).
Our vision is to expand upon this foundational technology by creating a comprehensive "bit ecosystem" – a suite of offline-capable applications that all utilize Bitchat's established Bluetooth mesh protocol and adhere to its strict design principles. This ecosystem aims to provide essential digital tools that function reliably without reliance on central servers or internet access.
2.2 BitShare Product Overview
BitShare is the first application to extend the bit ecosystem. It is designed as a native iOS/macOS file sharing application that facilitates completely offline file transfers over Bluetooth mesh. A critical aspect of BitShare's design is its commitment to 100% visual and architectural consistency with Bitchat, ensuring a cohesive and intuitive user experience across the ecosystem.
2.2.1 Core Concept
BitShare enables users to select and transfer files to other nearby devices within the Bluetooth mesh network. Files are chunked, encrypted, and relayed across intermediate devices, extending the effective range of file transfers beyond direct Bluetooth proximity. Users can intuitively manage transfers, track progress, and ensure data integrity.
2.2.2 Key Differentiators
Works Completely Offline: No internet, Wi-Fi, or cellular connection is required for file transfers.
Bitchat Visual & Technical Consistency: Employs Bitchat's exact visual design language and leverages its established Bluetooth mesh protocol for seamless ecosystem integration.
Native Performance: Built as a native iOS and macOS application, ensuring optimal performance, responsiveness, and integration with the respective operating systems.
Multi-hop File Transfer: Files can be relayed through multiple intermediate devices within the mesh, significantly extending the effective transfer range (beyond the typical 30m Bluetooth LE direct range).
End-to-End Encryption: Utilizes the same robust encryption model as Bitchat (X25519 key exchange + AES-256-GCM), ensuring the privacy and security of transferred files.
Cross-platform Protocol Compatibility: While initially native iOS/macOS, the underlying protocol is designed to be compatible with future Android implementations, fostering a truly cross-platform offline ecosystem.
3. Technical Foundation
3.1 Bitchat Protocol Details
BitShare will build directly upon the Bitchat protocol, ensuring interoperability and leveraging its proven robustness. Key aspects of the Bitchat protocol include:
Bluetooth Low Energy Mesh Networking: The underlying transport layer.
Binary Protocol: A custom binary protocol designed for efficiency over BLE.
13-byte Header Format: All messages utilize a standardized 13-byte header for routing and metadata.
TTL-based Routing: Messages (and file chunks) are routed using a Time-To-Live (TTL) mechanism, supporting a maximum of 7 hops.
X25519 Key Exchange + AES-256-GCM Encryption: Provides strong end-to-end encryption for all data traversing the mesh.
Store-and-Forward: Messages (and file chunks) can be temporarily stored on intermediate nodes and forwarded when the destination becomes available, enabling asynchronous delivery.
Service UUID: 6E400001-B5A3-F393-E0A9-E50E24DCCA9E
Characteristic UUID: 6E400002-B5A3-F393-E0A9-E50E24DCCA9E
3.2 File Transfer Adaptations
To support file transfer functionality, the Bitchat protocol will be extended with file-specific message types and handling mechanisms.
Extended Protocol with File-Specific Message Types:
FILE_MANIFEST: Sent by the sender to announce a file transfer. Contains metadata like file name, size, SHA-256 hash, and number of chunks.
FILE_CHUNK: Contains a segment of the file data. Includes chunk index and payload.
FILE_ACK: Acknowledgment from the receiver for received chunks, used for reliability and retransmission.
Chunking Large Files: Files will be segmented into 480-byte chunks to fit within Bluetooth LE's maximum transmission unit (MTU) limitations while allowing for protocol overhead. This ensures efficient and reliable transfer of even large files.
Reassembly and Integrity Verification:
The receiving device will reassemble received chunks in the correct order.
A final SHA-256 hash of the reassembled file will be computed and compared against the hash provided in the FILE_MANIFEST to ensure data integrity.
Progress Tracking: The application will track and display the transfer progress (e.g., percentage complete, progress bar).
Resume Capabilities: Mechanisms will be implemented to allow for pausing and resuming file transfers, crucial for large files or intermittent connectivity.
4. Design System Requirements
Maintaining 100% visual and interaction consistency with Bitchat is paramount to creating a cohesive bit ecosystem.
4.1 Visual Identity (Must Match Bitchat Exactly)
Monospace Typography: Exclusively use SF Mono system font throughout the application UI.
Color Scheme:
Accent Color: Pure green (#00FF00)
Backgrounds: Black and white for high contrast.
Aesthetic: High contrast, minimalist design.
Component Styling: Buttons, input fields, cards, and other UI elements must replicate the exact styling patterns of Bitchat.
Spacing System:
Horizontal Padding: Consistent 12px.
Vertical Padding: Consistent 8px.
Animation Patterns: Utilize spring animations with 0.3 response and 0.8 damping for all UI transitions and interactions to match Bitchat's fluid feel.
4.2 UI Layout Pattern
BitShare will strictly adhere to the following UI layout pattern, identical to Bitchat:
┌─────────────────────────────────────┐
│ bitshare* [peers: 3]                │ ← Header (44px fixed height)
├─────────────────────────────────────┤
│ File Drop Zone / Transfer Area      │ ← Main content area (scrollable if needed)
├─────────────────────────────────────┤
│ Peer Discovery / Controls           │ ← Bottom section (variable height based on content)
└─────────────────────────────────────┘


Header: Displays the application name ("bitshare*") and real-time peer count.
Main Content Area: This is where users will interact with file selection (drag-and-drop), view ongoing transfer progress, and see completed transfers.
Bottom Section: Contains controls for initiating transfers, managing peer connections, and other relevant actions.
5. Core Features & Functionality
5.1 Essential Features (Minimum Viable Product - MVP)
Bluetooth Mesh Peer Discovery and Connection:
User Story: As a user, I want BitShare to automatically discover and connect to other BitShare/Bitchat users in the vicinity via Bluetooth mesh, so I can see who is available for file transfer.
Acceptance Criteria:
Application automatically scans for and displays available peers.
Peer list updates in real-time as devices enter/leave the mesh.
Connection status (e.g., "Connected," "Disconnected") is clearly indicated for each peer.
Shared peer discovery with Bitchat: BitShare and Bitchat users are visible to each other.
Drag-and-Drop File Selection Interface:
User Story: As a user, I want to easily select files for transfer by dragging and dropping them into the application window on macOS, or by using a standard file picker on iOS, so I can initiate a transfer quickly.
Acceptance Criteria:
On macOS, a dedicated drop zone is present and visually indicates readiness for files.
On iOS, a clear "Select File" button or equivalent initiates the system file picker.
Multiple files can be selected simultaneously.
Unsupported file types are visually indicated or prevented from selection.
Multi-File Transfer with Progress Tracking:
User Story: As a user, I want to transfer multiple files to a selected peer and monitor the progress of each file individually, so I know when my files have been successfully sent.
Acceptance Criteria:
Users can select one or more files to send to a specific peer.
A clear progress indicator (e.g., percentage, progress bar) is displayed for each active transfer.
Transfer status (e.g., "Sending," "Receiving," "Complete," "Failed") is visible.
Ability to transfer different files to different peers concurrently.
Transfer Pause/Resume Capabilities:
User Story: As a user, I want to be able to pause an ongoing file transfer and resume it later, even if the connection is temporarily lost, so I don't have to restart large transfers from scratch.
Acceptance Criteria:
A "Pause" button is available for active transfers.
Clicking "Pause" stops the transfer gracefully.
A "Resume" button appears for paused transfers.
Resuming a transfer continues from where it left off (chunk-level granularity).
Transfers automatically attempt to resume when a lost connection is re-established.
File Integrity Verification (SHA-256 Hashing):
User Story: As a user, I want assurance that the files I send or receive are not corrupted during transfer, so I can trust the integrity of my data.
Acceptance Criteria:
Sender calculates SHA-256 hash of the file before transfer.
Hash is included in the FILE_MANIFEST message.
Receiver calculates SHA-256 hash of the reassembled file.
Receiver compares calculated hash with the received hash.
If hashes do not match, the transfer is marked as "Corrupted" or "Failed."
Automatic Transport Optimization (Direct vs. Multi-hop):
User Story: As a user, I want BitShare to automatically determine the most efficient way to transfer my files, whether directly or through intermediate peers, so I don't have to manually configure routes.
Acceptance Criteria:
Application prioritizes direct Bluetooth connection if available and reliable.
If direct connection is not possible or optimal, the application transparently utilizes multi-hop relaying.
Users are not required to select direct or multi-hop mode.
Transfer History and Retry Mechanisms:
User Story: As a user, I want to see a history of my past file transfers and be able to easily retry failed transfers, so I can manage my file sharing activities efficiently.
Acceptance Criteria:
A "Transfer History" section displays completed and failed transfers.
Each history entry shows file name, size, sender/receiver, date/time, and status.
A "Retry" option is available for failed transfers.
Retrying a transfer re-initiates the transfer process from the beginning or from the last successful chunk if resume is active.
5.2 Advanced Features (Post-MVP)
Large File Chunking and Parallel Transfer: Optimize chunking for extremely large files and explore parallel chunk transfer to multiple peers for faster delivery.
Folder/Directory Transfer Support: Allow users to select and transfer entire folders, maintaining the directory structure on the receiving end.
Transfer Scheduling and Queuing: Users can schedule transfers for a later time or queue multiple transfers, which will be initiated automatically when conditions are met (e.g., target peer comes online).
Bandwidth Limiting and QoS Controls: Provide options for users to limit the bandwidth consumed by BitShare, or prioritize certain transfers over others.
Cross-platform Compatibility (iOS ↔ macOS ↔ future Android): Full interoperability with an Android BitShare application once developed.
Integration with Bitchat for Enhanced Peer Discovery: Deeper integration allowing Bitchat users to initiate BitShare transfers directly from Bitchat's interface, and vice versa.
5.3 Feature Summary: MVP vs. Advanced
Feature
MVP
Post-MVP
Single file transfer
✅


Multi-file transfer
✅


Folder transfer


✅
Pause/resume
✅


Transfer scheduling


✅
Cross-platform compatibility


✅
Large file chunking/parallel


✅
Bandwidth limiting/QoS


✅
Integration with Bitchat


✅

6. Target Users & Use Cases
6.1 Primary Users
Privacy-conscious individuals: Users who prioritize data sovereignty and wish to avoid cloud-based file sharing services.
Professionals working in areas with poor connectivity: Engineers, field researchers, and others who frequently operate in locations with limited or no internet access.
Emergency responders and disaster relief workers: Critical personnel requiring reliable communication and data transfer capabilities when infrastructure is down.
Content creators sharing large files locally: Photographers, videographers, and designers who need to transfer large media files between devices or with collaborators without relying on internet bandwidth.
Educators and students in classroom settings: Facilitating file distribution and collection in environments where internet access might be restricted or unreliable.
6.2 Key Use Cases
Disaster Scenarios:
Description: Following a natural disaster (e.g., hurricane, earthquake), internet and cellular networks are down. Emergency responders need to share maps, casualty reports, and resource requests with teams in the field.
BitShare Role: BitShare enables rapid, secure, and offline transfer of these critical documents between responders, even across several hundred meters via multi-hop relaying.
Privacy-First Sharing:
Description: A journalist needs to securely share sensitive documents with a source without any digital footprint that could be intercepted by third parties or stored on cloud servers.
BitShare Role: Leveraging end-to-end encryption and direct Bluetooth mesh, BitShare provides a highly secure and private channel for transferring confidential files.
Bandwidth-Limited Environments:
Description: A student needs to transfer a large video file for a project to a classmate in the same building, but the campus Wi-Fi is slow or unreliable.
BitShare Role: BitShare allows for fast, local file transfer without consuming internet data or relying on congested Wi-Fi networks.
Local Collaboration:
Description: A design team needs to share large CAD files or project assets during a meeting in a conference room without an internet connection or secure local network.
BitShare Role: BitShare facilitates quick and efficient sharing of files directly between team members' devices, ensuring everyone has the latest versions.
Remote Area Operations:
Description: A geological survey team is collecting data in a remote area without cellular or Wi-Fi coverage and needs to transfer survey results from field devices to a central laptop for analysis.
BitShare Role: BitShare provides the sole reliable method for transferring collected data in such off-grid environments, ensuring data is not lost and can be processed.
7. Technical Architecture
7.1 Platform Strategy
Primary Platforms:
Native iOS Application: Targeting iPhone and iPad devices.
Native macOS Application: Targeting MacBook, iMac, and Mac mini devices.
Secondary (Limited Functionality):
Web Version with Limited Bluetooth Capabilities: A conceptual future consideration. This would primarily serve as a viewing portal or for very basic interactions, as full Bluetooth mesh capabilities are often restricted in web browsers.
Future Expansion:
Android Native App: A critical future step to complete the bit ecosystem, ensuring cross-platform interoperability.
7.2 Core Components (Modifying Bitchat Architecture)
BitShare's architecture will be built by directly modifying the existing Bitchat codebase. This approach ensures maximum consistency and leverages a proven foundation.
BitShare Architecture (Modified Bitchat):
├── UI Layer (Bitchat-identical design system) - UNCHANGED
│   ├── iOS UI (SwiftUI/UIKit) - UNCHANGED
│   └── macOS UI (SwiftUI/AppKit) - UNCHANGED
├── File Management Layer (chunking, integrity, progress) - ADDED/MODIFIED
│   ├── File I/O Management
│   ├── Chunking/Reassembly Engine
│   ├── SHA-256 Hashing Module
│   └── Transfer State Management (Pause/Resume, History)
├── Bluetooth Mesh Protocol (Bitchat-compatible) - UNCHANGED
│   ├── BLE Peripheral/Central Management - UNCHANGED
│   ├── Bitchat Protocol Encoding/Decoding - UNCHANGED (extended with new message types)
│   ├── TTL-based Routing Logic - UNCHANGED
│   └── Store-and-Forward Mechanism - UNCHANGED
├── Encryption Layer (same as Bitchat) - UNCHANGED
│   ├── X25519 Key Exchange Implementation - UNCHANGED
│   └── AES-256-GCM Encryption/Decryption - UNCHANGED
└── Storage Layer (temporary file handling) - ADDED/MODIFIED
    ├── Secure Temporary File Storage
    └── Received File Management


UI Layer: This layer will remain UNCHANGED from the Bitchat codebase in terms of components, styling, and animations. Modifications will involve replacing messaging-specific UI elements with file transfer specific ones while maintaining the exact visual patterns.
File Management Layer: This is a NEW/MODIFIED layer. It will replace Bitchat's message handling logic with comprehensive file transfer logic. This includes:
Handling file input/output.
Implementing the chunking of large files for transmission and reassembly upon reception.
Integrating SHA-256 hashing for integrity verification.
Managing the state of ongoing transfers (pause, resume, progress tracking, history).
Bluetooth Mesh Protocol Layer: This core communication engine will remain UNCHANGED from Bitchat. Its robust BLE peripheral/central management, Bitchat protocol encoding/decoding, TTL-based routing, and store-and-forward mechanisms will be directly reused. The protocol will be extended with new file-specific message types (FILE_MANIFEST, FILE_CHUNK, FILE_ACK) but the underlying transport and routing logic will be preserved.
Encryption Layer: This layer will be UNCHANGED, directly leveraging Bitchat's proven X25519 key exchange and AES-256-GCM encryption/decryption routines, ensuring consistent and strong security.
Storage Layer: This layer will be ADDED/MODIFIED to handle the temporary storage of file chunks during transfer and the secure storage of received files before they are made available to the user.
7.3 Integration Points
Full Protocol Compatibility with Bitchat Mesh Networks: BitShare will operate on the same Bluetooth mesh network as Bitchat, meaning any device running BitShare can participate in a Bitchat mesh, and vice versa.
Shared Peer Discovery: Users of BitShare should be visible to Bitchat users, and Bitchat users should be visible as potential transfer targets within BitShare. This enhances the density and utility of the shared mesh.
Cross-App Communication Capabilities: Explore mechanisms for Bitchat to launch BitShare for file transfer, or for BitShare to notify Bitchat of a completed transfer, fostering a truly integrated ecosystem.
7.4 Technical Unknowns
While leveraging the Bitchat codebase significantly de-risks development, certain technical unknowns inherent to Bluetooth mesh file transfer require ongoing investigation and realistic expectation setting:
BLE Throughput Limitations: The maximum effective throughput per hop over BLE is inherently limited. While 480-byte chunks are designed to fit MTU, the actual sustained data rate will depend on various factors including interference, distance, and concurrent connections. Realistic throughput expectations for large files need to be established through testing.
Expected Chunk Loss Rates and Retransmission Strategy Performance: Even with a store-and-forward mechanism, wireless environments can lead to packet loss. The performance of the retransmission strategy (based on FILE_ACK messages) will be critical for transfer success rates, especially in noisy environments or with many hops. This needs rigorous testing and potential optimization.
Multi-hop Latency Concerns: For transfers involving multiple hops (e.g., 5+ hops for a 10MB file), the cumulative latency due to processing, forwarding, and retransmissions at each intermediate node could significantly impact overall transfer time. Realistic expectations for transfer completion over long multi-hop paths must be defined.
Realistic Performance Expectations for KPIs: The target KPIs for average transfer speed and connection establishment time should be continuously re-evaluated against real-world performance data collected during development and testing, acknowledging the constraints of the underlying BLE mesh technology.
8. Success Metrics & KPIs
8.1 Adoption Metrics
Monthly Active Users (MAU) within Bit Ecosystem: Total unique users utilizing either Bitchat or BitShare (or both) in a given month. Target: Consistent month-over-month growth.
Cross-App Usage (BitShare + Bitchat Users): Percentage of users who actively use both BitShare and Bitchat. Target: >40% of BitShare users also using Bitchat.
Geographic Distribution and Mesh Network Density: Mapping user locations (anonymously) and analyzing the average number of peers discovered in various regions to understand mesh network growth.
Download Counts: Number of BitShare downloads from App Store and Mac App Store.
8.2 Performance Metrics
File Transfer Success Rate: Percentage of initiated file transfers that complete successfully without errors or corruption. Target: >95%.
Average Transfer Speed Over Mesh Hops: Measure of throughput for files transferred directly and with varying numbers of hops. Target: Optimize for speed given BLE constraints; measure against baseline for multi-hop.
Connection Establishment Time: Average time taken for two devices to establish a direct Bluetooth mesh connection. Target: <5 seconds.
Battery Usage Optimization: Monitor and minimize the power consumption of BitShare, especially during active transfers and background peer discovery. Target: Negligible impact on daily battery life.
8.3 Ecosystem Metrics
Number of Simultaneous Mesh Participants: Average and peak number of devices participating in a single BitShare/Bitchat mesh network.
Average Mesh Network Size and Hop Distance: Mean number of nodes in active meshes and the typical number of hops required for a message/chunk to reach its destination.
Cross-platform Compatibility Rates: Once Android is introduced, the percentage of successful transfers between iOS/macOS and Android devices.
Development Velocity: Time to MVP completion. Target: 10 weeks (vs. 3-4 months for building from scratch).
Code Reuse Percentage: The proportion of Bitchat's original codebase that is directly reused in BitShare. Target: >80%.
9. Development Roadmap (Fork-Based Approach)
The development roadmap is significantly accelerated and de-risked by leveraging the existing Bitchat codebase.
9.1 Phase 0: Setup & Analysis (Week 1)
Week 1:
Fork the entire Bitchat repository from GitHub.
Set up the development environment for iOS and macOS.
Conduct a thorough analysis of the Bitchat codebase structure, identifying key modules for UI, networking, encryption, and message handling.
Document areas for modification and extension.
9.2 Phase 1: UI & Core Logic Replacement (Weeks 2-4)
Week 2:
Replace Messaging UI with File Transfer UI: Modify the existing Bitchat UI views to accommodate file selection (drag-and-drop zones, file pickers), transfer progress indicators, and transfer history. Crucially, all UI components, design system, and visual elements will be kept 100% unchanged in their styling and animation patterns.
Example: struct BitchatMessageView will be conceptually replaced with struct BitShareFileView using the same underlying UI components.
Week 3:
Replace Messaging Logic with File Logic: Identify and refactor Bitchat's message sending/receiving logic.
Implement initial file reading and chunking on the sender side.
Implement initial chunk reception and temporary storage on the receiver side.
Example: func handleMessage() will be replaced with func handleFileTransfer().
Week 4:
Integrate basic file transfer flow (send a single file, receive a single file).
Implement SHA-256 hash calculation for integrity verification on send.
Basic progress tracking for single file transfers.
9.3 Phase 2: Protocol Extension & Advanced Features (Weeks 5-7)
Week 5:
Extend Protocol: Implement the new FILE_MANIFEST, FILE_CHUNK, and FILE_ACK message types within the existing Bitchat binary protocol structure.
Integrate these new message types into the modified file transfer logic.
Week 6:
Implement robust reassembly logic for received file chunks.
Implement SHA-256 hash verification on the receiver side.
Develop multi-file transfer capabilities.
Week 7:
Implement pause/resume functionality for active transfers.
Develop transfer history and retry mechanisms.
Refine automatic transport optimization (direct vs. multi-hop) leveraging Bitchat's routing.
9.4 Phase 3: Testing, Refinement & Launch (Weeks 8-10)
Week 8:
Comprehensive internal testing across various iOS and macOS devices.
Extensive cross-app compatibility testing with Bitchat (ensuring shared peer discovery and mesh interoperability).
Week 9:
User acceptance testing (UAT) with a select group of external testers.
Address UAT feedback and perform final bug fixes.
Optimize performance and battery usage.
Week 10:
Prepare App Store and Mac App Store submissions (metadata, screenshots, privacy policy).
Final security audit.
App Store and Mac App Store submission and launch.
9.5 Phase 4: Expansion (Ongoing)
Ongoing:
Development of additional "bit ecosystem" apps (e.g., BitPad for collaborative document editing, BitCall for offline voice calls).
Implementation of advanced mesh networking features (e.g., dynamic routing, larger mesh sizes).
Explore enterprise and government partnerships for specialized offline solutions.
Android native app development to complete the primary platform strategy.
10. Strategic Considerations
10.1 Ecosystem Strategy
Complementary, Not Competitive: BitShare is positioned as a natural extension of Bitchat's capabilities, not a competitor. Its value proposition is enhanced by Bitchat's existence.
Protocol Compatibility for Shared Mesh: Strict adherence to the Bitchat protocol ensures that both applications contribute to and benefit from a single, growing Bluetooth mesh network, increasing the utility and reach for all users.
Contribute Improvements Back: Any optimizations or enhancements discovered during BitShare's development related to the core Bluetooth mesh protocol will be documented and potentially contributed back to the Bitchat project (or a shared underlying protocol library).
Foundation for Future Apps: BitShare will establish a reusable architectural pattern and set of libraries that can accelerate the development of subsequent "bit ecosystem" applications.
10.2 Business Model
BitShare is fundamentally an open-source, community-driven project built for the benefit of humanity, not for profit.
No Stakeholders or VC Funding: The project is not driven by external investors or profit motives. Its existence is sustained by community effort and the shared vision of a decentralized, offline-first future.
Community Contributions Welcome: Development will be entirely open, encouraging contributions from developers worldwide. Guidelines for contribution will be clearly published to facilitate this process.
Built for Humanity's Benefit, Not Profit: The primary goal is to provide a vital tool for communication and data exchange in scenarios where traditional infrastructure is unavailable or compromised, aligning with the principles of decentralization and digital freedom.
Potential Enterprise Support/Customization Services Only: While the core application remains free and open, there may be future opportunities to offer paid enterprise support, consulting, or custom development services to organizations (e.g., emergency services, NGOs) that require specialized deployments or integrations. This would be a service-based model, not a product-licensing model for the core application.
10.3 Risk Mitigation
Technical Risks:
Challenge: Fork Maintenance and Upstream Sync: Keeping BitShare's codebase synchronized with potential updates or bug fixes in the original Bitchat repository.
Mitigation: Maintain a clean and modular separation between the core Bitchat protocol/UI components (which remain largely unchanged) and the new file transfer specific logic. Regularly pull updates from the upstream Bitchat repository and carefully merge changes. Automated testing will be crucial to detect regressions.
Challenge: Optimizing performance for large file transfers over BLE's inherent bandwidth limitations and multi-hop latency.
Mitigation: Aggressive chunking, efficient retransmission strategies, and careful management of concurrent transfers. Prioritize native code for performance-critical sections.
Legal Risks:
Challenge: Ensuring compliance with open-source licenses used by Bitchat and other libraries.
Mitigation: Maintain an open-source approach for BitShare where feasible, ensuring proper attribution and license compliance for all third-party components. Consult with legal counsel regarding intellectual property and open-source licensing.
Market Risks:
Challenge: User adoption in a niche "offline-first" market.
Mitigation: Focus on clearly communicating the unique value proposition for underserved offline use cases. Leverage the existing Bitchat user base for initial adoption. Strategic partnerships with organizations that operate in offline environments.
11. Regulatory & Compliance
11.1 Privacy Requirements
Adherence to the highest privacy standards is non-negotiable, aligning with the ethos of Bitchat.
No Data Collection or Analytics: BitShare will not collect any user data, usage statistics, or analytics. This significantly simplifies privacy compliance requirements.
Local-Only File Storage: All file data (transferred or received) will reside exclusively on the user's local device. No cloud storage or remote servers will be involved. This local-only operation inherently reduces regulatory complexity associated with data storage and cross-border data transfer.
End-to-End Encryption Mandatory: All file transfers, including metadata, must be encrypted from the sender's device to the receiver's device using the specified Bitchat encryption model. No unencrypted data should traverse the mesh.
11.2 Platform Compliance
iOS App Store Guidelines Compliance:
Adhere to all Apple Human Interface Guidelines for design and functionality.
Comply with privacy policies regarding Bluetooth usage (e.g., requesting necessary permissions clearly).
Ensure robust error handling and stability to meet review criteria.
Provide clear and accurate app descriptions and screenshots.
App Store Export Compliance for Encryption: If applicable based on the specific cryptographic implementations, ensure compliance with Apple's export regulations for apps containing encryption. This typically involves submitting an annual self-classification report.
macOS Security Requirements:
Ensure notarization for macOS for enhanced security and user trust.
Comply with sandbox requirements and permission requests (e.g., file system access).
Bluetooth Usage Permissions and Privacy Notices:
Clearly inform users about the need for Bluetooth permissions for BitShare to function.
Provide a transparent and concise privacy policy that explicitly states no data collection and local-only operations.
12. Legal & Attribution
Given the decision to fork Jack Dorsey's open-source Bitchat codebase, the following legal and attribution considerations are paramount.
12.1 The Unlicense (Public Domain Dedication)
The original Bitchat project, as released by Jack Dorsey, operates under The Unlicense, which explicitly dedicates the software to the public domain. BitShare adopts this same public domain dedication unmodified, ensuring it remains free and unencumbered software for the benefit of humanity, not shareholders.
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.


For more information, please refer to https://unlicense.org
12.2 Ethical Attribution Statement
While The Unlicense does not legally require attribution, BitShare will explicitly and prominently attribute Jack Dorsey and Bitchat as the foundational work. This ethical attribution will be included in the application's "About" section, documentation, and relevant code comments, out of respect for the original creator and to acknowledge the origin of the core technology.
12.3 Warranty Disclaimer Emphasis
It is critical for all users and contributors to understand that THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED. This means that the authors and contributors are not liable for any claims, damages, or other liabilities arising from the use or other dealings in the software. Users assume all risks associated with the software's quality and performance.
12.4 Clear Documentation of Modifications
All significant modifications made to the original Bitchat codebase will be clearly documented within the BitShare repository. This includes comments in the code, commit messages, and a dedicated CHANGELOG.md or MODIFICATIONS.md file detailing the changes from the upstream Bitchat.
12.5 Contribution Strategy
We are committed to fostering the broader bit ecosystem. Any improvements, bug fixes, or general enhancements to the core Bluetooth mesh protocol or shared components that arise during BitShare's development will be considered for contribution back to the original Bitchat project (if applicable and welcomed by the maintainers) or released as open-source components for the benefit of the entire ecosystem.
13. Technical Benefits of Forking
The decision to fork the Bitchat codebase offers significant advantages for BitShare's development:
Guaranteed UI Consistency: By reusing Bitchat's exact UI components and design system, BitShare will achieve 100% visual and interaction consistency with Bitchat effortlessly. There is no need to recreate or meticulously match design elements, ensuring a cohesive ecosystem experience from day one.
Proven Protocol: The complex and battle-tested Bluetooth mesh protocol, networking, and encryption layers from Bitchat are directly inherited. This eliminates the need to reimplement intricate low-level communication logic, saving immense development time and reducing the risk of introducing new bugs in critical components.
Faster Development: This approach dramatically accelerates the development timeline. We anticipate reaching an MVP in 3-4 weeks for core functionality, compared to an estimated 3-4 months for building from scratch. This allows for quicker iteration and market entry.
Lower Risk: Building on a battle-tested foundation significantly lowers technical risks. The core communication and security mechanisms have already been proven in Bitchat, allowing the BitShare team to focus primarily on the file transfer-specific logic.
Perfect Ecosystem Integration: Sharing the same underlying codebase patterns and protocol ensures seamless integration with Bitchat. This facilitates shared peer discovery and lays the groundwork for more advanced cross-app communication features in the future.
Specific Implementation Details (Conceptual Example):
// Example of modification approach within the forked Bitchat codebase:

// KEEP: All UI components exactly as-is. We will repurpose them.
// For instance, a BitchatMessageView might be adapted to display file transfer status.
// No changes to the underlying SwiftUI/UIKit component definitions.
// struct BitchatMessageView -> struct BitShareFileTransferStatusView (conceptually, same visual components)

// KEEP: All networking code exactly as-is. We will extend its message types.
enum MessageType {
    case message        // ← Keep existing Bitchat message type
    case fileManifest   // ← Add new file-specific message type
    case fileChunk      // ← Add new file-specific message type
    case fileAck        // ← Add new file-specific message type
}

// MODIFY: Replace messaging logic with file transfer logic in relevant areas.
// Instead of handling text messages, this function will now manage file chunks.
func handleIncomingPayload(payload: Data) {
    // Original Bitchat logic might parse for 'message' type and display chat.
    // New BitShare logic will parse for 'fileManifest', 'fileChunk', 'fileAck'.
    switch parseMessageType(payload) {
    case .message:
        // Original Bitchat message handling (will be mostly removed or isolated for BitShare)
        // displayChatMessage(payload)
        break // Or handle as an error if only file types are expected in BitShare
    case .fileManifest:
        processFileManifest(payload)
    case .fileChunk:
        processFileChunk(payload)
    case .fileAck:
        processFileAck(payload)
    }
}

// ADD: New functions for file-specific logic
func processFileManifest(data: Data) { /* ... parse manifest, prepare for reception ... */ }
func processFileChunk(data: Data) { /* ... store chunk, update progress ... */ }
func processFileAck(data: Data) { /* ... mark chunk as sent, manage retransmissions ... */ }

// MODIFY: Original Bitchat send function will be adapted to send file chunks.
func sendFile(file: URL, to peer: Peer) {
    // Break file into chunks
    let chunks = chunkFile(file)
    // Send FILE_MANIFEST
    sendProtocolMessage(.fileManifest, manifestData)
    // Send FILE_CHUNKs
    for chunk in chunks {
        sendProtocolMessage(.fileChunk, chunkData)
    }
}


14. Community-Driven Development Model
BitShare is envisioned as a truly open-source, community-driven project, aligning with the spirit of Jack Dorsey's public domain release of Bitchat.
Open Source Development Approach: The entire codebase will be publicly available on a platform like GitHub. All development will occur transparently, with public repositories, issue trackers, and pull request processes.
Community Contribution Guidelines: Clear and comprehensive guidelines will be established to facilitate external contributions. These will cover coding standards, pull request submission processes, testing requirements, and communication channels.
Public Development Process: Design discussions, technical decisions, and roadmap planning will be conducted in public forums (e.g., GitHub discussions, community calls) to ensure transparency and allow for broad community input.
Alignment with Jack's Public Domain Vision: By operating under a public domain license (or a similarly permissive open-source license if the fork requires it), BitShare will embody the principles of free and unencumbered software, ensuring it remains a tool for collective benefit without proprietary restrictions. This fosters innovation and widespread adoption within the decentralized ecosystem.
15. Conclusion
BitShare represents a critical expansion of the "bit ecosystem," addressing the fundamental need for reliable, secure, and offline file sharing. By meticulously forking and modifying Bitchat's established codebase, BitShare will not only deliver a robust application with unparalleled consistency but also significantly accelerate its development timeline and de-risk its technical foundation. This PRD provides a comprehensive blueprint for its development, emphasizing technical excellence, user-centric design, and strategic alignment with the broader ecosystem vision. The successful implementation of BitShare will solidify the foundation for future innovations in decentralized, off-grid applications.
