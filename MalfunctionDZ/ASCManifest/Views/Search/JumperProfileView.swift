import SwiftUI

struct JumperProfileView: View {
    let person: SearchPerson

    var body: some View {
        AccountDetailView(target: person.accountTarget)
    }
}
