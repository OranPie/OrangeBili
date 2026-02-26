import SwiftUI

struct SkeletonVideoRow: View {
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.shimmerBase)
                .aspectRatio(16 / 9, contentMode: .fit)
                #if os(tvOS)
                .frame(width: 240)
                #else
                .frame(width: 96)
                #endif
                .shimmer()

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.shimmerBase)
                    .frame(height: 10)
                    .shimmer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.shimmerBase)
                    .frame(width: 80, height: 8)
                    .shimmer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.shimmerBase)
                    .frame(width: 60, height: 8)
                    .shimmer()
            }
        }
    }
}

struct SkeletonVideoList: View {
    var count: Int = 5

    var body: some View {
        ForEach(0..<count, id: \.self) { _ in
            SkeletonVideoRow()
                .listRowInsets(UIStyle.listRowInsets)
        }
    }
}

struct SkeletonDetailView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.shimmerBase)
                .aspectRatio(16 / 9, contentMode: .fit)
                #if os(tvOS)
                .frame(height: 360)
                #else
                .frame(height: 120)
                #endif
                .shimmer()

            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.shimmerBase)
                .frame(height: 12)
                .shimmer()

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(Theme.shimmerBase)
                        .frame(width: 56, height: 20)
                        .shimmer()
                }
            }

            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Theme.shimmerBase)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .shimmer()
                }
            }
        }
    }
}

struct SkeletonCommentRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Theme.shimmerBase)
                .frame(width: 28, height: 28)
                .shimmer()

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.shimmerBase)
                    .frame(width: 80, height: 9)
                    .shimmer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.shimmerBase)
                    .frame(height: 9)
                    .shimmer()
            }
        }
        .padding(.vertical, 2)
    }
}

struct SkeletonUploaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.shimmerBase)
                    .frame(width: 40, height: 40)
                    .shimmer()
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.shimmerBase)
                        .frame(width: 100, height: 10)
                        .shimmer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.shimmerBase)
                        .frame(width: 140, height: 8)
                        .shimmer()
                }
            }
            SkeletonVideoList(count: 3)
        }
    }
}
