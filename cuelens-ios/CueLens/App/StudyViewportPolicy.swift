import CoreGraphics

enum StudyViewportPolicy {
    static let minimumWidth: CGFloat = 375
    static let minimumHeight: CGFloat = 667

    static func allowsProductiveStudy(in size: CGSize) -> Bool {
        size.width >= minimumWidth
            && size.height >= minimumHeight
            && size.height >= size.width
    }
}
