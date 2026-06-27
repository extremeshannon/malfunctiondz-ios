# ASC Suite — Custom Fonts

Download from [Google Fonts](https://fonts.google.com/) and add these files to this folder, then ensure each is included in all ASC app targets:

| File | Family |
|------|--------|
| `BigShouldersDisplay-Black.ttf` | Big Shoulders Display |
| `BigShouldersDisplay-Bold.ttf` | Big Shoulders Display |
| `SairaCondensed-SemiBold.ttf` | Saira Condensed |
| `SairaCondensed-Bold.ttf` | Saira Condensed |
| `SairaCondensed-ExtraBold.ttf` | Saira Condensed |
| `Inter-Regular.ttf` | Inter |
| `Inter-Medium.ttf` | Inter |
| `Inter-SemiBold.ttf` | Inter |

They are registered in `MalfunctionDZ/Info.plist` under **Fonts provided by application**.

Until the files are present, ASC typography falls back to system fonts. Run a debug build and check the console for `ASC font …` diagnostics from `ASCFontDiagnostics`.
