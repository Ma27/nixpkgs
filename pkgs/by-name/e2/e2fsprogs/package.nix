{
  lib,
  stdenv,
  buildPackages,
  fetchurl,
  pkg-config,
  libuuid,
  gettext,
  texinfo,
  withFuse ? stdenv.hostPlatform.isLinux,
  fuse3,
  shared ? !stdenv.hostPlatform.isStatic,
  e2fsprogs,
  runCommand,
}:

stdenv.mkDerivation rec {
  pname = "e2fsprogs";
  version = "1.47.2";

  src = fetchurl {
    url = "mirror://kernel/linux/kernel/people/tytso/e2fsprogs/v${version}/e2fsprogs-${version}.tar.xz";
    hash = "sha256-CCQuZMoOgZTZwcqtSXYrGSCaBjGBmbY850rk7y105jw=";
  };

  # fuse2fs adds 14mb of dependencies
  outputs = [
    "bin"
    "dev"
    "out"
    "man"
    "info"
  ] ++ lib.optionals withFuse [ "fuse2fs" ];

  depsBuildBuild = [ buildPackages.stdenv.cc ];
  nativeBuildInputs = [
    pkg-config
    texinfo
  ];
  buildInputs = [
    libuuid
    gettext
  ] ++ lib.optionals withFuse [ fuse3 ];

  configureFlags =
    if stdenv.hostPlatform.isLinux then
      [
        # It seems that the e2fsprogs is one of the few packages that cannot be
        # build with shared and static libs.
        (if shared then "--enable-elf-shlibs" else "--disable-elf-shlibs")
        "--enable-symlink-install"
        "--enable-relative-symlinks"
        "--with-crond-dir=no"
        # fsck, libblkid, libuuid and uuidd are in util-linux-ng (the "libuuid" dependency)
        "--disable-fsck"
        "--disable-libblkid"
        "--disable-libuuid"
        "--disable-uuidd"
      ]
    else
      [
        "--enable-libuuid --disable-e2initrd-helper"
      ];

  nativeCheckInputs = [ buildPackages.perl ];
  doCheck = true;

  postInstall =
    ''
      # avoid cycle between outputs
      if [ -f $out/lib/${pname}/e2scrub_all_cron ]; then
        mv $out/lib/${pname}/e2scrub_all_cron $bin/bin/
      fi
    ''
    + lib.optionalString withFuse ''
      mkdir -p $fuse2fs/bin
      mv $bin/bin/fuse2fs $fuse2fs/bin/fuse2fs
    '';

  enableParallelBuilding = true;

  passthru.tests = {
    simple-filesystem = runCommand "e2fsprogs-create-fs" { } ''
      mkdir -p $out
      truncate -s10M $out/disc
      ${e2fsprogs}/bin/mkfs.ext4 $out/disc | tee $out/success
      ${e2fsprogs}/bin/e2fsck -n $out/disc | tee $out/success
      [ -e $out/success ]
    '';
  };
  meta = {
    homepage = "https://e2fsprogs.sourceforge.net/";
    changelog = "https://e2fsprogs.sourceforge.net/e2fsprogs-release.html#${version}";
    description = "Tools for creating and checking ext2/ext3/ext4 filesystems";
    license = with lib.licenses; [
      gpl2Plus
      lgpl2Plus # lib/ext2fs, lib/e2p
      bsd3 # lib/uuid
      mit # lib/et, lib/ss
    ];
    platforms = lib.platforms.unix;
    maintainers = with lib.maintainers; [ ];
  };
}
