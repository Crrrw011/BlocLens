import SwiftUI
import WebKit

/// Moonlitt video-first: video is the interface, minimal floating glass controls.
/// Flighty metadata: author · domain · helpful separated by typography, not cards.
struct BetaVideoCard: View {
    let link: BetaLink
    let isHelpful: Bool
    let openOriginal: () -> Void
    let markHelpful: () -> Void
    let reportIssue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            videoContainer
            flightyMetadata
            actionRow
        }
        .padding(DesignSpacing.small)
        .background(DesignColour.surfacePrimary, in: RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous).stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Video first — 16:9 fills interface, glass floats above

    private var videoContainer: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if link.embedSupport == .supported {
                    BetaVideoPlayerView(url: link.sourceURL)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipped()
                } else {
                    unsupportedPlaceholder
                }
            }
            // Legibility gradient — Moonlitt depth
            LinearGradient(colors: [.clear, Color.black.opacity(0.42)], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
            // Minimal floating glass controls
            floatingGlassBar
                .padding(DesignSpacing.small)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.card, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: DesignRadius.card, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 0.5) }
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }

    private var unsupportedPlaceholder: some View {
        ZStack {
            DesignColour.surfaceElevated
            VStack(spacing: DesignSpacing.small) {
                Image(systemName: platformIcon(link.platform))
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(DesignColour.textSecondary)
                Text(link.sourceURL.host ?? String(localized: L10n.betaPlatform(link.platform)))
                    .font(BlocTypography.metadata)
                    .foregroundStyle(DesignColour.textSecondary)
                    .lineLimit(1)
                Button(action: openOriginal) {
                    Label(L10n.Beta.openOriginalPost, systemImage: "arrow.up.forward.app")
                        .font(BlocTypography.status)
                }
                .buttonStyle(CompactActionButtonStyle())
            }
            .padding(DesignSpacing.medium)
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .accessibilityLabel(Text(verbatim: link.sourceURL.host ?? String(localized: L10n.betaPlatform(link.platform))))
    }

    private var floatingGlassBar: some View {
        HStack(spacing: DesignSpacing.small) {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay { Capsule().fill(Color.black.opacity(0.16)) }
                .overlay {
                    if #available(iOS 26.0, *) {
                        Capsule().fill(.ultraThinMaterial)
                            .glassEffect(.regular.tint(BlocColor.opticBlueTint).interactive(false), in: Capsule())
                    }
                }
                .overlay {
                    Label(domainShort, systemImage: platformIcon(link.platform))
                        .font(BlocTypography.status)
                        .foregroundStyle(.white)
                        .padding(.horizontal, BlocSpacing.compact)
                        .frame(minHeight: 28)
                }
                .frame(height: 28)
                .fixedSize(horizontal: true, vertical: false)
                .overlay { Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5) }
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)

            if link.tags.contains(.fullSolution) {
                Text(verbatim: "FULL")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.06)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 22)
                    .background(BlocColor.opticBlue, in: Capsule())
                    .overlay { Capsule().stroke(Color.white.opacity(0.20), lineWidth: 0.5) }
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
            }
            Spacer(minLength: 0)
            // Glass open control only when embed supported — minimal, not intrusive
            if link.embedSupport == .supported {
                Button(action: openOriginal) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay { Circle().stroke(Color.white.opacity(0.20), lineWidth: 0.5) }
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                }
                .accessibilityLabel(L10n.Beta.openOriginalPost)
            }
        }
    }

    // MARK: - Flighty clarity metadata — typography before containers

    private var flightyMetadata: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.xSmall) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSpacing.xSmall) {
                Text(verbatim: link.originalAuthor)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignColour.textPrimary)
                    .lineLimit(1)
                Text(verbatim: "·")
                    .font(BlocTypography.caption)
                    .foregroundStyle(DesignColour.textTertiary)
                Text(verbatim: domainShort)
                    .font(BlocTypography.metadata)
                    .foregroundStyle(DesignColour.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: DesignSpacing.small)
                Label {
                    Text(verbatim: "\(link.helpfulCount + (isHelpful ? 1 : 0))")
                        .font(BlocTypography.status)
                    + Text(L10n.Beta.helpfulSuffix)
                        .font(BlocTypography.caption)
                } icon: {
                    Image(systemName: isHelpful ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(isHelpful ? BlocColor.opticBlue : DesignColour.textSecondary)
                .lineLimit(1)
            }
            // Tags — Flighty density, uppercase 10pt
            if !link.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(link.tags, id: \.self) { tag in
                            Text(L10n.betaTag(tag))
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.04)
                                .textCase(.uppercase)
                                .foregroundStyle(tag == .fullSolution ? BlocColor.opticBlue : DesignColour.textSecondary)
                                .padding(.horizontal, 8)
                                .frame(minHeight: 22)
                                .background(DesignColour.surfaceElevated, in: Capsule())
                                .overlay { Capsule().stroke(DesignColour.separator.opacity(0.5), lineWidth: 0.5) }
                        }
                    }
                }
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: DesignSpacing.small) {
            Button(action: markHelpful) {
                Label(L10n.Beta.helpful, systemImage: isHelpful ? "hand.thumbsup.fill" : "hand.thumbsup")
            }
            .buttonStyle(CompactActionButtonStyle())
            .disabled(isHelpful)
            .accessibilityIdentifier("beta-helpful-\(link.id.rawValue)")

            Button(L10n.Beta.reportIssue, action: reportIssue)
                .buttonStyle(QuietButtonStyle())
                .accessibilityIdentifier("beta-report-\(link.id.rawValue)")

            Spacer(minLength: 0)
            if link.embedSupport == .sourcePlatformOnly {
                Button(action: openOriginal) {
                    Label(L10n.Beta.openOriginalPost, systemImage: "arrow.up.forward")
                        .font(BlocTypography.status)
                }
                .buttonStyle(CompactActionButtonStyle())
            }
        }
    }

    private var domainShort: String {
        link.sourceURL.host ?? String(localized: L10n.betaPlatform(link.platform))
    }

    private func platformIcon(_ platform: BetaPlatform) -> String {
        switch platform {
        case .youtube: "play.rectangle.fill"
        case .instagram: "camera.fill"
        case .tiktok: "music.note"
        case .vimeo: "video.fill"
        case .other: "link"
        }
    }
}
