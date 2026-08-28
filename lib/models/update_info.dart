/// A newer release found by [UpdateRepository.checkForUpdate]: the target
/// version, its release notes, and the direct download URL for its APK
/// asset.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.releaseNotes,
    required this.apkUrl,
  });

  final String version;
  final String releaseNotes;
  final String apkUrl;

  @override
  bool operator ==(Object other) =>
      other is UpdateInfo &&
      other.version == version &&
      other.releaseNotes == releaseNotes &&
      other.apkUrl == apkUrl;

  @override
  int get hashCode => Object.hash(version, releaseNotes, apkUrl);
}
