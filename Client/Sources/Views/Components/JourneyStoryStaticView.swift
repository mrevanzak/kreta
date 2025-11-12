import SwiftUI

struct JourneyStoryStaticView: View {
    let backgroundImage: UIImage
    let trainName: String
    let fromName: String?
    let toName: String?
    var isForSharing: Bool = false
    
    // Scale factor based on mode
    private var scaleFactor: CGFloat {
        isForSharing ? 4.0 : 1.0
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // full-screen background image
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                // gradient overlay for readability
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.45)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 0) {
                    // Top section with train name
                    Text(trainName)
                        .font(.system(size: 34 * scaleFactor, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, 44 * scaleFactor)
                        .padding(.horizontal, 20 * scaleFactor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    
                    Spacer()

                    // Bottom section with journey info
                    VStack(spacing: 12 * scaleFactor) {
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                                Text("FROM")
                                    .font(.system(size: 12 * scaleFactor))
                                    .foregroundStyle(.white.opacity(0.8))
                                Text(fromName ?? "Start")
                                    .font(.system(size: 22 * scaleFactor, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "arrow.right")
                                .font(.system(size: 22 * scaleFactor, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16 * scaleFactor)

                            VStack(alignment: .trailing, spacing: 6 * scaleFactor) {
                                Text("TO")
                                    .font(.system(size: 12 * scaleFactor))
                                    .foregroundStyle(.white.opacity(0.8))
                                Text(toName ?? "Destination")
                                    .font(.system(size: 22 * scaleFactor, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.horizontal, 28 * scaleFactor)
                        
                        Text("Shared from Kreta App")
                            .font(.system(size: 12 * scaleFactor))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.bottom, 44 * scaleFactor)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .frame(width: 270 * scaleFactor, height: 480 * scaleFactor)
        .cornerRadius(20 * scaleFactor)
        .compositingGroup()
    }
}
