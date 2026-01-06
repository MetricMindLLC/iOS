import SwiftUI
import PhotosUI

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
                    
                    Spacer()
                    
                    Text("Tactics Board")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Invisible placeholder for balance
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
                        
                        // Drawing layer (when in draw mode)
                        if isDrawingMode {
                            DrawingCanvasView(
                                drawings: $drawings,
                                currentDrawing: $currentDrawing,
                                selectedColor: selectedColor,
                                selectedLineWidth: selectedLineWidth,
                                isDrawingMode: isDrawingMode
                            )
                            .padding(8)
                            
                            // Static chips (non-interactive when drawing)
                            StaticChipsView(
                                team: team,
                                playerChipPositions: playerChipPositions,
                                opponentChipPositions: opponentChipPositions,
                                ballPosition: ballPosition,
                                opponentColor: opponentColor
                            )
                            .padding(8)
                        } else {
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
                }
                
                // Bottom Toolbar
                WhiteboardToolbar(
                    isDrawingMode: $isDrawingMode,
                    selectedColor: $selectedColor,
                    selectedLineWidth: $selectedLineWidth,
                    showingPlayerTray: $showingPlayerTray,
                    isDraggingChip: $isDraggingChip,
                    onUndo: undoLastDrawing,
                    onClear: clearAllDrawings,
                    onSave: saveToPhotos
                )
                
                // Chip Tray (only visible when not drawing and tray is shown)
                if !isDrawingMode && showingPlayerTray {
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
    @Binding var selectedColor: Color
    @Binding var selectedLineWidth: CGFloat
    @Binding var showingPlayerTray: Bool
    @Binding var isDraggingChip: Bool
    
    let onUndo: () -> Void
    let onClear: () -> Void
    let onSave: () -> Void
    
    @State private var isHoveringTrash: Bool = false
    
    let drawingColors: [Color] = [.red, .blue, .yellow, .white, .black, .orange]
    let lineWidths: [CGFloat] = [2, 4, 6]
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            if isDrawingMode {
                // Drawing Mode Toolbar
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
            
            // Main toolbar buttons
            HStack(spacing: 0) {
                // Move mode button
                Button(action: {
                    isDrawingMode = false
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "hand.point.up.left.fill")
                            .font(.system(size: 22))
                        Text("Move")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(isDrawingMode ? .secondary : .blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                Divider()
                    .frame(height: 40)
                
                // Draw mode button
                Button(action: {
                    isDrawingMode = true
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
                
                // Chips toggle (only in Move mode)
                if !isDrawingMode {
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
                
                // Trash Zone (appears when dragging) OR Reset button
                if isDraggingChip {
                    TrashDropZone(isHovering: $isHoveringTrash)
                        .frame(maxWidth: .infinity)
                } else {
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
                }
                
                Divider()
                    .frame(height: 40)
                
                // Save button
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
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
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
