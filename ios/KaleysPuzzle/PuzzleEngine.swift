import Foundation

/// Pure game logic — no UI, no side effects.
/// Direct port of puzzle-engine.js / PuzzleEngine.kt.
enum PuzzleEngine {

    static let snapDistance: CGFloat = 35
    static let imageW: Int = 800
    static let imageH: Int = 600

    struct Grid {
        let cols: Int
        let rows: Int
    }

    struct Edges {
        /// h[r][c] = edge between row r and row r+1 at column c
        let h: [[Int]]
        /// v[r][c] = edge between col c and col c+1 at row r
        let v: [[Int]]
    }

    class Piece: Identifiable {
        let id: Int
        let col: Int
        let row: Int
        var x: CGFloat
        var y: CGFloat
        let correctX: CGFloat
        let correctY: CGFloat
        var placed: Bool = false
        var groupId: Int

        init(id: Int, col: Int, row: Int, x: CGFloat, y: CGFloat,
             correctX: CGFloat, correctY: CGFloat, groupId: Int) {
            self.id = id
            self.col = col
            self.row = row
            self.x = x
            self.y = y
            self.correctX = correctX
            self.correctY = correctY
            self.groupId = groupId
        }
    }

    class Group {
        let id: Int
        var pieces: [Piece]
        var placed: Bool = false

        init(id: Int, pieces: [Piece]) {
            self.id = id
            self.pieces = pieces
        }
    }

    class GameState {
        var pieces: [Piece]
        var piecesById: [Int: Piece]
        var groups: [Group]

        init(pieces: [Piece], piecesById: [Int: Piece], groups: [Group]) {
            self.pieces = pieces
            self.piecesById = piecesById
            self.groups = groups
        }
    }

    struct SnapResult {
        let snapped: Bool
        let placedCount: Int
    }

    // MARK: - Grid Computation

    /// Find cols × rows grid that best matches the image aspect ratio
    /// while producing exactly `count` cells.
    static func computeGrid(count: Int, imageW: Int = PuzzleEngine.imageW, imageH: Int = PuzzleEngine.imageH) -> Grid {
        let aspect = CGFloat(imageW) / CGFloat(imageH)
        var bestCols = 1
        var bestRows = count
        var bestDiff = CGFloat.greatestFiniteMagnitude

        for c in 1...count {
            let r = Int(ceil(Double(count) / Double(c)))
            guard c * r == count else { continue }
            let gridAspect = CGFloat(c) / CGFloat(r)
            let diff = abs(gridAspect - aspect)
            if diff < bestDiff {
                bestDiff = diff
                bestCols = c
                bestRows = r
            }
        }
        return Grid(cols: bestCols, rows: bestRows)
    }

    // MARK: - Coordinate Transforms

    static func screenToWorld(sx: CGFloat, sy: CGFloat,
                              cameraX: CGFloat, cameraY: CGFloat, cameraZoom: CGFloat,
                              canvasW: CGFloat, canvasH: CGFloat) -> CGPoint {
        let wx = (sx - canvasW / 2) / cameraZoom + cameraX
        let wy = (sy - canvasH / 2) / cameraZoom + cameraY
        return CGPoint(x: wx, y: wy)
    }

    // MARK: - Edge Generation

    static func generateEdges(rows: Int, cols: Int) -> Edges {
        var h: [[Int]] = []
        for _ in 0..<(rows - 1) {
            h.append((0..<cols).map { _ in Bool.random() ? 1 : -1 })
        }
        var v: [[Int]] = []
        for _ in 0..<rows {
            v.append((0..<(cols - 1)).map { _ in Bool.random() ? 1 : -1 })
        }
        return Edges(h: h, v: v)
    }

    // MARK: - Neighbors

    static func getNeighbors(piece: Piece, cols: Int, rows: Int, piecesById: [Int: Piece]) -> [Piece] {
        var result: [Piece] = []
        let col = piece.col
        let row = piece.row
        func pieceId(r: Int, c: Int) -> Int { r * cols + c }

        if col > 0, let p = piecesById[pieceId(r: row, c: col - 1)] { result.append(p) }
        if col < cols - 1, let p = piecesById[pieceId(r: row, c: col + 1)] { result.append(p) }
        if row > 0, let p = piecesById[pieceId(r: row - 1, c: col)] { result.append(p) }
        if row < rows - 1, let p = piecesById[pieceId(r: row + 1, c: col)] { result.append(p) }
        return result
    }

    // MARK: - Game State Creation

    static func createGameState(cols: Int, rows: Int,
                                pieceW: CGFloat, pieceH: CGFloat,
                                puzzleX: CGFloat, puzzleY: CGFloat) -> GameState {
        var pieces: [Piece] = []
        var piecesById: [Int: Piece] = [:]
        var groups: [Group] = []

        for r in 0..<rows {
            for c in 0..<cols {
                let id = r * cols + c
                let correctX = puzzleX + CGFloat(c) * pieceW
                let correctY = puzzleY + CGFloat(r) * pieceH
                let piece = Piece(id: id, col: c, row: r,
                                  x: correctX, y: correctY,
                                  correctX: correctX, correctY: correctY,
                                  groupId: id)
                pieces.append(piece)
                piecesById[id] = piece
                groups.append(Group(id: id, pieces: [piece]))
            }
        }
        return GameState(pieces: pieces, piecesById: piecesById, groups: groups)
    }

    // MARK: - Snap Logic

    @discardableResult
    static func trySnap(movedGroup: Group, cols: Int, rows: Int,
                        pieceW: CGFloat, pieceH: CGFloat,
                        piecesById: [Int: Piece],
                        groups: inout [Group],
                        snapDistance: CGFloat = PuzzleEngine.snapDistance) -> SnapResult {
        for piece in movedGroup.pieces {
            // Check snap to correct position
            let dx = piece.x - piece.correctX
            let dy = piece.y - piece.correctY
            if abs(dx) < snapDistance && abs(dy) < snapDistance {
                var newlyPlaced = 0
                for gp in movedGroup.pieces {
                    gp.x = gp.correctX
                    gp.y = gp.correctY
                    if !gp.placed {
                        gp.placed = true
                        newlyPlaced += 1
                    }
                }
                movedGroup.placed = true
                return SnapResult(snapped: true, placedCount: newlyPlaced)
            }

            // Check snap to neighbor in different group
            let neighbors = getNeighbors(piece: piece, cols: cols, rows: rows, piecesById: piecesById)
            for neighbor in neighbors {
                if neighbor.groupId == piece.groupId { continue }
                let expectedDx = CGFloat(piece.col - neighbor.col) * pieceW
                let expectedDy = CGFloat(piece.row - neighbor.row) * pieceH
                let actualDx = piece.x - neighbor.x
                let actualDy = piece.y - neighbor.y
                if abs(actualDx - expectedDx) < snapDistance &&
                   abs(actualDy - expectedDy) < snapDistance {
                    let snapOffsetX = (neighbor.x + expectedDx) - piece.x
                    let snapOffsetY = (neighbor.y + expectedDy) - piece.y
                    for gp in movedGroup.pieces {
                        gp.x += snapOffsetX
                        gp.y += snapOffsetY
                    }
                    guard let neighborGroup = groups.first(where: { $0.id == neighbor.groupId }) else { continue }
                    let mergeCount = mergeGroups(groupA: movedGroup, groupB: neighborGroup,
                                                cols: cols, rows: rows,
                                                pieceW: pieceW, pieceH: pieceH,
                                                piecesById: piecesById, groups: &groups,
                                                snapDistance: snapDistance)
                    return SnapResult(snapped: true, placedCount: mergeCount)
                }
            }
        }
        return SnapResult(snapped: false, placedCount: 0)
    }

    // MARK: - Group Merging

    @discardableResult
    static func mergeGroups(groupA: Group, groupB: Group,
                            cols: Int, rows: Int,
                            pieceW: CGFloat, pieceH: CGFloat,
                            piecesById: [Int: Piece],
                            groups: inout [Group],
                            snapDistance: CGFloat = PuzzleEngine.snapDistance) -> Int {
        var placedCount = 0
        let newId = groupA.id
        for p in groupB.pieces {
            p.groupId = newId
            groupA.pieces.append(p)
        }
        if groupB.placed || groupA.placed {
            for p in groupA.pieces {
                p.x = p.correctX
                p.y = p.correctY
                if !p.placed {
                    p.placed = true
                    placedCount += 1
                }
            }
            groupA.placed = true
        }
        groups.removeAll { $0.id == groupB.id }

        // Chain reaction
        let chainResult = trySnap(movedGroup: groupA, cols: cols, rows: rows,
                                  pieceW: pieceW, pieceH: pieceH,
                                  piecesById: piecesById, groups: &groups,
                                  snapDistance: snapDistance)
        placedCount += chainResult.placedCount
        return placedCount
    }
}
