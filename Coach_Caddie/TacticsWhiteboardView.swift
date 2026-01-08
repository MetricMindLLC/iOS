import SwiftUI
import PhotosUI
import AVFoundation

// MARK: - Animation Video Recorder
class AnimationVideoRecorder {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    private var videoSize: CGSize = CGSize(width: 720, height: 960)
    private var frameRate: Double = 30.0
    
    private var tempFileURL: URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("tactics_animation_\(UUID().uuidString).mp4")
    }
    
    private var currentFileURL: URL?
    
    var onProgress: ((Double) -> Void)?
    var onComplete: ((URL?, Error?) -> Void)?
    
    func renderAnimation(
        team: Team,
        drawings: [DrawingPath],
        animationSequence: AnimationSequence,
        initialPlayerPositions: [UUID: CGPoint],
        initialOpponentPositions: [Int: CGPoint],
        initialBallPosition: CGPoint?,
        opponentColor: Color,
        fieldSize: CGSize,
        speed: Double = 1.0  // ADD THIS PARAMETER
    ) {
        // Calculate video size maintaining aspect ratio
        let aspectRatio = fieldSize.height / fieldSize.width
        videoSize = CGSize(width: 720, height: ceil(720 * aspectRatio / 2) * 2)
        
        currentFileURL = tempFileURL
        guard let fileURL = currentFileURL else { return }
        
        // Remove existing file if any
        try? FileManager.default.removeItem(at: fileURL)
        
        do {
            assetWriter = try AVAssetWriter(outputURL: fileURL, fileType: .mp4)
            
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: videoSize.width,
                AVVideoHeightKey: videoSize.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 3000000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]
            
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput?.expectsMediaDataInRealTime = false
            
            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: videoSize.width,
                kCVPixelBufferHeightKey as String: videoSize.height
            ]
            
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput!,
                sourcePixelBufferAttributes: sourcePixelBufferAttributes
            )
            
            if assetWriter!.canAdd(videoInput!) {
                assetWriter!.add(videoInput!)
            }
            
            assetWriter!.startWriting()
            assetWriter!.startSession(atSourceTime: .zero)
            
            // Render frames on background queue
            DispatchQueue.global(qos: .userInitiated).async {
                self.renderFrames(
                    team: team,
                    drawings: drawings,
                    animationSequence: animationSequence,
                    initialPlayerPositions: initialPlayerPositions,
                    initialOpponentPositions: initialOpponentPositions,
                    initialBallPosition: initialBallPosition,
                    opponentColor: opponentColor,
                    fieldSize: fieldSize,
                    speed: speed  // PASS SPEED
                )
            }
            
        } catch {
            onComplete?(nil, error)
        }
    }
    
    private func renderFrames(
        team: Team,
        drawings: [DrawingPath],
        animationSequence: AnimationSequence,
        initialPlayerPositions: [UUID: CGPoint],
        initialOpponentPositions: [Int: CGPoint],
        initialBallPosition: CGPoint?,
        opponentColor: Color,
        fieldSize: CGSize,
        speed: Double
    ) {
        let timing = animationSequence.calculatePlaybackTiming()
        let baseDuration = max(animationSequence.totalDuration, 1.0)
        let totalDuration = (baseDuration / speed) + 0.5
        let totalFrames = Int(totalDuration * frameRate)
        
        let scaleX = videoSize.width / fieldSize.width
        let scaleY = videoSize.height / fieldSize.height
        
        for frameIndex in 0..<totalFrames {
            let frameTime = Double(frameIndex) / frameRate
            let progress = min(frameTime / (totalDuration - 0.5), 1.0)
            
            // Calculate positions at this time
            var playerPositions = initialPlayerPositions
            var opponentPositions = initialOpponentPositions
            var ballPosition = initialBallPosition
            var ballCarrier = animationSequence.ballCarrier
            
            // Update positions based on animation paths
            let currentTime = progress * baseDuration
            
            for (step, startTime, endTime) in timing {
                let path = step.path
                
                guard currentTime >= startTime else { continue }
                
                let pathProgress: Double
                if currentTime >= endTime {
                    pathProgress = 1.0
                } else {
                    pathProgress = (currentTime - startTime) / path.duration
                }
                
                if let position = path.position(at: pathProgress) {
                    // Scale position to video size
                    let scaledPosition = CGPoint(
                        x: position.x * scaleX,
                        y: position.y * scaleY
                    )
                    
                    switch path.chipId {
                    case .player(let uuid):
                        playerPositions[uuid] = scaledPosition
                        if ballCarrier == .player(uuid) && path.pathType == .dribble {
                            ballPosition = CGPoint(x: scaledPosition.x + 16, y: scaledPosition.y + 16)
                        }
                    case .opponent(let number):
                        opponentPositions[number] = scaledPosition
                        if ballCarrier == .opponent(number) && path.pathType == .dribble {
                            ballPosition = CGPoint(x: scaledPosition.x + 14, y: scaledPosition.y + 14)
                        }
                    case .ball:
                        ballPosition = scaledPosition
                        if pathProgress > 0 && pathProgress < 1.0 {
                            ballCarrier = nil
                        }
                        if path.pathType == .pass && pathProgress >= 1.0, let target = path.passTargetChipId {
                            ballCarrier = target
                        }
                        if path.pathType == .shot && pathProgress >= 1.0 {
                            ballCarrier = nil
                        }
                    }
                }
            }
            
            // Scale initial positions that haven't been animated
            var scaledPlayerPositions: [UUID: CGPoint] = [:]
            for (id, pos) in playerPositions {
                if initialPlayerPositions[id] == pos {
                    scaledPlayerPositions[id] = CGPoint(x: pos.x * scaleX, y: pos.y * scaleY)
                } else {
                    scaledPlayerPositions[id] = pos
                }
            }
            
            var scaledOpponentPositions: [Int: CGPoint] = [:]
            for (num, pos) in opponentPositions {
                if initialOpponentPositions[num] == pos {
                    scaledOpponentPositions[num] = CGPoint(x: pos.x * scaleX, y: pos.y * scaleY)
                } else {
                    scaledOpponentPositions[num] = pos
                }
            }
            
            var scaledBallPosition: CGPoint? = nil
            if let bp = ballPosition {
                if initialBallPosition == bp {
                    scaledBallPosition = CGPoint(x: bp.x * scaleX, y: bp.y * scaleY)
                } else {
                    scaledBallPosition = bp
                }
            }
            
            // Scale drawings
            let scaledDrawings = drawings.map { drawing -> DrawingPath in
                var scaled = drawing
                scaled.points = drawing.points.map { CGPoint(x: $0.x * scaleX, y: $0.y * scaleY) }
                return scaled
            }
            
            // Scale animation paths
            let scaledAnimationPaths = animationSequence.steps.map { step -> AnimationPath in
                var scaled = step.path
                scaled.points = step.path.points.map { CGPoint(x: $0.x * scaleX, y: $0.y * scaleY) }
                return scaled
            }
            
            // Render frame on main thread
            DispatchQueue.main.sync {
                let frameView = AnimationFrameView(
                    team: team,
                    drawings: scaledDrawings,
                    animationPaths: scaledAnimationPaths,
                    playerPositions: scaledPlayerPositions,
                    opponentPositions: scaledOpponentPositions,
                    ballPosition: scaledBallPosition,
                    opponentColor: opponentColor,
                    ballCarrier: ballCarrier,
                    size: videoSize
                )
                
                let renderer = ImageRenderer(content: frameView)
                renderer.scale = 2.0
                
                if let cgImage = renderer.cgImage {
                    self.appendFrame(cgImage, at: frameIndex)
                }
            }
            
            // Report progress
            let progressValue = Double(frameIndex) / Double(totalFrames)
            DispatchQueue.main.async {
                self.onProgress?(progressValue)
            }
        }
        
        // Finish writing
        videoInput?.markAsFinished()
        assetWriter?.finishWriting { [weak self] in
            DispatchQueue.main.async {
                if self?.assetWriter?.status == .completed {
                    self?.onComplete?(self?.currentFileURL, nil)
                } else {
                    self?.onComplete?(nil, self?.assetWriter?.error)
                }
            }
        }
    }
    
    private func appendFrame(_ cgImage: CGImage, at frameIndex: Int) {
        guard let adaptor = pixelBufferAdaptor,
              let input = videoInput else { return }
        
        while !input.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        guard let pixelBuffer = createPixelBuffer(from: cgImage) else { return }
        
        let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(frameRate))
        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
    }
    
    private func createPixelBuffer(from cgImage: CGImage) -> CVPixelBuffer? {
        let width = Int(videoSize.width)
        let height = Int(videoSize.height)
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true
            ] as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }
        
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return buffer
    }
}

struct TacticsWhiteboardView: View {
    @Binding var team: Team
    var onDismiss: (() -> Void)? = nil
    
    // MARK: - Drawing State
    @State private var drawings: [DrawingPath] = []
    @State private var currentDrawing: DrawingPath?
    @State private var selectedColor: Color = .white
    @State private var selectedLineWidth: CGFloat = 3.0
    @State private var isDrawingMode: Bool = false
    
    
    // MARK: - Chip Positions
    @State private var playerChipPositions: [UUID: CGPoint] = [:]
    @State private var opponentChipPositions: [Int: CGPoint] = [:]
    @State private var ballPosition: CGPoint? = nil
    
    // MARK: - UI State
    @State private var showingColorPicker: Bool = false
    @State private var showingPlayerTray: Bool = true
    @State private var showingSaveSuccess: Bool = false
    @State private var showingSaveError: Bool = false
    @State private var saveErrorMessage: String = ""
    @State private var opponentColor: Color = .gray
    @State private var isDraggingChip: Bool = false
    
    // MARK: - Animation State
    @State private var isAnimationMode: Bool = false
    @State private var isPlaying: Bool = false
    @StateObject private var animationSequence: AnimationSequence = AnimationSequence()
    @State private var selectedChipForPath: ChipIdentifier? = nil
    @State private var currentPathType: PathType = .run
    @State private var currentAnimationPath: AnimationPath? = nil
    @State private var playbackProgress: Double = 0.0
    @State private var playbackTimer: Timer? = nil
    @State private var showingChipMenu: Bool = false
    @State private var chipMenuPosition: CGPoint = .zero
    @State private var isSelectingPassTarget: Bool = false
    @State private var pendingPassPath: AnimationPath? = nil
    @State private var addToCurrentStep: Bool = false
    @State private var isRecordingVideo: Bool = false
    @State private var recordingProgress: Double = 0.0
    @State private var showingVideoSaved: Bool = false
    @State private var showingVideoError: Bool = false
    @State private var videoErrorMessage: String = ""
    @State private var videoRecorder = AnimationVideoRecorder()
    @State private var fieldSize: CGSize = .zero
    @State private var animationSpeed: Double = 1.0
    
    // Store original positions for playback reset
    @State private var originalPlayerPositions: [UUID: CGPoint] = [:]
    @State private var originalOpponentPositions: [Int: CGPoint] = [:]
    @State private var originalBallPosition: CGPoint? = nil
    
    // MARK: - Playback State
    @State private var playbackPlayerPositions: [UUID: CGPoint] = [:]
    @State private var playbackOpponentPositions: [Int: CGPoint] = [:]
    @State private var playbackBallPosition: CGPoint? = nil
    @State private var playbackBallCarrier: ChipIdentifier? = nil
    
    // Available drawing colors
    let drawingColors: [Color] = [.white, .yellow, .red, .blue, .orange, .green, .purple]
    let lineWidths: [CGFloat] = [2.0, 4.0, 6.0, 8.0]
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button(action: { onDismiss?() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Overview")
                                .font(.system(size: 17))
                        }
                        .foregroundColor(team.primaryColor)
                    }
                    .disabled(isPlaying)
                    .opacity(isPlaying ? 0.5 : 1)
                    
                    Spacer()
                    
                    Text(isAnimationMode ? "Animate Play" : "Tactics Board")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Invisible placeholder for balance
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Overview")
                            .font(.system(size: 17))
                    }
                    .opacity(0)
                    .allowsHitTesting(false)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                
                // Field Area
                GeometryReader { geometry in
                    ZStack {
                        // Field background
                        WhiteboardFieldView()
                            .cornerRadius(12)
                            .padding(8)
                        
                        // MARK: - Drawing Mode
                        if isDrawingMode {
                            DrawingCanvasView(
                                drawings: $drawings,
                                currentDrawing: $currentDrawing,
                                selectedColor: selectedColor,
                                selectedLineWidth: selectedLineWidth,
                                isDrawingMode: isDrawingMode
                            )
                            .padding(8)
                            
                            StaticChipsView(
                                team: team,
                                playerChipPositions: playerChipPositions,
                                opponentChipPositions: opponentChipPositions,
                                ballPosition: ballPosition,
                                opponentColor: opponentColor
                            )
                            .padding(8)
                        }
                        // MARK: - Animation Mode (Not Playing)
                        else if isAnimationMode && !isPlaying {
                            // Show existing drawings
                            ForEach(drawings) { drawing in
                                DrawingPathShape(points: drawing.points)
                                    .stroke(drawing.color, style: StrokeStyle(
                                        lineWidth: drawing.lineWidth,
                                        lineCap: .round,
                                        lineJoin: .round
                                    ))
                                    .padding(8)
                            }
                            
                            // Show animation paths with sequence numbers
                            ForEach(animationSequence.steps) { step in
                                ZStack {
                                    AnimationPathView(
                                        path: step.path,
                                        isActive: selectedChipForPath == step.path.chipId
                                    )
                                    
                                    // Sequence number badge
                                    if let startPoint = step.path.startPoint {
                                        SequenceNumberBadge(number: step.order + 1)
                                            .position(x: startPoint.x + 20, y: startPoint.y - 20)
                                    }
                                }
                                .padding(8)
                            }
                            
                            // Current path being drawn
                            if let currentPath = currentAnimationPath {
                                AnimationPathView(
                                    path: currentPath,
                                    isActive: true
                                )
                                .padding(8)
                            }
                            
                            // Path drawing canvas (when chip selected and menu dismissed, not selecting pass target)
                            if selectedChipForPath != nil && !showingChipMenu && !isSelectingPassTarget {
                                AnimationPathDrawingCanvas(
                                    currentPath: $currentAnimationPath,
                                    selectedChip: selectedChipForPath,
                                    pathType: currentPathType,
                                    startPosition: getChipPosition(selectedChipForPath),
                                    onPathCompleted: { path in
                                        handlePathCompleted(path)
                                    }
                                )
                                .padding(8)
                            }
                            
                            // Selectable chips
                            AnimationChipsLayerView(
                                team: team,
                                playerChipPositions: playerChipPositions,
                                opponentChipPositions: opponentChipPositions,
                                ballPosition: ballPosition,
                                opponentColor: opponentColor,
                                selectedChip: selectedChipForPath,
                                ballCarrier: animationSequence.ballCarrier,
                                isSelectingPassTarget: isSelectingPassTarget,
                                onChipTapped: { chipId, position in
                                    if !isSelectingPassTarget {
                                        selectedChipForPath = chipId
                                        chipMenuPosition = position
                                        showingChipMenu = true
                                    }
                                },
                                onPassTargetSelected: { targetChipId, targetPosition in
                                    completePassToTarget(targetChipId, at: targetPosition)
                                }
                            )
                            .padding(8)
                            
                            // Pass target selection overlay
                            if isSelectingPassTarget {
                                PassTargetSelectionView(
                                    message: "Tap a player to pass to",
                                    onCancel: {
                                        isSelectingPassTarget = false
                                        pendingPassPath = nil
                                        selectedChipForPath = nil
                                    }
                                )
                            }
                            
                            // Chip action menu
                            if showingChipMenu, let chipId = selectedChipForPath {
                                ChipActionMenu(
                                    chipId: chipId,
                                    position: chipMenuPosition,
                                    hasBall: animationSequence.ballCarrier == chipId,
                                    hasExistingPaths: animationSequence.steps.contains { $0.path.chipId == chipId },
                                    onSelectAction: { pathType in
                                        currentPathType = pathType
                                        showingChipMenu = false
                                        
                                        // For pass, we need to handle specially
                                        if pathType == .pass {
                                            // Will draw pass path, then select target
                                        }
                                    },
                                    onSetBallCarrier: {
                                        animationSequence.ballCarrier = chipId
                                        showingChipMenu = false
                                        selectedChipForPath = nil
                                    },
                                    onRemovePaths: {
                                        animationSequence.steps.removeAll { $0.path.chipId == chipId }
                                        showingChipMenu = false
                                        selectedChipForPath = nil
                                    },
                                    onDismiss: {
                                        showingChipMenu = false
                                        selectedChipForPath = nil
                                    }
                                )
                            }
                        }
                        // MARK: - Animation Playback
                        else if isPlaying {
                            // Show existing drawings
                            ForEach(drawings) { drawing in
                                DrawingPathShape(points: drawing.points)
                                    .stroke(drawing.color, style: StrokeStyle(
                                        lineWidth: drawing.lineWidth,
                                        lineCap: .round,
                                        lineJoin: .round
                                    ))
                                    .padding(8)
                            }
                            
                            // Show animation paths (faded during playback)
                            ForEach(animationSequence.steps) { step in
                                AnimationPathView(path: step.path, isActive: false)
                                    .opacity(0.3)
                                    .padding(8)
                            }
                            
                            // Animated chips
                            PlaybackChipsLayerView(
                                team: team,
                                playerPositions: playbackPlayerPositions,
                                opponentPositions: playbackOpponentPositions,
                                ballPosition: playbackBallPosition,
                                opponentColor: opponentColor,
                                ballCarrier: playbackBallCarrier
                            )
                            .padding(8)
                        }
                        // MARK: - Move Mode (Default)
                        else {
                            // Drawings (static when moving)
                            ForEach(drawings) { drawing in
                                DrawingPathShape(points: drawing.points)
                                    .stroke(drawing.color, style: StrokeStyle(
                                        lineWidth: drawing.lineWidth,
                                        lineCap: .round,
                                        lineJoin: .round
                                    ))
                                    .padding(8)
                            }
                            
                            // Interactive chips
                            ChipsLayerView(
                                team: team,
                                playerChipPositions: $playerChipPositions,
                                opponentChipPositions: $opponentChipPositions,
                                ballPosition: $ballPosition,
                                opponentColor: opponentColor,
                                fieldSize: CGSize(
                                    width: geometry.size.width - 16,
                                    height: geometry.size.height
                                ),
                                isDraggingChip: $isDraggingChip
                            )
                            .padding(8)
                        }
                    }
                    .onAppear {
                        fieldSize = CGSize(width: geometry.size.width - 16, height: geometry.size.height)
                    }
                    .onChange(of: geometry.size) { newSize in
                        fieldSize = CGSize(width: newSize.width - 16, height: newSize.height)
                    }
                }
                
                WhiteboardToolbar(
                    isDrawingMode: $isDrawingMode,
                    isAnimationMode: $isAnimationMode,
                    isPlaying: $isPlaying,
                    selectedColor: $selectedColor,
                    selectedLineWidth: $selectedLineWidth,
                    showingPlayerTray: $showingPlayerTray,
                    isDraggingChip: $isDraggingChip,
                    addToCurrentStep: $addToCurrentStep,
                    isRecordingVideo: $isRecordingVideo,
                    recordingProgress: $recordingProgress,
                    animationSpeed: $animationSpeed,  // ADD THIS
                    hasAnimationPaths: !animationSequence.steps.isEmpty,
                    onUndo: {
                        if isAnimationMode {
                            undoLastAnimationStep()
                        } else {
                            undoLastDrawing()
                        }
                    },
                    onClear: clearAllDrawings,
                    onSave: saveToPhotos,
                    onPlay: startPlayback,
                    onStop: stopPlayback,
                    onClearPaths: clearAnimationPaths,
                    onRecordVideo: recordAnimation
                )
                
                // Chip Tray (only visible when not drawing, not animating, and tray is shown)
                if !isDrawingMode && !isAnimationMode && showingPlayerTray {
                    ChipTrayView(
                        team: team,
                        playerChipPositions: $playerChipPositions,
                        opponentChipPositions: $opponentChipPositions,
                        ballPosition: $ballPosition,
                        opponentColor: $opponentColor
                    )
                    .frame(height: 110)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Saved!", isPresented: $showingSaveSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Tactics board saved to your photo library.")
        }
        .alert("Error", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage)
        }
        .alert("Video Saved!", isPresented: $showingVideoSaved) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your tactics animation has been saved to your photo library.")
        }
        .alert("Video Error", isPresented: $showingVideoError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(videoErrorMessage)
        }
    }
    
    // MARK: - Actions
    
    private func undoLastDrawing() {
        if !drawings.isEmpty {
            drawings.removeLast()
        }
    }
    
    private func clearAllDrawings() {
        drawings.removeAll()
    }
    
    private func resetBoard() {
        drawings.removeAll()
        playerChipPositions.removeAll()
        opponentChipPositions.removeAll()
        ballPosition = nil
    }
    
    private func saveToPhotos() {
        let renderer = ImageRenderer(content: WhiteboardSnapshotView(
            team: team,
            drawings: drawings,
            playerChipPositions: playerChipPositions,
            opponentChipPositions: opponentChipPositions,
            ballPosition: ballPosition,
            opponentColor: opponentColor
        ))
        
        renderer.scale = UIScreen.main.scale
        
        if let uiImage = renderer.uiImage {
            // Request photo library permission and save
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                DispatchQueue.main.async {
                    if status == .authorized || status == .limited {
                        UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                        showingSaveSuccess = true
                    } else {
                        saveErrorMessage = "Please allow photo library access in Settings to save images."
                        showingSaveError = true
                    }
                }
            }
        } else {
            saveErrorMessage = "Failed to capture the tactics board."
            showingSaveError = true
        }
    }
    
    // MARK: - Animation Actions
    
    private func getChipPosition(_ chipId: ChipIdentifier?) -> CGPoint? {
        guard let chipId = chipId else { return nil }
        
        // First check if there's an existing path for this chip - use its endpoint
        if let lastStep = animationSequence.steps.last(where: { $0.path.chipId == chipId }),
           let endPoint = lastStep.path.endPoint {
            return endPoint
        }
        
        // Otherwise use current position
        switch chipId {
        case .player(let uuid):
            return playerChipPositions[uuid]
        case .opponent(let number):
            return opponentChipPositions[number]
        case .ball:
            return ballPosition
        }
    }
    
    private func handlePathCompleted(_ path: AnimationPath) {
        var newPath = path
        newPath.sequenceOrder = addToCurrentStep ? max(0, animationSequence.nextSequenceOrder - 1) : animationSequence.nextSequenceOrder
        
        // Calculate duration based on path length
        let length = calculatePathLength(path.points)
        newPath.duration = max(1.0, min(4.0, length / 80.0))
        
        if path.pathType == .pass {
            // For pass, the ball moves - not the player
            // Store who kicked it, but chipId is the ball
            newPath.sourceChipId = selectedChipForPath
            newPath.chipId = .ball
            
            // We need to select a target
            pendingPassPath = newPath
            isSelectingPassTarget = true
        } else if path.pathType == .shot {
            // For shot, the ball moves to the drawn endpoint
            newPath.sourceChipId = selectedChipForPath
            newPath.chipId = .ball
            
            // Add the step directly (no target selection needed)
            let step = AnimationStep(path: newPath, order: newPath.sequenceOrder)
            animationSequence.addStep(step)
            
            // Ball is no longer carried after shot
            animationSequence.ballCarrier = nil
            selectedChipForPath = nil
        } else {
            // Run or Dribble - add the step directly
            let step = AnimationStep(path: newPath, order: newPath.sequenceOrder)
            animationSequence.addStep(step)
            selectedChipForPath = nil
        }
    }
    
    private func completePassToTarget(_ targetChipId: ChipIdentifier, at targetPosition: CGPoint) {
        guard var passPath = pendingPassPath else { return }
        
        // Update pass path to end at target position
        if passPath.points.count > 0 {
            passPath.points[passPath.points.count - 1] = targetPosition
        }
        passPath.passTargetChipId = targetChipId
        
        // Add the pass step
        let step = AnimationStep(path: passPath, order: passPath.sequenceOrder)
        animationSequence.addStep(step)
        
        // Ball carrier transfers to target after pass
        animationSequence.ballCarrier = targetChipId
        
        // Reset state
        isSelectingPassTarget = false
        pendingPassPath = nil
        selectedChipForPath = nil
    }
    
    private func calculatePathLength(_ points: [CGPoint]) -> Double {
        var length: Double = 0
        for i in 1..<points.count {
            let dx = points[i].x - points[i-1].x
            let dy = points[i].y - points[i-1].y
            length += sqrt(dx*dx + dy*dy)
        }
        return length
    }
    
    private func clearAnimationPaths() {
        animationSequence.clearAll()
        selectedChipForPath = nil
        showingChipMenu = false
        currentAnimationPath = nil
        isSelectingPassTarget = false
        pendingPassPath = nil
    }
    
    private func undoLastAnimationStep() {
        animationSequence.removeLastStep()
    }
    
    private func startPlayback() {
        // Store original positions
        originalPlayerPositions = playerChipPositions
        originalOpponentPositions = opponentChipPositions
        originalBallPosition = ballPosition
        
        // Initialize playback positions
        playbackPlayerPositions = playerChipPositions
        playbackOpponentPositions = opponentChipPositions
        playbackBallPosition = ballPosition
        playbackBallCarrier = animationSequence.ballCarrier
        
        // Clear selection
        selectedChipForPath = nil
        showingChipMenu = false
        isSelectingPassTarget = false
        
        // Start playback
        isPlaying = true
        playbackProgress = 0.0
        
        let timing = animationSequence.calculatePlaybackTiming()
        let baseDuration = max(animationSequence.totalDuration, 1.0)
        let totalDuration = baseDuration / animationSpeed  // Apply speed multiplier
        let startTime = Date()
        
        // Create timer for animation
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = elapsed / totalDuration
            
            if progress >= 1.0 {
                // Animation complete
                playbackProgress = 1.0
                updatePlaybackPositions(at: 1.0, timing: timing, totalDuration: baseDuration)
                
                // Auto-stop after a brief pause
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    stopPlayback()
                }
                timer.invalidate()
                playbackTimer = nil
            } else {
                playbackProgress = progress
                updatePlaybackPositions(at: progress, timing: timing, totalDuration: baseDuration)
            }
        }
    }
    
    private func updatePlaybackPositions(at overallProgress: Double, timing: [(step: AnimationStep, startTime: Double, endTime: Double)], totalDuration: Double) {
        let currentTime = overallProgress * totalDuration
        
        // Update each chip based on its paths
        for (step, startTime, endTime) in timing {
            let path = step.path
            
            // Check if this path is currently active
            guard currentTime >= startTime else { continue }
            
            let pathProgress: Double
            if currentTime >= endTime {
                pathProgress = 1.0
            } else {
                pathProgress = (currentTime - startTime) / path.duration
            }
            
            if let position = path.position(at: pathProgress) {
                switch path.chipId {
                case .player(let uuid):
                    playbackPlayerPositions[uuid] = position
                    
                    // Ball follows carrier during dribble
                    if playbackBallCarrier == .player(uuid) && path.pathType == .dribble {
                        playbackBallPosition = CGPoint(x: position.x + 20, y: position.y + 20)
                    }
                    
                case .opponent(let number):
                    playbackOpponentPositions[number] = position
                    
                    if playbackBallCarrier == .opponent(number) && path.pathType == .dribble {
                        playbackBallPosition = CGPoint(x: position.x + 18, y: position.y + 18)
                    }
                    
                case .ball:
                    // Ball movement (pass or shot)
                    playbackBallPosition = position
                    
                    // During pass/shot, ball is not carried
                    if pathProgress > 0 && pathProgress < 1.0 {
                        playbackBallCarrier = nil
                    }
                    
                    // Pass complete - ball carrier transfers to target
                    if path.pathType == .pass && pathProgress >= 1.0, let target = path.passTargetChipId {
                        playbackBallCarrier = target
                    }
                    
                    // Shot complete - ball stays where it ended (no carrier)
                    if path.pathType == .shot && pathProgress >= 1.0 {
                        playbackBallCarrier = nil
                    }
                }
            }
        }
    }
    
    private func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
        playbackProgress = 0.0
        
        // Reset positions to original
        playbackPlayerPositions = originalPlayerPositions
        playbackOpponentPositions = originalOpponentPositions
        playbackBallPosition = originalBallPosition
    }
    
    // MARK: - Video Recording
    private func recordAnimation() {
        guard !animationSequence.steps.isEmpty else { return }
        
        isRecordingVideo = true
        recordingProgress = 0.0
        
        videoRecorder.onProgress = { progress in
            recordingProgress = progress
        }
        
        videoRecorder.onComplete = { url, error in
            isRecordingVideo = false
            
            if let error = error {
                videoErrorMessage = error.localizedDescription
                showingVideoError = true
            } else if let videoURL = url {
                saveVideoToPhotos(url: videoURL)
            }
        }
        
        videoRecorder.renderAnimation(
            team: team,
            drawings: drawings,
            animationSequence: animationSequence,
            initialPlayerPositions: playerChipPositions,
            initialOpponentPositions: opponentChipPositions,
            initialBallPosition: ballPosition,
            opponentColor: opponentColor,
            fieldSize: fieldSize,
            speed: animationSpeed  // ADD THIS
        )
    }

    private func saveVideoToPhotos(url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                    } completionHandler: { success, error in
                        DispatchQueue.main.async {
                            // Clean up temp file
                            try? FileManager.default.removeItem(at: url)
                            
                            if success {
                                showingVideoSaved = true
                            } else {
                                videoErrorMessage = error?.localizedDescription ?? "Failed to save video"
                                showingVideoError = true
                            }
                        }
                    }
                } else {
                    videoErrorMessage = "Please allow photo library access in Settings to save videos."
                    showingVideoError = true
                }
            }
        }
    }
}

// MARK: - Drawing Path Model
struct DrawingPath: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat
    
    init(points: [CGPoint] = [], color: Color = .white, lineWidth: CGFloat = 3.0) {
        self.points = points
        self.color = color
        self.lineWidth = lineWidth
    }
}

// MARK: - Animation Path Models
// MARK: - Animation Path Models

enum PathType: String, CaseIterable {
    case run = "Run"
    case dribble = "Dribble"
    case pass = "Pass"
    case shot = "Shot"
    
    var color: Color {
        switch self {
        case .run: return .yellow
        case .dribble: return .orange
        case .pass: return .cyan
        case .shot: return .red
        }
    }
    
    var lineStyle: StrokeStyle {
        switch self {
        case .run:
            return StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        case .dribble:
            return StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [8, 4])
        case .pass:
            return StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round, dash: [12, 6])
        case .shot:
            return StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        }
    }
    
    var icon: String {
        switch self {
        case .run: return "figure.run"
        case .dribble: return "soccerball"
        case .pass: return "paperplane.fill"
        case .shot: return "target"
        }
    }
}

struct AnimationPath: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var pathType: PathType
    var chipId: ChipIdentifier
    var sequenceOrder: Int
    var duration: Double
    
    // For passes/shots - who kicked the ball
    var sourceChipId: ChipIdentifier? = nil
    // For passes - who receives the ball
    var passTargetChipId: ChipIdentifier? = nil
    
    init(points: [CGPoint] = [], pathType: PathType = .run, chipId: ChipIdentifier, sequenceOrder: Int = 0, duration: Double = 2.0, sourceChipId: ChipIdentifier? = nil) {
        self.points = points
        self.pathType = pathType
        self.chipId = chipId
        self.sequenceOrder = sequenceOrder
        self.duration = duration
        self.sourceChipId = sourceChipId
    }
    
    var startPoint: CGPoint? { points.first }
    var endPoint: CGPoint? { points.last }
    
    func position(at progress: Double) -> CGPoint? {
        guard points.count >= 2 else { return points.first }
        
        let clampedProgress = max(0, min(1, progress))
        let totalSegments = points.count - 1
        let exactSegment = clampedProgress * Double(totalSegments)
        let segmentIndex = min(Int(exactSegment), totalSegments - 1)
        let segmentProgress = exactSegment - Double(segmentIndex)
        
        let start = points[segmentIndex]
        let end = points[segmentIndex + 1]
        
        return CGPoint(
            x: start.x + (end.x - start.x) * segmentProgress,
            y: start.y + (end.y - start.y) * segmentProgress
        )
    }
}

enum ChipIdentifier: Hashable {
    case player(UUID)
    case opponent(Int)
    case ball
    
    var displayName: String {
        switch self {
        case .player: return "Player"
        case .opponent(let num): return "Opponent \(num)"
        case .ball: return "Ball"
        }
    }
}

// MARK: - Animation Sequence (Manages ordered steps)
class AnimationSequence: ObservableObject {
    @Published var steps: [AnimationStep] = []
    @Published var ballCarrier: ChipIdentifier? = nil
    
    var nextSequenceOrder: Int {
        (steps.map { $0.order }.max() ?? -1) + 1
    }
    
    func addStep(_ step: AnimationStep) {
        steps.append(step)
        steps.sort { $0.order < $1.order }
    }
    
    func removeStep(id: UUID) {
        steps.removeAll { $0.id == id }
        reorderSteps()
    }
    
    func removeLastStep() {
        if !steps.isEmpty {
            steps.removeLast()
        }
    }
    
    func clearAll() {
        steps.removeAll()
        ballCarrier = nil
    }
    
    private func reorderSteps() {
        for (index, _) in steps.enumerated() {
            steps[index].order = index
        }
    }
    
    // Get all steps that should be active at a given step index
    func activeSteps(atOrder order: Int) -> [AnimationStep] {
        steps.filter { $0.order <= order }
    }
    
    // Calculate timing for playback
    func calculatePlaybackTiming() -> [(step: AnimationStep, startTime: Double, endTime: Double)] {
        var timing: [(step: AnimationStep, startTime: Double, endTime: Double)] = []
        var currentTime: Double = 0
        
        // Group steps by order (steps with same order play together)
        let grouped = Dictionary(grouping: steps) { $0.order }
        let sortedOrders = grouped.keys.sorted()
        
        for order in sortedOrders {
            guard let stepsAtOrder = grouped[order] else { continue }
            
            let stepStartTime = currentTime
            var maxDuration: Double = 0
            
            for step in stepsAtOrder {
                let stepEndTime = stepStartTime + step.path.duration
                timing.append((step: step, startTime: stepStartTime, endTime: stepEndTime))
                maxDuration = max(maxDuration, step.path.duration)
            }
            
            // Next group starts after the longest path in this group
            currentTime += maxDuration
        }
        
        return timing
    }
    
    var totalDuration: Double {
        let timing = calculatePlaybackTiming()
        return timing.map { $0.endTime }.max() ?? 0
    }
}

struct AnimationStep: Identifiable {
    let id = UUID()
    var path: AnimationPath
    var order: Int // Sequence order - lower numbers play first
    
    // Steps with the same order play simultaneously
    // Steps with sequential orders play one after another
}

// MARK: - Trash Zone View
struct TrashZoneView: View {
    let isActive: Bool
    @Binding var isHovering: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: isHovering ? "trash.fill" : "trash")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(isHovering ? .white : .white.opacity(0.8))
            
            Text("Drop to remove")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isHovering ? .white : .white.opacity(0.8))
        }
        .frame(width: 100, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovering ? Color.red : Color.red.opacity(0.6))
                .shadow(color: isHovering ? Color.red.opacity(0.5) : Color.clear, radius: 8)
        )
        .scaleEffect(isHovering ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .opacity(isActive ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

struct ChipActionMenu: View {
    let chipId: ChipIdentifier
    let position: CGPoint
    let hasBall: Bool
    let hasExistingPaths: Bool
    let onSelectAction: (PathType) -> Void
    let onSetBallCarrier: () -> Void
    let onRemovePaths: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let menuWidth: CGFloat = 160
            let menuHeight: CGFloat = hasBall && chipId != .ball ? 220 : 160
            
            // Calculate safe position
            let safeX = min(max(menuWidth / 2 + 8, position.x), geometry.size.width - menuWidth / 2 - 8)
            let safeY = max(menuHeight / 2 + 8, position.y - 60)
            
            VStack(spacing: 8) {
                // Header
                HStack {
                    Text(chipId.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    if hasBall {
                        Image(systemName: "soccerball")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
                
                // Action buttons - Row 1
                HStack(spacing: 12) {
                    // Run button (always available)
                    ActionMenuButton(
                        icon: "figure.run",
                        label: "Run",
                        color: .yellow
                    ) {
                        onSelectAction(.run)
                    }
                    
                    // Ball carrier / Dribble
                    if case .ball = chipId {
                        // Ball can only pass
                        ActionMenuButton(
                            icon: "paperplane.fill",
                            label: "Pass",
                            color: .cyan
                        ) {
                            onSelectAction(.pass)
                        }
                    } else {
                        if hasBall {
                            ActionMenuButton(
                                icon: "soccerball",
                                label: "Dribble",
                                color: .orange
                            ) {
                                onSelectAction(.dribble)
                            }
                        } else {
                            ActionMenuButton(
                                icon: "soccerball",
                                label: "Has Ball",
                                color: .green,
                                isToggle: true
                            ) {
                                onSetBallCarrier()
                            }
                        }
                    }
                }
                
                // Action buttons - Row 2 (only if has ball)
                if hasBall && chipId != .ball {
                    HStack(spacing: 12) {
                        ActionMenuButton(
                            icon: "arrow.up.right",
                            label: "Pass",
                            color: .white
                        ) {
                            onSelectAction(.pass)
                        }
                        
                        ActionMenuButton(
                            icon: "target",
                            label: "Shot",
                            color: .red
                        ) {
                            onSelectAction(.shot)
                        }
                    }
                }
                
                // Remove paths button (if this chip has paths)
                if hasExistingPaths {
                    Button(action: onRemovePaths) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                            Text("Remove Paths")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.top, 4)
                }
                
                // Cancel button
                Button(action: onDismiss) {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
                .padding(.top, 4)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
            )
            .position(x: safeX, y: safeY)
        }
    }
}

// MARK: - Pass Target Selection Overlay
struct PassTargetSelectionView: View {
    let message: String
    let onCancel: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle")
                        .foregroundColor(.white)
                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.blue)
                )
                
                Spacer()
            }
            .padding(.top, 16)
            
            Spacer()
        }
    }
}

struct ActionMenuButton: View {
    let icon: String
    let label: String
    let color: Color
    var isToggle: Bool = false
    let action: () -> Void
    
    // Computed property to handle white color
    private var displayColor: Color {
        color == .white ? .blue : color
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(displayColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(displayColor)
                }
                
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Sequence Number Badge
struct SequenceNumberBadge: View {
    let number: Int
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 22, height: 22)
            
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Drawing Canvas View
struct DrawingCanvasView: View {
    @Binding var drawings: [DrawingPath]
    @Binding var currentDrawing: DrawingPath?
    let selectedColor: Color
    let selectedLineWidth: CGFloat
    let isDrawingMode: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Transparent hit area
                Color.clear
                    .contentShape(Rectangle())
                
                // Render completed drawings
                ForEach(drawings) { drawing in
                    DrawingPathShape(points: drawing.points)
                        .stroke(drawing.color, style: StrokeStyle(
                            lineWidth: drawing.lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        ))
                }
                
                // Render current drawing
                if let current = currentDrawing {
                    DrawingPathShape(points: current.points)
                        .stroke(current.color, style: StrokeStyle(
                            lineWidth: current.lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        ))
                }
            }
            .gesture(
                isDrawingMode ?
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let point = value.location
                        
                        if currentDrawing == nil {
                            currentDrawing = DrawingPath(
                                points: [point],
                                color: selectedColor,
                                lineWidth: selectedLineWidth
                            )
                        } else {
                            currentDrawing?.points.append(point)
                        }
                    }
                    .onEnded { _ in
                        if let drawing = currentDrawing, drawing.points.count > 1 {
                            drawings.append(drawing)
                        }
                        currentDrawing = nil
                    }
                : nil
            )
        }
    }
}

// MARK: - Drawing Path Shape
struct DrawingPathShape: Shape {
    let points: [CGPoint]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard points.count > 1 else {
            if let point = points.first {
                path.addEllipse(in: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4))
            }
            return path
        }
        
        path.move(to: points[0])
        
        for i in 1..<points.count {
            let mid = CGPoint(
                x: (points[i-1].x + points[i].x) / 2,
                y: (points[i-1].y + points[i].y) / 2
            )
            path.addQuadCurve(to: mid, control: points[i-1])
        }
        
        if let last = points.last {
            path.addLine(to: last)
        }
        
        return path
    }
}

// MARK: - Animation Path Shape with Arrow
struct AnimationPathView: View {
    let path: AnimationPath
    let isActive: Bool
    
    var body: some View {
        ZStack {
            // Path line
            AnimationPathShape(points: path.points)
                .stroke(
                    path.pathType.color,
                    style: path.pathType.lineStyle
                )
                .opacity(isActive ? 1.0 : 0.6)
            
            // Arrow head at end
            if let end = path.endPoint, path.points.count >= 2 {
                let secondLast = path.points[path.points.count - 2]
                ArrowHead(from: secondLast, to: end, color: path.pathType.color)
            }
        }
    }
}

// MARK: - Animation Path Drawing Canvas
struct AnimationPathDrawingCanvas: View {
    @Binding var currentPath: AnimationPath?
    let selectedChip: ChipIdentifier?
    let pathType: PathType
    let startPosition: CGPoint?
    let onPathCompleted: (AnimationPath) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard let chipId = selectedChip else { return }
                            
                            let point = value.location
                            
                            if currentPath == nil {
                                // Start new path from chip's current position or touch point
                                let startPoint = startPosition ?? point
                                currentPath = AnimationPath(
                                    points: [startPoint, point],
                                    pathType: pathType,
                                    chipId: chipId
                                )
                            } else {
                                currentPath?.points.append(point)
                            }
                        }
                        .onEnded { _ in
                            if var path = currentPath, path.points.count > 1 {
                                // Calculate duration based on path length
                                let length = calculatePathLength(path.points)
                                path.duration = max(1.0, min(5.0, length / 100.0)) // 1-5 seconds based on length
                                onPathCompleted(path)
                            }
                            currentPath = nil
                        }
                )
        }
    }
    
    private func calculatePathLength(_ points: [CGPoint]) -> Double {
        var length: Double = 0
        for i in 1..<points.count {
            let dx = points[i].x - points[i-1].x
            let dy = points[i].y - points[i-1].y
            length += sqrt(dx*dx + dy*dy)
        }
        return length
    }
}

struct AnimationPathShape: Shape {
    let points: [CGPoint]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard points.count > 1 else {
            if let point = points.first {
                path.addEllipse(in: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4))
            }
            return path
        }
        
        path.move(to: points[0])
        
        for i in 1..<points.count {
            let mid = CGPoint(
                x: (points[i-1].x + points[i].x) / 2,
                y: (points[i-1].y + points[i].y) / 2
            )
            path.addQuadCurve(to: mid, control: points[i-1])
        }
        
        if let last = points.last {
            path.addLine(to: last)
        }
        
        return path
    }
}

struct ArrowHead: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color
    
    var body: some View {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let arrowLength: CGFloat = 12
        let arrowAngle: CGFloat = .pi / 6
        
        Path { path in
            path.move(to: to)
            path.addLine(to: CGPoint(
                x: to.x - arrowLength * cos(angle - arrowAngle),
                y: to.y - arrowLength * sin(angle - arrowAngle)
            ))
            path.move(to: to)
            path.addLine(to: CGPoint(
                x: to.x - arrowLength * cos(angle + arrowAngle),
                y: to.y - arrowLength * sin(angle + arrowAngle)
            ))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }
}

// MARK: - Whiteboard Field View
struct WhiteboardFieldView: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // Field background
                Rectangle()
                    .fill(Color(red: 0.13, green: 0.55, blue: 0.13))
                
                // Field markings (VERTICAL orientation - goals at top and bottom)
                Canvas { context, size in
                    let lineColor = Color.white.opacity(0.8)
                    let lineWidth: CGFloat = 2.0
                    
                    // Outer boundary
                    let boundary = CGRect(x: 10, y: 10, width: size.width - 20, height: size.height - 20)
                    context.stroke(Path(boundary), with: .color(lineColor), lineWidth: lineWidth)
                    
                    // Center line (horizontal for vertical field)
                    var centerLine = Path()
                    centerLine.move(to: CGPoint(x: 10, y: size.height / 2))
                    centerLine.addLine(to: CGPoint(x: size.width - 10, y: size.height / 2))
                    context.stroke(centerLine, with: .color(lineColor), lineWidth: lineWidth)
                    
                    // Center circle
                    let centerCircleRadius: CGFloat = min(size.width, size.height) * 0.1
                    let centerCircle = Path(ellipseIn: CGRect(
                        x: size.width / 2 - centerCircleRadius,
                        y: size.height / 2 - centerCircleRadius,
                        width: centerCircleRadius * 2,
                        height: centerCircleRadius * 2
                    ))
                    context.stroke(centerCircle, with: .color(lineColor), lineWidth: lineWidth)
                    
                    // Center dot
                    let centerDot = Path(ellipseIn: CGRect(
                        x: size.width / 2 - 4,
                        y: size.height / 2 - 4,
                        width: 8,
                        height: 8
                    ))
                    context.fill(centerDot, with: .color(lineColor))
                    
                    // Top penalty area
                    let penaltyWidth: CGFloat = size.width * 0.44
                    let penaltyHeight: CGFloat = size.height * 0.14
                    let topPenalty = CGRect(
                        x: (size.width - penaltyWidth) / 2,
                        y: 10,
                        width: penaltyWidth,
                        height: penaltyHeight
                    )
                    context.stroke(Path(topPenalty), with: .color(lineColor), lineWidth: lineWidth)
                    
                    // Top goal area
                    let goalWidth: CGFloat = size.width * 0.2
                    let goalHeight: CGFloat = size.height * 0.05
                    let topGoal = CGRect(
                        x: (size.width - goalWidth) / 2,
                        y: 10,
                        width: goalWidth,
                        height: goalHeight
                    )
                    context.stroke(Path(topGoal), with: .color(lineColor), lineWidth: lineWidth)
                    
                    // Top penalty spot
                    let topPenaltySpot = Path(ellipseIn: CGRect(
                        x: size.width / 2 - 3,
                        y: 10 + penaltyHeight * 0.7 - 3,
                        width: 6,
                        height: 6
                    ))
                    context.fill(topPenaltySpot, with: .color(lineColor))
                    
                    // Bottom penalty area
                    let bottomPenalty = CGRect(
                        x: (size.width - penaltyWidth) / 2,
                        y: size.height - 10 - penaltyHeight,
                        width: penaltyWidth,
                        height: penaltyHeight
                    )
                    context.stroke(Path(bottomPenalty), with: .color(lineColor), lineWidth: lineWidth)
                    
                    // Bottom goal area
                    let bottomGoal = CGRect(
                        x: (size.width - goalWidth) / 2,
                        y: size.height - 10 - goalHeight,
                        width: goalWidth,
                        height: goalHeight
                    )
                    context.stroke(Path(bottomGoal), with: .color(lineColor), lineWidth: lineWidth)
                    
                    // Bottom penalty spot
                    let bottomPenaltySpot = Path(ellipseIn: CGRect(
                        x: size.width / 2 - 3,
                        y: size.height - 10 - penaltyHeight * 0.7 - 3,
                        width: 6,
                        height: 6
                    ))
                    context.fill(bottomPenaltySpot, with: .color(lineColor))
                    
                    // Corner arcs
                    let cornerRadius: CGFloat = 12
                    
                    // Top-left corner
                    var topLeftCorner = Path()
                    topLeftCorner.addArc(center: CGPoint(x: 10, y: 10), radius: cornerRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
                    context.stroke(topLeftCorner, with: .color(lineColor), lineWidth: lineWidth)
                    
                    // Top-right corner
                    var topRightCorner = Path()
                    topRightCorner.addArc(center: CGPoint(x: size.width - 10, y: 10), radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
                    context.stroke(topRightCorner, with: .color(lineColor), lineWidth: lineWidth)
                    
                    // Bottom-left corner
                    var bottomLeftCorner = Path()
                    bottomLeftCorner.addArc(center: CGPoint(x: 10, y: size.height - 10), radius: cornerRadius, startAngle: .degrees(270), endAngle: .degrees(360), clockwise: false)
                    context.stroke(bottomLeftCorner, with: .color(lineColor), lineWidth: lineWidth)
                    
                    // Bottom-right corner
                    var bottomRightCorner = Path()
                    bottomRightCorner.addArc(center: CGPoint(x: size.width - 10, y: size.height - 10), radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
                    context.stroke(bottomRightCorner, with: .color(lineColor), lineWidth: lineWidth)
                }
            }
        }
    }
}

// MARK: - Chips Layer View (Interactive)
struct ChipsLayerView: View {
    let team: Team
    @Binding var playerChipPositions: [UUID: CGPoint]
    @Binding var opponentChipPositions: [Int: CGPoint]
    @Binding var ballPosition: CGPoint?
    let opponentColor: Color
    let fieldSize: CGSize
    @Binding var isDraggingChip: Bool
    
    @State private var currentDragChipId: AnyHashable? = nil
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Team player chips
                ForEach(Array(playerChipPositions.keys), id: \.self) { playerId in
                    if let position = playerChipPositions[playerId],
                       let player = team.players.first(where: { $0.id == playerId }) {
                        DraggablePlayerChip(
                            player: player,
                            position: Binding(
                                get: { playerChipPositions[playerId] ?? .zero },
                                set: { playerChipPositions[playerId] = $0 }
                            ),
                            teamColor: team.primaryColor,
                            isDragging: Binding(
                                get: { currentDragChipId as? UUID == playerId },
                                set: { _ in }
                            ),
                            onDragChanged: { location in
                                currentDragChipId = playerId
                                isDraggingChip = true
                            },
                            onDragEnded: { location in
                                // Check if dropped below the field (in toolbar area)
                                if location.y > geometry.size.height - 20 {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    playerChipPositions.removeValue(forKey: playerId)
                                }
                                currentDragChipId = nil
                                isDraggingChip = false
                            }
                        )
                    }
                }
                
                // Opponent chips
                ForEach(Array(opponentChipPositions.keys), id: \.self) { number in
                    if let position = opponentChipPositions[number] {
                        DraggableOpponentChip(
                            number: number,
                            position: Binding(
                                get: { opponentChipPositions[number] ?? .zero },
                                set: { opponentChipPositions[number] = $0 }
                            ),
                            color: opponentColor,
                            isDragging: Binding(
                                get: { currentDragChipId as? Int == number },
                                set: { _ in }
                            ),
                            onDragChanged: { location in
                                currentDragChipId = number
                                isDraggingChip = true
                            },
                            onDragEnded: { location in
                                // Check if dropped below the field (in toolbar area)
                                if location.y > geometry.size.height - 20 {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    opponentChipPositions.removeValue(forKey: number)
                                }
                                currentDragChipId = nil
                                isDraggingChip = false
                            }
                        )
                    }
                }
                
                // Ball
                if ballPosition != nil {
                    DraggableBallChip(
                        position: Binding(
                            get: { ballPosition ?? .zero },
                            set: { ballPosition = $0 }
                        ),
                        isDragging: Binding(
                            get: { currentDragChipId as? String == "ball" },
                            set: { _ in }
                        ),
                        onDragChanged: { location in
                            currentDragChipId = "ball"
                            isDraggingChip = true
                        },
                        onDragEnded: { location in
                            // Check if dropped below the field (in toolbar area)
                            if location.y > geometry.size.height - 20 {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                ballPosition = nil
                            }
                            currentDragChipId = nil
                            isDraggingChip = false
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Static Chips View (Non-interactive, for drawing mode)
struct StaticChipsView: View {
    let team: Team
    let playerChipPositions: [UUID: CGPoint]
    let opponentChipPositions: [Int: CGPoint]
    let ballPosition: CGPoint?
    let opponentColor: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Team player chips (static)
                ForEach(Array(playerChipPositions.keys), id: \.self) { playerId in
                    if let position = playerChipPositions[playerId],
                       let player = team.players.first(where: { $0.id == playerId }) {
                        StaticPlayerChip(player: player, position: position, teamColor: team.primaryColor)
                    }
                }
                
                // Opponent chips (static)
                ForEach(Array(opponentChipPositions.keys), id: \.self) { number in
                    if let position = opponentChipPositions[number] {
                        StaticOpponentChip(number: number, position: position, color: opponentColor)
                    }
                }
                
                // Ball (static)
                if let ballPos = ballPosition {
                    StaticBallChip(position: ballPos)
                }
            }
        }
    }
}

// MARK: - Draggable Player Chip
struct DraggablePlayerChip: View {
    let player: Player
    @Binding var position: CGPoint
    let teamColor: Color
    @Binding var isDragging: Bool
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: (CGPoint) -> Void
    
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(teamColor)
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.3), radius: isDragging ? 8 : 4, x: 0, y: isDragging ? 6 : 2)
                
                Text("\(player.jerseyNumber)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(player.name.components(separatedBy: " ").first ?? "")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.6))
                .cornerRadius(4)
        }
        .scaleEffect(isDragging ? 1.15 : 1.0)
        .position(position)
        .gesture(
            DragGesture()
                .onChanged { value in
                    position = value.location
                    onDragChanged(value.location)
                }
                .onEnded { value in
                    onDragEnded(value.location)
                }
        )
    }
}

// MARK: - Static Player Chip
struct StaticPlayerChip: View {
    let player: Player
    let position: CGPoint
    let teamColor: Color
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(teamColor)
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                
                Text("\(player.jerseyNumber)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(player.name.components(separatedBy: " ").first ?? "")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.6))
                .cornerRadius(4)
        }
        .position(position)
    }
}

// MARK: - Draggable Opponent Chip
struct DraggableOpponentChip: View {
    let number: Int
    @Binding var position: CGPoint
    let color: Color
    @Binding var isDragging: Bool
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: (CGPoint) -> Void
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.9))
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.3), radius: isDragging ? 8 : 4, x: 0, y: isDragging ? 6 : 2)
            
            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                .frame(width: 40, height: 40)
            
            Text("\(number)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
        .scaleEffect(isDragging ? 1.15 : 1.0)
        .position(position)
        .gesture(
            DragGesture()
                .onChanged { value in
                    position = value.location
                    onDragChanged(value.location)
                }
                .onEnded { value in
                    onDragEnded(value.location)
                }
        )
    }
}

// MARK: - Static Opponent Chip
struct StaticOpponentChip: View {
    let number: Int
    let position: CGPoint
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.9))
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            
            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                .frame(width: 40, height: 40)
            
            Text("\(number)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
        .position(position)
    }
}

// MARK: - Draggable Ball Chip
struct DraggableBallChip: View {
    @Binding var position: CGPoint
    @Binding var isDragging: Bool
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: (CGPoint) -> Void
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 28, height: 28)
                .shadow(color: .black.opacity(0.4), radius: isDragging ? 6 : 3, x: 0, y: isDragging ? 4 : 2)
            
            Image(systemName: "soccerball")
                .font(.system(size: 20))
                .foregroundColor(.black)
        }
        .scaleEffect(isDragging ? 1.2 : 1.0)
        .position(position)
        .gesture(
            DragGesture()
                .onChanged { value in
                    position = value.location
                    onDragChanged(value.location)
                }
                .onEnded { value in
                    onDragEnded(value.location)
                }
        )
    }
}

// MARK: - Static Ball Chip
struct StaticBallChip: View {
    let position: CGPoint
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 28, height: 28)
                .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
            
            Image(systemName: "soccerball")
                .font(.system(size: 20))
                .foregroundColor(.black)
        }
        .position(position)
    }
}

// MARK: - Selectable Player Chip (for Animation Mode)
struct SelectablePlayerChip: View {
    let player: Player
    let position: CGPoint
    let teamColor: Color
    let isSelected: Bool
    let hasBall: Bool
    var isPassTarget: Bool = false
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                // Pass target highlight
                if isPassTarget {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 56, height: 56)
                        .opacity(0.8)
                }
                
                // Selection ring
                if isSelected {
                    Circle()
                        .stroke(Color.yellow, lineWidth: 3)
                        .frame(width: 52, height: 52)
                }
                
                Circle()
                    .fill(teamColor)
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                
                Text("\(player.jerseyNumber)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                // Ball indicator
                if hasBall {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Image(systemName: "soccerball")
                                .font(.system(size: 10))
                                .foregroundColor(.black)
                        )
                        .offset(x: 16, y: -16)
                }
            }
            
            Text(player.name.components(separatedBy: " ").first ?? "")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.6))
                .cornerRadius(4)
        }
        .scaleEffect(isPassTarget ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isPassTarget)
        .position(position)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Selectable Opponent Chip (for Animation Mode)
struct SelectableOpponentChip: View {
    let number: Int
    let position: CGPoint
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        ZStack {
            // Selection ring
            if isSelected {
                Circle()
                    .stroke(Color.yellow, lineWidth: 3)
                    .frame(width: 48, height: 48)
            }
            
            Circle()
                .fill(color.opacity(0.9))
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            
            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                .frame(width: 40, height: 40)
            
            Text("\(number)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
        .position(position)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Selectable Ball Chip (for Animation Mode)
struct SelectableBallChip: View {
    let position: CGPoint
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        ZStack {
            // Selection ring
            if isSelected {
                Circle()
                    .stroke(Color.yellow, lineWidth: 3)
                    .frame(width: 36, height: 36)
            }
            
            Circle()
                .fill(Color.white)
                .frame(width: 28, height: 28)
                .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
            
            Image(systemName: "soccerball")
                .font(.system(size: 20))
                .foregroundColor(.black)
        }
        .position(position)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Animation Chips Layer View
struct AnimationChipsLayerView: View {
    let team: Team
    let playerChipPositions: [UUID: CGPoint]
    let opponentChipPositions: [Int: CGPoint]
    let ballPosition: CGPoint?
    let opponentColor: Color
    let selectedChip: ChipIdentifier?
    let ballCarrier: ChipIdentifier?
    let isSelectingPassTarget: Bool
    let onChipTapped: (ChipIdentifier, CGPoint) -> Void
    let onPassTargetSelected: (ChipIdentifier, CGPoint) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Team player chips (selectable)
                ForEach(Array(playerChipPositions.keys), id: \.self) { playerId in
                    if let position = playerChipPositions[playerId],
                       let player = team.players.first(where: { $0.id == playerId }) {
                        SelectablePlayerChip(
                            player: player,
                            position: position,
                            teamColor: team.primaryColor,
                            isSelected: selectedChip == .player(playerId),
                            hasBall: ballCarrier == .player(playerId),
                            isPassTarget: isSelectingPassTarget && selectedChip != .player(playerId),
                            onTap: {
                                if isSelectingPassTarget && selectedChip != .player(playerId) {
                                    onPassTargetSelected(.player(playerId), position)
                                } else {
                                    onChipTapped(.player(playerId), position)
                                }
                            }
                        )
                    }
                }
                
                // Opponent chips (selectable)
                ForEach(Array(opponentChipPositions.keys), id: \.self) { number in
                    if let position = opponentChipPositions[number] {
                        SelectableOpponentChip(
                            number: number,
                            position: position,
                            color: opponentColor,
                            isSelected: selectedChip == .opponent(number),
                            onTap: {
                                if isSelectingPassTarget && selectedChip != .opponent(number) {
                                    onPassTargetSelected(.opponent(number), position)
                                } else {
                                    onChipTapped(.opponent(number), position)
                                }
                            }
                        )
                    }
                }
                
                // Ball (selectable, but only if not attached to a carrier)
                if let ballPos = ballPosition, ballCarrier == nil {
                    SelectableBallChip(
                        position: ballPos,
                        isSelected: selectedChip == .ball,
                        onTap: {
                            onChipTapped(.ball, ballPos)
                        }
                    )
                }
            }
        }
    }
}
// MARK: - Playback Chips Layer View (Animated positions during playback)
struct PlaybackChipsLayerView: View {
    let team: Team
    let playerPositions: [UUID: CGPoint]
    let opponentPositions: [Int: CGPoint]
    let ballPosition: CGPoint?
    let opponentColor: Color
    let ballCarrier: ChipIdentifier?
    
    var body: some View {
        ZStack {
            // Team player chips
            ForEach(Array(playerPositions.keys), id: \.self) { playerId in
                if let position = playerPositions[playerId],
                   let player = team.players.first(where: { $0.id == playerId }) {
                    StaticPlayerChip(
                        player: player,
                        position: position,
                        teamColor: team.primaryColor
                    )
                    
                    // Ball attached to carrier
                    if ballCarrier == .player(playerId) {
                        StaticBallChip(position: CGPoint(x: position.x + 20, y: position.y + 20))
                    }
                }
            }
            
            // Opponent chips
            ForEach(Array(opponentPositions.keys), id: \.self) { number in
                if let position = opponentPositions[number] {
                    StaticOpponentChip(
                        number: number,
                        position: position,
                        color: opponentColor
                    )
                    
                    // Ball attached to carrier
                    if ballCarrier == .opponent(number) {
                        StaticBallChip(position: CGPoint(x: position.x + 18, y: position.y + 18))
                    }
                }
            }
            
            // Free ball (when not carried and not following a pass path)
            if let ballPos = ballPosition, ballCarrier == nil {
                StaticBallChip(position: ballPos)
            }
        }
    }
}

// MARK: - Chip Tray View
struct ChipTrayView: View {
    let team: Team
    @Binding var playerChipPositions: [UUID: CGPoint]
    @Binding var opponentChipPositions: [Int: CGPoint]
    @Binding var ballPosition: CGPoint?
    @Binding var opponentColor: Color
    
    @State private var selectedTray: Int = 0 // 0 = Team, 1 = Opponents, 2 = Ball
    
    let opponentColorOptions: [Color] = [.gray, .red, .blue, .orange, .purple, .black, .yellow]
    
    var availablePlayers: [Player] {
        team.players.filter { !playerChipPositions.keys.contains($0.id) }
            .sorted { $0.jerseyNumber < $1.jerseyNumber }
    }
    
    var availableOpponents: [Int] {
        (1...11).filter { !opponentChipPositions.keys.contains($0) }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Tray selector - Segmented style
            HStack(spacing: 0) {
                TraySegmentButton(title: "My Team", isSelected: selectedTray == 0) {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedTray = 0 }
                }
                TraySegmentButton(title: "Opponents", isSelected: selectedTray == 1) {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedTray = 1 }
                }
                TraySegmentButton(title: "Ball", isSelected: selectedTray == 2) {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedTray = 2 }
                }
            }
            .background(Color(.systemGray5))
            .cornerRadius(8)
            .padding(.horizontal)
            
            // Chip options
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    switch selectedTray {
                    case 0:
                        // Team players
                        if availablePlayers.isEmpty {
                            Text("All players on field")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(availablePlayers) { player in
                                TrayPlayerChip(player: player, teamColor: team.primaryColor) {
                                    playerChipPositions[player.id] = CGPoint(x: 200, y: 300)
                                }
                            }
                        }
                        
                    case 1:
                        // Opponent color picker
                        VStack(spacing: 4) {
                            Text("Color")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                            HStack(spacing: 6) {
                                ForEach(opponentColorOptions, id: \.self) { color in
                                    Circle()
                                        .fill(color)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .stroke(opponentColor == color ? Color.primary : Color.clear, lineWidth: 2)
                                                .padding(-2)
                                        )
                                        .onTapGesture {
                                            opponentColor = color
                                        }
                                }
                            }
                        }
                        .padding(.trailing, 8)
                        
                        Divider()
                            .frame(height: 50)
                        
                        // Opponent numbers
                        if availableOpponents.isEmpty {
                            Text("All opponents on field")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(availableOpponents, id: \.self) { number in
                                TrayOpponentChip(number: number, color: opponentColor) {
                                    opponentChipPositions[number] = CGPoint(x: 200, y: 300)
                                }
                            }
                        }
                        
                    case 2:
                        // Ball
                        if ballPosition == nil {
                            TrayBallChip {
                                ballPosition = CGPoint(x: 200, y: 300)
                            }
                        } else {
                            Text("Ball already on field")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .padding()
                        }
                        
                    default:
                        EmptyView()
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}

// MARK: - Tray Segment Button
struct TraySegmentButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.blue : Color.clear)
                        .padding(2)
                )
        }
    }
}

// MARK: - Tray Tab Button
struct TrayTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.blue : Color.clear)
                )
        }
    }
}

// MARK: - Tray Player Chip
struct TrayPlayerChip: View {
    let player: Player
    let teamColor: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(teamColor)
                        .frame(width: 36, height: 36)
                    
                    Text("\(player.jerseyNumber)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text(player.name.components(separatedBy: " ").first ?? "")
                    .font(.system(size: 8))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Tray Opponent Chip
struct TrayOpponentChip: View {
    let number: Int
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.9))
                    .frame(width: 36, height: 36)
                
                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Tray Ball Chip
struct TrayBallChip: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.2), radius: 2)
                
                Image(systemName: "soccerball")
                    .font(.system(size: 20))
                    .foregroundColor(.black)
            }
        }
    }
}

// MARK: - Trash Drop Zone (in toolbar)
struct TrashDropZone: View {
    @Binding var isHovering: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: isHovering ? "trash.fill" : "trash")
                .font(.system(size: 22))
            Text("Drop here")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.red : Color.red.opacity(0.7))
        )
        .padding(.horizontal, 4)
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }
}

// MARK: - Whiteboard Toolbar
struct WhiteboardToolbar: View {
    @Binding var isDrawingMode: Bool
    @Binding var isAnimationMode: Bool
    @Binding var isPlaying: Bool
    @Binding var selectedColor: Color
    @Binding var selectedLineWidth: CGFloat
    @Binding var showingPlayerTray: Bool
    @Binding var isDraggingChip: Bool
    @Binding var addToCurrentStep: Bool
    @Binding var isRecordingVideo: Bool  // ADD THIS
    @Binding var recordingProgress: Double
    @Binding var animationSpeed: Double  // AD// ADD THIS
    
    let hasAnimationPaths: Bool
    let onUndo: () -> Void
    let onClear: () -> Void
    let onSave: () -> Void
    let onPlay: () -> Void
    let onStop: () -> Void
    let onClearPaths: () -> Void
    let onRecordVideo: () -> Void
    
    @State private var isHoveringTrash: Bool = false
    
    let drawingColors: [Color] = [.red, .blue, .yellow, .white, .black, .orange]
    let lineWidths: [CGFloat] = [2, 4, 6]
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            // Drawing mode options
            if isDrawingMode && !isAnimationMode {
                VStack(spacing: 12) {
                    // Color picker
                    HStack(spacing: 12) {
                        Text("Color")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        ForEach(drawingColors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.blue, lineWidth: selectedColor == color ? 3 : 0)
                                        .padding(-2)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                        
                        Spacer()
                    }
                    
                    // Line width picker
                    HStack(spacing: 12) {
                        Text("Size")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        ForEach(lineWidths, id: \.self) { width in
                            Circle()
                                .fill(Color.primary)
                                .frame(width: width + 8, height: width + 8)
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedLineWidth == width ? Color.blue.opacity(0.2) : Color.clear)
                                )
                                .onTapGesture {
                                    selectedLineWidth = width
                                }
                        }
                        
                        Spacer()
                        
                        // Undo button
                        Button(action: onUndo) {
                            VStack(spacing: 2) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 20))
                                Text("Undo")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 8)
                        
                        // Clear button
                        Button(action: onClear) {
                            VStack(spacing: 2) {
                                Image(systemName: "trash")
                                    .font(.system(size: 20))
                                Text("Clear")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.red)
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            
            // Animation mode hint
            if isAnimationMode && !isPlaying {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Tap a player to draw their path")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        
                        if hasAnimationPaths {
                            Button(action: onClearPaths) {
                                Text("Clear All")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    HStack {
                        // Step mode toggle
                        Text("Add to:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $addToCurrentStep) {
                            Text("New Step").tag(false)
                            Text("Same Step").tag(true)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 160)
                        
                        Spacer()
                        
                        // Speed picker - use icon instead of text to save space
                        Image(systemName: "speedometer")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $animationSpeed) {
                            Text("0.5x").tag(0.5)
                            Text("1x").tag(1.0)
                            Text("1.5x").tag(1.5)
                            Text("2x").tag(2.0)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 140)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
            }
            
            // Playback progress bar
            if isPlaying {
                PlaybackProgressView()
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
            
            // Main toolbar buttons
            HStack(spacing: 0) {
                if isPlaying {
                    // Stop button (full width when playing)
                    Button(action: onStop) {
                        VStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 22))
                            Text("Stop")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                } else {
                    // Move mode button
                    Button(action: {
                        isDrawingMode = false
                        isAnimationMode = false
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "hand.point.up.left.fill")
                                .font(.system(size: 22))
                            Text("Move")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(!isDrawingMode && !isAnimationMode ? .blue : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    // Draw mode button
                    Button(action: {
                        isDrawingMode = true
                        isAnimationMode = false
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "pencil.tip")
                                .font(.system(size: 22))
                            Text("Draw")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(isDrawingMode ? .blue : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    // Animate mode button
                    Button(action: {
                        isDrawingMode = false
                        isAnimationMode = true
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "play.circle")
                                .font(.system(size: 22))
                            Text("Animate")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(isAnimationMode ? .blue : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    // Play button (only in animation mode with paths)
                    if isAnimationMode && hasAnimationPaths {
                        Button(action: onPlay) {
                            VStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 22))
                                Text("Play")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .disabled(isRecordingVideo)
                        
                        Divider()
                            .frame(height: 40)
                        
                        // Save Video button
                        Button(action: onRecordVideo) {
                            VStack(spacing: 4) {
                                if isRecordingVideo {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .frame(width: 22, height: 22)
                                } else {
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 22))
                                }
                                Text(isRecordingVideo ? "\(Int(recordingProgress * 100))%" : "Save")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(isRecordingVideo ? .gray : .purple)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .disabled(isRecordingVideo)
                        
                        Divider()
                            .frame(height: 40)
                    }
                    
                    // Chips toggle (only in Move mode)
                    if !isDrawingMode && !isAnimationMode {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingPlayerTray.toggle()
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: showingPlayerTray ? "tray.fill" : "tray")
                                    .font(.system(size: 22))
                                Text("Chips")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(showingPlayerTray ? .blue : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        
                        Divider()
                            .frame(height: 40)
                    }
                    
                    // Trash Zone (appears when dragging) OR Reset/Save
                    if isDraggingChip {
                        TrashDropZone(isHovering: $isHoveringTrash)
                            .frame(maxWidth: .infinity)
                    } else if !isAnimationMode {
                        // Reset button
                        Button(action: onClear) {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 22))
                                Text("Reset")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        
                        Divider()
                            .frame(height: 40)
                    }
                    
                    // Save button
                    if !isAnimationMode {
                        Button(action: onSave) {
                            VStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 22))
                                Text("Save")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Playback Progress View
struct PlaybackProgressView: View {
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Playing...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
                Spacer()
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray4))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green)
                        .frame(height: 4)
                        .animation(.linear, value: UUID())
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Snapshot View for Saving
struct WhiteboardSnapshotView: View {
    let team: Team
    let drawings: [DrawingPath]
    let playerChipPositions: [UUID: CGPoint]
    let opponentChipPositions: [Int: CGPoint]
    let ballPosition: CGPoint?
    let opponentColor: Color
    
    var body: some View {
        ZStack {
            // Field
            WhiteboardFieldView()
            
            // Drawings
            ForEach(drawings) { drawing in
                DrawingPathShape(points: drawing.points)
                    .stroke(drawing.color, style: StrokeStyle(
                        lineWidth: drawing.lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    ))
            }
            
            // Player chips
            ForEach(Array(playerChipPositions.keys), id: \.self) { playerId in
                if let position = playerChipPositions[playerId],
                   let player = team.players.first(where: { $0.id == playerId }) {
                    StaticPlayerChip(player: player, position: position, teamColor: team.primaryColor)
                }
            }
            
            // Opponent chips
            ForEach(Array(opponentChipPositions.keys), id: \.self) { number in
                if let position = opponentChipPositions[number] {
                    StaticOpponentChip(number: number, position: position, color: opponentColor)
                }
            }
            
            // Ball
            if let ballPos = ballPosition {
                StaticBallChip(position: ballPos)
            }
            
            // Watermark
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("Coach Caddie")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(8)
                }
            }
        }
        .frame(width: 300, height: 400)  // Changed to vertical dimensions
        .background(Color(red: 0.13, green: 0.55, blue: 0.13))
        .cornerRadius(12)
    }
}

// MARK: - Animation Frame View (For Video Rendering)
struct AnimationFrameView: View {
    let team: Team
    let drawings: [DrawingPath]
    let animationPaths: [AnimationPath]
    let playerPositions: [UUID: CGPoint]
    let opponentPositions: [Int: CGPoint]
    let ballPosition: CGPoint?
    let opponentColor: Color
    let ballCarrier: ChipIdentifier?
    let size: CGSize
    
    var body: some View {
        ZStack {
            // Field background
            Rectangle()
                .fill(Color(red: 0.13, green: 0.55, blue: 0.13))
            
            // Field markings
            FieldMarkingsView(size: size)
            
            // Drawings
            ForEach(drawings) { drawing in
                DrawingPathShape(points: drawing.points)
                    .stroke(drawing.color, style: StrokeStyle(
                        lineWidth: drawing.lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    ))
            }
            
            // Animation paths (faded)
            ForEach(animationPaths, id: \.id) { path in
                AnimationPathShape(points: path.points)
                    .stroke(
                        path.pathType.color.opacity(0.3),
                        style: path.pathType.lineStyle
                    )
            }
            
            // Player chips
            ForEach(Array(playerPositions.keys), id: \.self) { playerId in
                if let position = playerPositions[playerId],
                   let player = team.players.first(where: { $0.id == playerId }) {
                    VideoPlayerChip(
                        jerseyNumber: player.jerseyNumber,
                        name: player.name,
                        position: position,
                        color: team.primaryColor,
                        hasBall: ballCarrier == .player(playerId)
                    )
                }
            }
            
            // Opponent chips
            ForEach(Array(opponentPositions.keys), id: \.self) { number in
                if let position = opponentPositions[number] {
                    VideoOpponentChip(
                        number: number,
                        position: position,
                        color: opponentColor
                    )
                }
            }
            
            // Ball (only if not carried)
            if let ballPos = ballPosition, ballCarrier == nil {
                VideoBallChip(position: ballPos)
            }
            
            // Watermark
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("Coach Caddie")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(6)
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Field Markings View (Simplified for video)
struct FieldMarkingsView: View {
    let size: CGSize
    
    var body: some View {
        Canvas { context, canvasSize in
            let lineColor = Color.white.opacity(0.8)
            let lineWidth: CGFloat = 2.0
            
            // Outer boundary
            let boundary = CGRect(x: 10, y: 10, width: canvasSize.width - 20, height: canvasSize.height - 20)
            context.stroke(Path(boundary), with: .color(lineColor), lineWidth: lineWidth)
            
            // Center line
            var centerLine = Path()
            centerLine.move(to: CGPoint(x: 10, y: canvasSize.height / 2))
            centerLine.addLine(to: CGPoint(x: canvasSize.width - 10, y: canvasSize.height / 2))
            context.stroke(centerLine, with: .color(lineColor), lineWidth: lineWidth)
            
            // Center circle
            let centerCircleRadius: CGFloat = min(canvasSize.width, canvasSize.height) * 0.1
            let centerCircle = Path(ellipseIn: CGRect(
                x: canvasSize.width / 2 - centerCircleRadius,
                y: canvasSize.height / 2 - centerCircleRadius,
                width: centerCircleRadius * 2,
                height: centerCircleRadius * 2
            ))
            context.stroke(centerCircle, with: .color(lineColor), lineWidth: lineWidth)
            
            // Center dot
            let centerDot = Path(ellipseIn: CGRect(
                x: canvasSize.width / 2 - 4,
                y: canvasSize.height / 2 - 4,
                width: 8,
                height: 8
            ))
            context.fill(centerDot, with: .color(lineColor))
            
            // Penalty areas
            let penaltyWidth: CGFloat = canvasSize.width * 0.44
            let penaltyHeight: CGFloat = canvasSize.height * 0.14
            
            let topPenalty = CGRect(
                x: (canvasSize.width - penaltyWidth) / 2,
                y: 10,
                width: penaltyWidth,
                height: penaltyHeight
            )
            context.stroke(Path(topPenalty), with: .color(lineColor), lineWidth: lineWidth)
            
            let bottomPenalty = CGRect(
                x: (canvasSize.width - penaltyWidth) / 2,
                y: canvasSize.height - 10 - penaltyHeight,
                width: penaltyWidth,
                height: penaltyHeight
            )
            context.stroke(Path(bottomPenalty), with: .color(lineColor), lineWidth: lineWidth)
            
            // Goal areas
            let goalWidth: CGFloat = canvasSize.width * 0.2
            let goalHeight: CGFloat = canvasSize.height * 0.05
            
            let topGoal = CGRect(
                x: (canvasSize.width - goalWidth) / 2,
                y: 10,
                width: goalWidth,
                height: goalHeight
            )
            context.stroke(Path(topGoal), with: .color(lineColor), lineWidth: lineWidth)
            
            let bottomGoal = CGRect(
                x: (canvasSize.width - goalWidth) / 2,
                y: canvasSize.height - 10 - goalHeight,
                width: goalWidth,
                height: goalHeight
            )
            context.stroke(Path(bottomGoal), with: .color(lineColor), lineWidth: lineWidth)
        }
    }
}

struct VideoPlayerChip: View {
    let jerseyNumber: Int
    let name: String
    let position: CGPoint
    let color: Color
    let hasBall: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 36, height: 36)
                
                Text("\(jerseyNumber)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                if hasBall {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Image(systemName: "soccerball")
                                .font(.system(size: 10))
                                .foregroundColor(.black)
                        )
                        .offset(x: 16, y: 16)
                }
            }
            
            // Player name
            Text(name.components(separatedBy: " ").first ?? "")
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(Color.black.opacity(0.6))
                .cornerRadius(3)
        }
        .position(position)
    }
}

struct VideoOpponentChip: View {
    let number: Int
    let position: CGPoint
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.9))
                .frame(width: 32, height: 32)
            
            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                .frame(width: 32, height: 32)
            
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
        .position(position)
    }
}

struct VideoBallChip: View {
    let position: CGPoint
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            
            Image(systemName: "soccerball")
                .font(.system(size: 14))
                .foregroundColor(.black)
        }
        .position(position)
    }
}
// MARK: - Preview
#Preview {
    NavigationView {
        TacticsWhiteboardView(
            team: .constant(Team(
                id: UUID(),
                name: "Sample FC",
                format: .elevenVEleven,
                defaultFormation: .formation442,
                players: [
                    Player(name: "John Smith", jerseyNumber: 1, positions: ["Goalkeeper"], preferredPosition: "Goalkeeper"),
                    Player(name: "Mike Johnson", jerseyNumber: 4, positions: ["Defender"], preferredPosition: "Defender"),
                    Player(name: "Tom Wilson", jerseyNumber: 7, positions: ["Midfielder"], preferredPosition: "Midfielder"),
                    Player(name: "Chris Brown", jerseyNumber: 9, positions: ["Forward"], preferredPosition: "Forward")
                ],
                games: [],
                practices: [],
                primaryColor: .blue,
                dateCreated: Date()
            )),
            onDismiss: {}
        )
    }
}
