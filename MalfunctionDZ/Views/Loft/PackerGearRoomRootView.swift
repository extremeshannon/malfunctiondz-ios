// ASC Packers — Gear Room (DZ rigs) and 25 Jump Check roots.
import SwiftUI

struct PackerGearRoomRootView: View {
  @Environment(\.mdzColors) private var colors
  @Environment(\.mdzColorScheme) private var mdzColorScheme

  var body: some View {
    DzRigsView()
      .navigationTitle("Gear Room")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
      .toolbarBackground(colors.navyMid, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
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
