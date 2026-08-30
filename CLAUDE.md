# app-genailabs — agent notes

## Never commit an `objectVersion` downgrade in the iOS project

`ios/Runner.xcodeproj/project.pbxproj` must keep **`objectVersion = 60`**
(Xcode 15 format). The project uses Flutter's Swift Package Manager mode —
the pbxproj contains an `XCLocalSwiftPackageReference` to
`FlutterGeneratedPluginSwiftPackage`, an Xcode-15-only feature. Upstream set
60 deliberately (commit `d4b7d85`).

Some local tooling built on the Ruby `Xcodeproj` gem (fastlane, icon/asset
utilities) silently rewrites it to `54`, producing an inconsistent project
file and merge conflicts with upstream.

If `git status` shows `project.pbxproj` modified and the diff is only
`objectVersion = 60` → `54`:

```bash
git checkout -- ios/Runner.xcodeproj/project.pbxproj
```

If the diff mixes this with real changes, restore the `objectVersion = 60`
line before committing. Never commit the downgrade.
