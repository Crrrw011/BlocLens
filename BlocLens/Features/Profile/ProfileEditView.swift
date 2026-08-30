import SwiftUI

struct ProfileEditView: View {
    @ObservedObject var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var showsError = false

    @State private var height: Double?
    @State private var armSpan: Double?
    @State private var hasHeight: Bool
    @State private var hasArmSpan: Bool
    @State private var gradeSystem: GradeSystem?
    @State private var vGrade: VGrade?
    @State private var ydsGrade: YDSGrade?

    init(session: AppSession) {
        self.session = session
        let profile = session.authenticationState.profile
        _height = State(initialValue: profile?.heightCentimetres)
        _armSpan = State(initialValue: profile?.armSpanCentimetres)
        _hasHeight = State(initialValue: profile?.heightCentimetres != nil)
        _hasArmSpan = State(initialValue: profile?.armSpanCentimetres != nil)
        _gradeSystem = State(initialValue: profile?.gradeSystem ?? .vScale)
        _vGrade = State(initialValue: profile?.regularGrade)
        _ydsGrade = State(initialValue: profile?.ydsGrade)
    }

    private var isGradeSet: Bool {
        guard let gradeSystem else { return false }
        switch gradeSystem {
        case .vScale: return vGrade != nil
        case .yds: return ydsGrade != nil
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(L10n.ProfileEdit.subtitle)
                        .font(DesignTypography.body)
                        .foregroundStyle(DesignColour.secondaryText)
                }
                .listRowBackground(Color.clear)

                Section {
                    measurementToggle(
                        title: L10n.ProfileEdit.height,
                        icon: "ruler",
                        isOn: $hasHeight,
                        pickerValue: $height
                    )
                    measurementToggle(
                        title: L10n.ProfileEdit.armSpan,
                        icon: "arrow.left.and.right",
                        isOn: $hasArmSpan,
                        pickerValue: $armSpan
                    )
                } header: {
                    labeledHeader(L10n.ProfileEdit.measurements, icon: "figure.stand")
                }

                Section {
                    Picker(L10n.ProfileEdit.gradeSystem, selection: $gradeSystem) {
                        Text(L10n.ProfileEdit.vScale).tag(GradeSystem?.some(.vScale))
                        Text(L10n.ProfileEdit.yds).tag(GradeSystem?.some(.yds))
                    }
                    .pickerStyle(.segmented)

                    if gradeSystem == .vScale {
                        wheelPicker(selection: $vGrade)
                    } else if gradeSystem == .yds {
                        wheelPicker(selection: $ydsGrade)
                    }

                    Button {
                        withAnimation {
                            gradeSystem = nil
                            vGrade = nil
                            ydsGrade = nil
                        }
                    } label: {
                        Label(L10n.ProfileEdit.notSureYet, systemImage: "questionmark.circle")
                            .font(DesignTypography.supporting)
                            .foregroundStyle(DesignColour.secondaryText)
                    }
                    .buttonStyle(.plain)
                } header: {
                    labeledHeader(L10n.ProfileEdit.regularGrade, icon: "gauge.with.needle")
                } footer: {
                    Text(L10n.ProfileEdit.gradeHint)
                        .font(DesignTypography.caption)
                }

                if showsError {
                    Section {
                        Label(L10n.ProfileEdit.saveFailed, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(DesignColour.error)
                    }
                }
            }
            .navigationTitle(L10n.ProfileEdit.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(L10n.Common.save)
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func labeledHeader(_ title: LocalizedStringResource, icon: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: icon)
        }
    }

    @ViewBuilder
    private func measurementToggle(
        title: LocalizedStringResource,
        icon: String,
        isOn: Binding<Bool>,
        pickerValue: Binding<Double?>
    ) -> some View {
        Toggle(isOn: isOn) {
            Label {
                Text(title).font(DesignTypography.body)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(BlocColor.opticBlue)
            }
        }
        if isOn.wrappedValue {
            wheelPicker(value: pickerValue)
        }
    }

    private func wheelPicker(selection: Binding<VGrade?>) -> some View {
        Picker(L10n.ProfileEdit.vScale, selection: selection) {
            ForEach(VGrade.allCases.filter { $0 != .unknown }, id: \.self) { value in
                Text(value.displayName).tag(VGrade?.some(value))
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 120)
    }

    private func wheelPicker(selection: Binding<YDSGrade?>) -> some View {
        Picker(L10n.ProfileEdit.yds, selection: selection) {
            ForEach(YDSGrade.allCases, id: \.self) { value in
                Text(value.displayName).tag(YDSGrade?.some(value))
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 120)
    }

    private func wheelPicker(value: Binding<Double?>) -> some View {
        Picker(L10n.ProfileEdit.height, selection: value) {
            ForEach(Array(stride(from: 100.0, through: 250.0, by: 1.0)), id: \.self) { cm in
                Text("\(Int(cm)) \(L10n.ProfileEdit.cm)").tag(Double?.some(cm))
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 120)
    }

    private func save() async {
        isSaving = true
        showsError = false
        defer { isSaving = false }
        let useGrade = gradeSystem != nil && isGradeSet
        let details = ProfileDetailsUpdate(
            heightCentimetres: hasHeight ? height : nil,
            armSpanCentimetres: hasArmSpan ? armSpan : nil,
            regularGrade: useGrade && gradeSystem == .vScale ? vGrade : nil,
            gradeSystem: useGrade ? gradeSystem : nil,
            ydsGrade: useGrade && gradeSystem == .yds ? ydsGrade : nil
        )
        await session.updateProfileDetails(details)
        if case .error = session.authenticationState {
            showsError = true
        } else {
            dismiss()
        }
    }
}
