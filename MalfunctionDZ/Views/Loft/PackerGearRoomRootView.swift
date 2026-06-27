// ASC Packers — Gear Room (DZ rigs) and 25 Jump Check roots.
import SwiftUI
import MalfunctionDZCore

struct PackerGearRoomRootView: View {
  @Environment(\.mdzColorScheme) private var mdzColorScheme

  var body: some View {
    PackerGearRoomBrowseView()
      .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
  }
}

struct PackerJumpCheckRootView: View {
  @StateObject private var vm = DzRigsViewModel()
  @Environment(\.mdzColors) private var colors
  @Environment(\.mdzColorScheme) private var mdzColorScheme

  var body: some View {
    JumpCheckView(vm: vm)
      .navigationTitle("25 Jump Check")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
      .toolbarBackground(colors.navyMid, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
  }
}
