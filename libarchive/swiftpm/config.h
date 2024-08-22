/* Created from the CMakeLists.txt and config.h.in assuming clang and SwiftPM environment. */
#ifdef __clang__

#define __LIBARCHIVE_CONFIG_H_INCLUDED 1

/* Clang has all of these types. */
#define HAVE_INT16_T
#define HAVE_INT32_T
#define HAVE_INT64_T
#define HAVE_INTMAX_T

#define HAVE_UINT8_T
#define HAVE_UINT16_T
#define HAVE_UINT32_T
#define HAVE_UINT64_T
#define HAVE_UINTMAX_T

/* The sizes of various standard integer types. */
#define SIZEOF_SHORT sizeof(short)
#define SIZEOF_INT sizeof(int)
#define SIZEOF_LONG sizeof(long)
#define SIZEOF_LONG_LONG sizeof(long long)
#define SIZEOF_UNSIGNED_SHORT sizeof(unsigned short)
#define SIZEOF_UNSIGNED sizeof(unsigned)
#define SIZEOF_UNSIGNED_LONG sizeof(unsigned long)
#define SIZEOF_UNSIGNED_LONG_LONG sizeof(unsigned long long)

/* Define ZLIB_WINAPI if zlib was built on Visual Studio. */
/* #undef ZLIB_WINAPI */

/* Darwin ACL support */
/* #undef ARCHIVE_ACL_DARWIN */

/* FreeBSD ACL support */
/* #undef ARCHIVE_ACL_FREEBSD */

/* FreeBSD NFSv4 ACL support */
/* #undef ARCHIVE_ACL_FREEBSD_NFS4 */

/* Linux POSIX.1e ACL support via libacl */
/* #undef ARCHIVE_ACL_LIBACL */

/* Linux NFSv4 ACL support via librichacl */
/* #undef ARCHIVE_ACL_LIBRICHACL */

/* Solaris ACL support */
/* #undef ARCHIVE_ACL_SUNOS */

/* Solaris NFSv4 ACL support */
/* #undef ARCHIVE_ACL_SUNOS_NFS4 */

/* MD5 via ARCHIVE_CRYPTO_MD5_LIBC supported. */
/* #undef ARCHIVE_CRYPTO_MD5_LIBC */

/* MD5 via ARCHIVE_CRYPTO_MD5_LIBSYSTEM supported. */
/* #undef ARCHIVE_CRYPTO_MD5_LIBSYSTEM */

/* MD5 via ARCHIVE_CRYPTO_MD5_MBEDTLS supported. */
/* #undef ARCHIVE_CRYPTO_MD5_MBEDTLS */

/* MD5 via ARCHIVE_CRYPTO_MD5_NETTLE supported. */
/* #undef ARCHIVE_CRYPTO_MD5_NETTLE */

/* MD5 via ARCHIVE_CRYPTO_MD5_OPENSSL supported. */
/* #undef ARCHIVE_CRYPTO_MD5_OPENSSL */

/* MD5 via ARCHIVE_CRYPTO_MD5_WIN supported. */
/* #undef ARCHIVE_CRYPTO_MD5_WIN */

/* RMD160 via ARCHIVE_CRYPTO_RMD160_LIBC supported. */
/* #undef ARCHIVE_CRYPTO_RMD160_LIBC */

/* RMD160 via ARCHIVE_CRYPTO_RMD160_NETTLE supported. */
/* #undef ARCHIVE_CRYPTO_RMD160_NETTLE */

/* RMD160 via ARCHIVE_CRYPTO_RMD160_MBEDTLS supported. */
/* #undef ARCHIVE_CRYPTO_RMD160_MBEDTLS */

/* RMD160 via ARCHIVE_CRYPTO_RMD160_OPENSSL supported. */
/* #undef ARCHIVE_CRYPTO_RMD160_OPENSSL */

/* SHA1 via ARCHIVE_CRYPTO_SHA1_LIBC supported. */
/* #undef ARCHIVE_CRYPTO_SHA1_LIBC */

/* SHA1 via ARCHIVE_CRYPTO_SHA1_LIBSYSTEM supported. */
/* #undef ARCHIVE_CRYPTO_SHA1_LIBSYSTEM */

/* SHA1 via ARCHIVE_CRYPTO_SHA1_MBEDTLS supported. */
/* #undef ARCHIVE_CRYPTO_SHA1_MBEDTLS */

/* SHA1 via ARCHIVE_CRYPTO_SHA1_NETTLE supported. */
/* #undef ARCHIVE_CRYPTO_SHA1_NETTLE */

/* SHA1 via ARCHIVE_CRYPTO_SHA1_OPENSSL supported. */
/* #undef ARCHIVE_CRYPTO_SHA1_OPENSSL */

/* SHA1 via ARCHIVE_CRYPTO_SHA1_WIN supported. */
/* #undef ARCHIVE_CRYPTO_SHA1_WIN */

/* SHA256 via ARCHIVE_CRYPTO_SHA256_LIBC supported. */
/* #undef ARCHIVE_CRYPTO_SHA256_LIBC */

/* SHA256 via ARCHIVE_CRYPTO_SHA256_LIBC2 supported. */
/* #undef ARCHIVE_CRYPTO_SHA256_LIBC2 */

/* SHA256 via ARCHIVE_CRYPTO_SHA256_LIBC3 supported. */
/* #undef ARCHIVE_CRYPTO_SHA256_LIBC3 */

/* SHA256 via ARCHIVE_CRYPTO_SHA256_LIBSYSTEM supported. */
/* #undef ARCHIVE_CRYPTO_SHA256_LIBSYSTEM */

/* SHA256 via ARCHIVE_CRYPTO_SHA256_MBEDTLS supported. */
/* #undef ARCHIVE_CRYPTO_SHA256_MBEDTLS */

/* SHA256 via ARCHIVE_CRYPTO_SHA256_NETTLE supported. */
/* #undef ARCHIVE_CRYPTO_SHA256_NETTLE */

/* SHA256 via ARCHIVE_CRYPTO_SHA256_OPENSSL supported. */
/* #undef ARCHIVE_CRYPTO_SHA256_OPENSSL */

/* SHA256 via ARCHIVE_CRYPTO_SHA256_WIN supported. */
/* #undef ARCHIVE_CRYPTO_SHA256_WIN */

/* SHA384 via ARCHIVE_CRYPTO_SHA384_LIBC supported. */
/* #undef ARCHIVE_CRYPTO_SHA384_LIBC */

/* SHA384 via ARCHIVE_CRYPTO_SHA384_LIBC2 supported. */
/* #undef ARCHIVE_CRYPTO_SHA384_LIBC2 */

/* SHA384 via ARCHIVE_CRYPTO_SHA384_LIBC3 supported. */
/* #undef ARCHIVE_CRYPTO_SHA384_LIBC3 */

/* SHA384 via ARCHIVE_CRYPTO_SHA384_LIBSYSTEM supported. */
/* #undef ARCHIVE_CRYPTO_SHA384_LIBSYSTEM */

/* SHA384 via ARCHIVE_CRYPTO_SHA384_MBEDTLS supported. */
/* #undef ARCHIVE_CRYPTO_SHA384_MBEDTLS */

/* SHA384 via ARCHIVE_CRYPTO_SHA384_NETTLE supported. */
/* #undef ARCHIVE_CRYPTO_SHA384_NETTLE */

/* SHA384 via ARCHIVE_CRYPTO_SHA384_OPENSSL supported. */
/* #undef ARCHIVE_CRYPTO_SHA384_OPENSSL */

/* SHA384 via ARCHIVE_CRYPTO_SHA384_WIN supported. */
/* #undef ARCHIVE_CRYPTO_SHA384_WIN */

/* SHA512 via ARCHIVE_CRYPTO_SHA512_LIBC supported. */
/* #undef ARCHIVE_CRYPTO_SHA512_LIBC */

/* SHA512 via ARCHIVE_CRYPTO_SHA512_LIBC2 supported. */
/* #undef ARCHIVE_CRYPTO_SHA512_LIBC2 */

/* SHA512 via ARCHIVE_CRYPTO_SHA512_LIBC3 supported. */
/* #undef ARCHIVE_CRYPTO_SHA512_LIBC3 */

/* SHA512 via ARCHIVE_CRYPTO_SHA512_LIBSYSTEM supported. */
/* #undef ARCHIVE_CRYPTO_SHA512_LIBSYSTEM */

/* SHA512 via ARCHIVE_CRYPTO_SHA512_MBEDTLS supported. */
/* #undef ARCHIVE_CRYPTO_SHA512_MBEDTLS */

/* SHA512 via ARCHIVE_CRYPTO_SHA512_NETTLE supported. */
/* #undef ARCHIVE_CRYPTO_SHA512_NETTLE */

/* SHA512 via ARCHIVE_CRYPTO_SHA512_OPENSSL supported. */
/* #undef ARCHIVE_CRYPTO_SHA512_OPENSSL */

/* SHA512 via ARCHIVE_CRYPTO_SHA512_WIN supported. */
/* #undef ARCHIVE_CRYPTO_SHA512_WIN */

/* AIX xattr support */
/* #undef ARCHIVE_XATTR_AIX */

/* Darwin xattr support */
#ifdef __APPLE__
#define ARCHIVE_XATTR_DARWIN 1
#endif

/* FreeBSD xattr support */
#ifdef __FreeBSD__
#define ARCHIVE_XATTR_FREEBSD
#endif

/* Linux xattr support */
/* #undef ARCHIVE_XATTR_LINUX */

/* Version number of bsdcpio */
#define BSDCPIO_VERSION_STRING "3.7.4"

/* Version number of bsdtar */
#define BSDTAR_VERSION_STRING "3.7.4"

/* Version number of bsdcat */
#define BSDCAT_VERSION_STRING "3.7.4"

/* Version number of bsdunzip */
#define BSDUNZIP_VERSION_STRING "3.7.4"

/* Define to 1 if you have the `acl_create_entry' function. */
/* #undef HAVE_ACL_CREATE_ENTRY */

/* Define to 1 if you have the `acl_get_fd_np' function. */
/* #undef HAVE_ACL_GET_FD_NP */

/* Define to 1 if you have the `acl_get_link' function. */
/* #undef HAVE_ACL_GET_LINK */

/* Define to 1 if you have the `acl_get_link_np' function. */
/* #undef HAVE_ACL_GET_LINK_NP */

/* Define to 1 if you have the `acl_get_perm' function. */
/* #undef HAVE_ACL_GET_PERM */

/* Define to 1 if you have the `acl_get_perm_np' function. */
/* #undef HAVE_ACL_GET_PERM_NP */

/* Define to 1 if you have the `acl_init' function. */
/* #undef HAVE_ACL_INIT */

/* Define to 1 if you have the <acl/libacl.h> header file. */
#if defined(HAVE_LIBACL) &&  __has_include("<acl/libacl.h>")
#define HAVE_ACL_LIBACL_H 1
#endif

/* Define to 1 if the system has the type `acl_permset_t'. */
/* #undef HAVE_ACL_PERMSET_T */

/* Define to 1 if you have the `acl_set_fd' function. */
/* #undef HAVE_ACL_SET_FD */

/* Define to 1 if you have the `acl_set_fd_np' function. */
/* #undef HAVE_ACL_SET_FD_NP */

/* Define to 1 if you have the `acl_set_file' function. */
/* #undef HAVE_ACL_SET_FILE */

/* Define to 1 if you have the `arc4random_buf' function. */
/* #undef HAVE_ARC4RANDOM_BUF */

/* Define to 1 if you have the <attr/xattr.h> header file. */
#if __has_include(<attr/xattr.h>)
#define HAVE_ATTR_XATTR_H 1
#endif

/* Define to 1 if you have the <bcrypt.h> header file. */
#if __has_include(<bcrypt.h>)
#define HAVE_BCRYPT_H 1
#endif

/* Define to 1 if you have the <bsdxml.h> header file. */
#if defined(HAVE_LIBBSDXML) && __has_include(<bsdxml.h>)
#define HAVE_BSDXML_H 1
#endif

/* Define to 1 if you have the <bzlib.h> header file. */
#if defined(HAVE_LIBBZ2) && __has_include(<bzlib.h>)
#define HAVE_BZLIB_H 1
#endif

/* Define to 1 if you have the `chflags' function. */
#if defined(__APPLE__) || defined(__FreeBSD__)
#define HAVE_CHFLAGS 1
#endif

/* Define to 1 if you have the `chown' function. */
#define HAVE_CHOWN 1

/* Define to 1 if you have the `chroot' function. */
#define HAVE_CHROOT 1

/* Define to 1 if you have the <copyfile.h> header file. */
#if __has_include(<copyfile.h>)
#define HAVE_COPYFILE_H 1
#endif

/* Define to 1 if you have the `ctime_r' function. */
#define HAVE_CTIME_R 1

/* Define to 1 if you have the <ctype.h> header file. */
#define HAVE_CTYPE_H 1

/* Define to 1 if you have the `cygwin_conv_path' function. */
/* #undef HAVE_CYGWIN_CONV_PATH */

/* Define to 1 if you have the declaration of `ACE_GETACL', and to 0 if you
   don't. */
/* #undef HAVE_DECL_ACE_GETACL */

/* Define to 1 if you have the declaration of `ACE_GETACLCNT', and to 0 if you
   don't. */
/* #undef HAVE_DECL_ACE_GETACLCNT */

/* Define to 1 if you have the declaration of `ACE_SETACL', and to 0 if you
   don't. */
/* #undef HAVE_DECL_ACE_SETACL */

/* Define to 1 if you have the declaration of `ACL_SYNCHRONIZE', and to 0 if
   you don't. */
/* #undef HAVE_DECL_ACL_SYNCHRONIZE */

/* Define to 1 if you have the declaration of `ACL_TYPE_EXTENDED', and to 0 if
   you don't. */
/* #undef HAVE_DECL_ACL_TYPE_EXTENDED */

/* Define to 1 if you have the declaration of `ACL_TYPE_NFS4', and to 0 if you
   don't. */
/* #undef HAVE_DECL_ACL_TYPE_NFS4 */

/* Define to 1 if you have the declaration of `ACL_USER', and to 0 if you
   don't. */
/* #undef HAVE_DECL_ACL_USER */

/* Define to 1 if you have the declaration of `INT32_MAX', and to 0 if you
   don't. */
#define HAVE_DECL_INT32_MAX 1

/* Define to 1 if you have the declaration of `INT32_MIN', and to 0 if you
   don't. */
#define HAVE_DECL_INT32_MIN 1

/* Define to 1 if you have the declaration of `INT64_MAX', and to 0 if you
   don't. */
#define HAVE_DECL_INT64_MAX 1

/* Define to 1 if you have the declaration of `INT64_MIN', and to 0 if you
   don't. */
#define HAVE_DECL_INT64_MIN 1

/* Define to 1 if you have the declaration of `INTMAX_MAX', and to 0 if you
   don't. */
#define HAVE_DECL_INTMAX_MAX 1

/* Define to 1 if you have the declaration of `INTMAX_MIN', and to 0 if you
   don't. */
#define HAVE_DECL_INTMAX_MIN 1

/* Define to 1 if you have the declaration of `SETACL', and to 0 if you don't.
   */
/* #undef HAVE_DECL_SETACL */

/* Define to 1 if you have the declaration of `SIZE_MAX', and to 0 if you
   don't. */
#define HAVE_DECL_SIZE_MAX 1

/* Define to 1 if you have the declaration of `SSIZE_MAX', and to 0 if you
   don't. */
#define HAVE_DECL_SSIZE_MAX 1

/* Define to 1 if you have the declaration of `strerror_r', and to 0 if you
   don't. */
#define HAVE_DECL_STRERROR_R 1

/* Define to 1 if you have the declaration of `UINT32_MAX', and to 0 if you
   don't. */
#define HAVE_DECL_UINT32_MAX 1

/* Define to 1 if you have the declaration of `UINT64_MAX', and to 0 if you
   don't. */
#define HAVE_DECL_UINT64_MAX 1

/* Define to 1 if you have the declaration of `UINTMAX_MAX', and to 0 if you
   don't. */
#define HAVE_DECL_UINTMAX_MAX 1

/* Define to 1 if you have the declaration of `XATTR_NOFOLLOW', and to 0 if
   you don't. */
/* #undef HAVE_DECL_XATTR_NOFOLLOW */

/* Define to 1 if you have the <direct.h> header file. */
#if __has_include(<direct.h>)
#define HAVE_DIRECT_H 1
#endif

/* Define to 1 if you have the <dirent.h> header file, and it defines `DIR'.
   */
#if __has_include(<dirent.h>)
#define HAVE_DIRENT_H 1
#endif

/* Define to 1 if you have the `dirfd' function. */
#define HAVE_DIRFD 1

/* Define to 1 if you have the <dlfcn.h> header file. */
#if __has_include(<dlfcn.h>)
#define HAVE_DLFCN_H 1
#endif

/* Define to 1 if you don't have `vprintf' but do have `_doprnt.' */
/* #undef HAVE_DOPRNT */

/* Define to 1 if nl_langinfo supports D_MD_ORDER */
/* #undef HAVE_D_MD_ORDER */

/* A possible errno value for invalid file format errors */
/* #undef HAVE_EFTYPE */

/* A possible errno value for invalid file format errors */
#define HAVE_EILSEQ 1

/* Define to 1 if you have the <errno.h> header file. */
#if __has_include(<errno.h>)
#define HAVE_ERRNO_H 1
#endif

/* Define to 1 if you have the <expat.h> header file. */
#if defined(HAVE_LIBEXPAT) && __has_include(<expat.h>)
#define HAVE_EXPAT_H 1
#endif

/* Define to 1 if you have the <ext2fs/ext2_fs.h> header file. */
#if __has_include(<ext2fs/ext2_fs.h>)
#define HAVE_EXT2FS_EXT2_FS_H 1
#endif

/* Define to 1 if you have the `extattr_get_file' function. */
/* #undef HAVE_EXTATTR_GET_FILE */

/* Define to 1 if you have the `extattr_list_file' function. */
/* #undef HAVE_EXTATTR_LIST_FILE */

/* Define to 1 if you have the `extattr_set_fd' function. */
/* #undef HAVE_EXTATTR_SET_FD */

/* Define to 1 if you have the `extattr_set_file' function. */
/* #undef HAVE_EXTATTR_SET_FILE */

/* Define to 1 if EXTATTR_NAMESPACE_USER is defined in sys/extattr.h. */
/* #undef HAVE_DECL_EXTATTR_NAMESPACE_USER */

/* Define to 1 if you have the declaration of `GETACL', and to 0 if you don't.
   */
/* #undef HAVE_DECL_GETACL */

/* Define to 1 if you have the declaration of `GETACLCNT', and to 0 if you
   don't. */
/* #undef HAVE_DECL_GETACLCNT */

/* Define to 1 if you have the `fchdir' function. */
#define HAVE_FCHDIR 1

/* Define to 1 if you have the `fchflags' function. */
#if defined(__APPLE__) || defined(__FreeBSD__)
#define HAVE_FCHFLAGS 1
#endif

/* Define to 1 if you have the `fchmod' function. */
#define HAVE_FCHMOD 1

/* Define to 1 if you have the `fchown' function. */
#define HAVE_FCHOWN 1

/* Define to 1 if you have the `fcntl' function. */
#define HAVE_FCNTL 1

/* Define to 1 if you have the <fcntl.h> header file. */
#if __has_include(<fcntl.h>)
#define HAVE_FCNTL_H 1
#endif

/* Define to 1 if you have the `fdopendir' function. */
#define HAVE_FDOPENDIR 1

/* Define to 1 if you have the `fgetea' function. */
/* #undef HAVE_FGETEA */

/* Define to 1 if you have the `fgetxattr' function. */
#if defined(__APPLE__) || defined(__FreeBSD__)
#define HAVE_FGETXATTR 1
#endif

/* Define to 1 if you have the `flistea' function. */
/* #undef HAVE_FLISTEA */

/* Define to 1 if you have the `flistxattr' function. */
#if defined(__APPLE__) || defined(__FreeBSD__)
#define HAVE_FLISTXATTR 1
#endif

/* Define to 1 if you have the `fnmatch' function. */
#define HAVE_FNMATCH 1

/* Define to 1 if you have the <fnmatch.h> header file. */
#if __has_include(<fnmatch.h>)
#define HAVE_FNMATCH_H 1
#endif

/* Define to 1 if you have the `fork' function. */
#define HAVE_FORK 1

/* Define to 1 if fseeko (and presumably ftello) exists and is declared. */
#define HAVE_FSEEKO 1

/* Define to 1 if you have the `fsetea' function. */
/* #undef HAVE_FSETEA */

/* Define to 1 if you have the `fsetxattr' function. */
#if defined(__APPLE__) || defined(__FreeBSD__)
#define HAVE_FSETXATTR 1
#endif

/* Define to 1 if you have the `fstat' function. */
#define HAVE_FSTAT 1

/* Define to 1 if you have the `fstatat' function. */
#define HAVE_FSTATAT 1

/* Define to 1 if you have the `fstatfs' function. */
#define HAVE_FSTATFS 1

/* Define to 1 if you have the `fstatvfs' function. */
#define HAVE_FSTATVFS 1

/* Define to 1 if you have the `ftruncate' function. */
#define HAVE_FTRUNCATE 1

/* Define to 1 if you have the `futimens' function. */
#define HAVE_FUTIMENS 1

/* Define to 1 if you have the `futimes' function. */
#define HAVE_FUTIMES 1

/* Define to 1 if you have the `futimesat' function. */
/* #undef HAVE_FUTIMESAT */

/* Define to 1 if you have the `getea' function. */
/* #undef HAVE_GETEA */

/* Define to 1 if you have the `geteuid' function. */
#define HAVE_GETEUID 1

/* Define to 1 if you have the `getgrgid_r' function. */
#define HAVE_GETGRGID_R 1

/* Define to 1 if you have the `getgrnam_r' function. */
#define HAVE_GETGRNAM_R 1

/* Define to 1 if you have the `getline' function. */
#define HAVE_GETLINE 1

/* Define to 1 if you have the `getpid' function. */
#define HAVE_GETPID 1

/* Define to 1 if you have the `getpwnam_r' function. */
#define HAVE_GETPWNAM_R 1

/* Define to 1 if you have the `getpwuid_r' function. */
#define HAVE_GETPWUID_R 1

/* Define to 1 if you have the `getvfsbyname' function. */
#if defined(__APPLE__) || defined(__FreeBSD__)
#define HAVE_GETVFSBYNAME 1
#endif

/* Define to 1 if you have the `getxattr' function. */
#if defined(__APPLE__) || defined(__FreeBSD__)
#define HAVE_GETXATTR 1
#endif

/* Define to 1 if you have the `gmtime_r' function. */
#define HAVE_GMTIME_R 1

/* Define to 1 if you have the <grp.h> header file. */
#if __has_include(<grp.h>)
#define HAVE_GRP_H 1
#endif

/* Define to 1 if you have the `iconv' function. */
/* #undef HAVE_ICONV */

/* Define to 1 if you have the <iconv.h> header file. */
#if __has_include(<iconv.h>)
#define HAVE_ICONV_H 1
#endif

/* Define to 1 if you have the <inttypes.h> header file. */
#if __has_include(<inttypes.h>)
#define HAVE_INTTYPES_H 1
#endif

/* Define to 1 if you have the <io.h> header file. */
#if __has_include(<io.h>)
#define HAVE_IO_H 1
#endif

/* Define to 1 if you have the <langinfo.h> header file. */
#if __has_include(<langinfo.h>)
#define HAVE_LANGINFO_H 1
#endif

/* Define to 1 if you have the `lchflags' function. */
#if defined(__APPLE__) || defined(__FreeBSD__)
#define HAVE_LCHFLAGS 1
#endif

/* Define to 1 if you have the `lchmod' function. */
#if defined(__APPLE__) || defined(__FreeBSD__)
#define HAVE_LCHMOD 1
#endif

/* Define to 1 if you have the `lchown' function. */
#define HAVE_LCHOWN 1

/* Define to 1 if you have the `lgetea' function. */
/* #undef HAVE_LGETEA */

/* Define to 1 if you have the `lgetxattr' function. */
#if defined(__APPLE__) || defined(__FreeBSD__)
#define HAVE_LGETXATTR 1
#endif

/* Define to 1 if you have the <blake2.h> header file. */
#if __has_include(<blake2.h>)
#define HAVE_BLAKE2_H 1
#endif

/* Define to 1 if you have the <libxml/xmlreader.h> header file. */
#if defined(HAVE_LIBXML2) && __has_include(<libxml/xmlreader.h>)
#define HAVE_LIBXML_XMLREADER_H 1
#endif

/* Define to 1 if you have the <libxml/xmlwriter.h> header file. */
#if defined(HAVE_LIBXML2) && __has_include(<libxml/xmlwriter.h>)
#define HAVE_LIBXML_XMLWRITER_H 1
#endif

/* Define to 1 if you have the ZSTD_compressStream function. */
/* #undef HAVE_ZSTD_compressStream */

/* Define to 1 if you have the <limits.h> header file. */
#if __has_include(<limits.h>)
#define HAVE_LIMITS_H 1
#endif

/* Define to 1 if you have the `link' function. */
#define HAVE_LINK 1

/* Define to 1 if you have the `linkat' function. */
#define HAVE_LINKAT 1

/* Define to 1 if you have the <linux/fiemap.h> header file. */
#if __has_include(<linux/fiemap.h>)
#define HAVE_LINUX_FIEMAP_H 1
#endif

/* Define to 1 if you have the <linux/fs.h> header file. */
#if __has_include(<linux/fs.h>)
#define HAVE_LINUX_FS_H 1
#endif

/* Define to 1 if you have the <linux/magic.h> header file. */
#if __has_include(<linux/magic.h>)
#define HAVE_LINUX_MAGIC_H 1
#endif

/* Define to 1 if you have the <linux/types.h> header file. */
#if __has_include(<linux/types.h>)
#define HAVE_LINUX_TYPES_H 1
#endif

/* Define to 1 if you have the `listea' function. */
/* #undef HAVE_LISTEA */

/* Define to 1 if you have the `listxattr' function. */
#if defined(__APPLE__) || defined(__FreeBSD__)
#define HAVE_LISTXATTR 1
#endif

/* Define to 1 if you have the `llistea' function. */
/* #undef HAVE_LLISTEA */

/* Define to 1 if you have the `llistxattr' function. */
/* #undef HAVE_LLISTXATTR */

/* Define to 1 if you have the <localcharset.h> header file. */
#if __has_include(<localcharset.h>)
#define HAVE_LOCALCHARSET_H 1
#endif

/* Define to 1 if you have the `locale_charset' function. */
/* #undef HAVE_LOCALE_CHARSET */

/* Define to 1 if you have the <locale.h> header file. */
#if __has_include(<locale.h>)
#define HAVE_LOCALE_H 1
#endif

/* Define to 1 if you have the `localtime_r' function. */
#define HAVE_LOCALTIME_R 1

/* Define to 1 if the system has the type `long long int'. */
/* #undef HAVE_LONG_LONG_INT */

/* Define to 1 if you have the `lsetea' function. */
/* #undef HAVE_LSETEA */

/* Define to 1 if you have the `lsetxattr' function. */
/* #undef HAVE_LSETXATTR */

/* Define to 1 if you have the `lstat' function. */
#define HAVE_LSTAT 1

/* Define to 1 if `lstat' has the bug that it succeeds when given the
   zero-length file name argument. */
/* #undef HAVE_LSTAT_EMPTY_STRING_BUG */

/* Define to 1 if you have the `lutimes' function. */
#define HAVE_LUTIMES 1

/* Define to 1 if you have the <lz4hc.h> header file. */
#if defined(HAVE_LIBLZ4) && __has_include(<lz4hc.h>)
#define HAVE_LZ4HC_H 1
#endif

/* Define to 1 if you have the <lz4.h> header file. */
#if defined(HAVE_LIBLZ4) && __has_include(<lz4.h>)
#define HAVE_LZ4_H 1
#endif

/* Define to 1 if you have the <lzmadec.h> header file. */
#if defined(HAVE_LIBLZMADEC) && __has_include(<lzmadec.h>)
#define HAVE_LZMADEC_H 1
#endif

/* Define to 1 if you have the <lzma.h> header file. */
#if defined(HAVE_LIBLZMA) && __has_include(<lzma.h>)
#define HAVE_LZMA_H 1
#endif

/* Define to 1 if you have a working `lzma_stream_encoder_mt' function. */
/* #undef HAVE_LZMA_STREAM_ENCODER_MT */

/* Define to 1 if you have the <lzo/lzo1x.h> header file. */
#if defined(HAVE_LIBLZO2) && __has_include(<lzo/lzo1x.h>)
#define HAVE_LZO_LZO1X_H 1
#endif

/* Define to 1 if you have the <lzo/lzoconf.h> header file. */
#if defined(HAVE_LIBLZO2) && __has_include(<lzo/lzoconf.h>)
#define HAVE_LZO_LZOCONF_H 1
#endif

/* Define to 1 if you have the <mbedtls/aes.h> header file. */
#if defined(HAVE_LIBMBEDCRYPTO) && __has_include(<mbedtls/aes.h>)
#define HAVE_MBEDTLS_AES_H 1
#endif

/* Define to 1 if you have the <mbedtls/md.h> header file. */
#if defined(HAVE_LIBMBEDCRYPTO) && __has_include(<mbedtls/md.h>)
#define HAVE_MBEDTLS_MD_H 1
#endif

/* Define to 1 if you have the <mbedtls/pkcs5.h> header file. */
#if defined(HAVE_LIBMBEDCRYPTO) && __has_include(<mbedtls/pkcs5.h>)
#define HAVE_MBEDTLS_PKCS5_H 1
#endif

/* Define to 1 if you have the `mbrtowc' function. */
#define HAVE_MBRTOWC 1

/* Define to 1 if you have the <membership.h> header file. */
#if __has_include(<membership.h>)
#define HAVE_MEMBERSHIP_H 1
#endif

/* Define to 1 if you have the `memmove' function. */
#define HAVE_MEMMOVE 1

/* Define to 1 if you have the <memory.h> header file. */
#if __has_include(<memory.h>)
#define HAVE_MEMORY_H 1
#endif

/* Define to 1 if you have the `mkdir' function. */
#define HAVE_MKDIR 1

/* Define to 1 if you have the `mkfifo' function. */
#define HAVE_MKFIFO 1

/* Define to 1 if you have the `mknod' function. */
#define HAVE_MKNOD 1

/* Define to 1 if you have the `mkstemp' function. */
#define HAVE_MKSTEMP 1

/* Define to 1 if you have the <ndir.h> header file, and it defines `DIR'. */
#if __has_include(<ndir.h>)
#define HAVE_NDIR_H 1
#endif

/* Define to 1 if you have the <nettle/aes.h> header file. */
#if defined(HAVE_LIBNETTLE) && __has_include(<nettle/aes.h>)
#define HAVE_NETTLE_AES_H 1
#endif

/* Define to 1 if you have the <nettle/hmac.h> header file. */
#if defined(HAVE_LIBNETTLE) && __has_include(<nettle/hmac.h>)
#define HAVE_NETTLE_HMAC_H 1
#endif

/* Define to 1 if you have the <nettle/md5.h> header file. */
#if defined(HAVE_LIBNETTLE) && __has_include(<nettle/md5.h>)
#define HAVE_NETTLE_MD5_H 1
#endif

/* Define to 1 if you have the <nettle/pbkdf2.h> header file. */
#if defined(HAVE_LIBNETTLE) && __has_include(<nettle/pbkdf2.h>)
#define HAVE_NETTLE_PBKDF2_H 1
#endif

/* Define to 1 if you have the <nettle/ripemd160.h> header file. */
#if defined(HAVE_LIBNETTLE) && __has_include(<nettle/ripemd160.h>)
#define HAVE_NETTLE_RIPEMD160_H 1
#endif

/* Define to 1 if you have the <nettle/sha.h> header file. */
#if defined(HAVE_LIBNETTLE) && __has_include(<nettle/sha.h>)
#define HAVE_NETTLE_SHA_H 1
#endif

/* Define to 1 if you have the `nl_langinfo' function. */
#define HAVE_NL_LANGINFO 1

/* Define to 1 if you have the `openat' function. */
#define HAVE_OPENAT 1

/* Define to 1 if you have the <openssl/evp.h> header file. */
#if __has_include(<openssl/evp.h>)
#define HAVE_OPENSSL_EVP_H 1
#endif

/* Define to 1 if you have the <paths.h> header file. */
#if __has_include(<paths.h>)
#define HAVE_PATHS_H 1
#endif

/* Define to 1 if you have the <pcreposix.h> header file. */
#if defined(HAVE_PCREPOSIX) && __has_include(<pcreposix.h>)
#define HAVE_PCREPOSIX_H 1
#endif

/* Define to 1 if you have the <pcre2posix.h> header file. */
#if defined(HAVE_PCRE2POSIX) && __has_include(<pcre2posix.h>)
#define HAVE_PCRE2POSIX_H 1
#endif

/* Define to 1 if you have the `pipe' function. */
#define HAVE_PIPE 1

/* Define to 1 if you have the `PKCS5_PBKDF2_HMAC_SHA1' function. */
/* #undef HAVE_PKCS5_PBKDF2_HMAC_SHA1 */

/* Define to 1 if you have the `poll' function. */
#define HAVE_POLL 1

/* Define to 1 if you have the <poll.h> header file. */
#if __has_include(<poll.h>)
#define HAVE_POLL_H 1
#endif

/* Define to 1 if you have the `posix_spawnp' function. */
#define HAVE_POSIX_SPAWNP 1

/* Define to 1 if you have the <process.h> header file. */
#if __has_include(<process.h>)
#define HAVE_PROCESS_H 1
#endif

/* Define to 1 if you have the <pthread.h> header file. */
#if __has_include(<pthread.h>)
#define HAVE_PTHREAD_H 1
#endif

/* Define to 1 if you have the <pwd.h> header file. */
#if __has_include(<pwd.h>)
#define HAVE_PWD_H 1
#endif

/* Define to 1 if you have the `readdir_r' function. */
#if defined(__APPLE__) || defined(__FreeBSD__)
#define HAVE_READDIR_R 1
#endif

/* Define to 1 if you have the `readlink' function. */
#define HAVE_READLINK 1

/* Define to 1 if you have the `readlinkat' function. */
#define HAVE_READLINKAT 1

/* Define to 1 if you have the `readpassphrase' function. */
#if defined(__APPLE__)
#define HAVE_READPASSPHRASE 1
#endif

/* Define to 1 if you have the <readpassphrase.h> header file. */
#if __has_include(<readpassphrase.h>)
#define HAVE_READPASSPHRASE_H 1
#endif

/* Define to 1 if you have the <regex.h> header file. */
#if __has_include(<regex.h>)
#define HAVE_REGEX_H 1
#endif

/* Define to 1 if you have the `select' function. */
#define HAVE_SELECT 1

/* Define to 1 if you have the `setenv' function. */
#define HAVE_SETENV 1

/* Define to 1 if you have the `setlocale' function. */
#define HAVE_SETLOCALE 1

/* Define to 1 if you have the `sigaction' function. */
#define HAVE_SIGACTION 1

/* Define to 1 if you have the <signal.h> header file. */
#if __has_include(<signal.h>)
#define HAVE_SIGNAL_H 1
#endif

/* Define to 1 if you have the <spawn.h> header file. */
#if __has_include(<spawn.h>)
#define HAVE_SPAWN_H 1
#endif

/* Define to 1 if you have the `statfs' function. */
#define HAVE_STATFS 1

/* Define to 1 if you have the `statvfs' function. */
#define HAVE_STATVFS 1

/* Define to 1 if `stat' has the bug that it succeeds when given the
   zero-length file name argument. */
/* #undef HAVE_STAT_EMPTY_STRING_BUG */

/* Define to 1 if you have the <stdarg.h> header file. */
#if __has_include(<stdarg.h>)
#define HAVE_STDARG_H 1
#endif

/* Define to 1 if you have the <stdint.h> header file. */
#if __has_include(<stdint.h>)
#define HAVE_STDINT_H 1
#endif

/* Define to 1 if you have the <stdlib.h> header file. */
#if __has_include(<stdlib.h>)
#define HAVE_STDLIB_H 1
#endif

/* Define to 1 if you have the `strchr' function. */
#define HAVE_STRCHR 1

/* Define to 1 if you have the `strnlen' function. */
#define HAVE_STRNLEN 1

/* Define to 1 if you have the `strdup' function. */
#define HAVE_STRDUP 1

/* Define to 1 if you have the `strerror' function. */
#define HAVE_STRERROR 1

/* Define to 1 if you have the `strerror_r' function. */
#define HAVE_STRERROR_R 1

/* Define to 1 if you have the `strftime' function. */
#define HAVE_STRFTIME 1

/* Define to 1 if you have the <strings.h> header file. */
#if __has_include(<strings.h>)
#define HAVE_STRINGS_H 1
#endif

/* Define to 1 if you have the <string.h> header file. */
#if __has_include(<string.h>)
#define HAVE_STRING_H 1
#endif

/* Define to 1 if you have the `strrchr' function. */
#define HAVE_STRRCHR 1

/* Define to 1 if the system has the type `struct statfs'. */
/* #undef HAVE_STRUCT_STATFS */

/* Define to 1 if `f_iosize' is a member of `struct statfs'. */
/* #undef HAVE_STRUCT_STATFS_F_IOSIZE */

/* Define to 1 if `f_namemax' is a member of `struct statfs'. */
/* #undef HAVE_STRUCT_STATFS_F_NAMEMAX */

/* Define to 1 if `f_iosize' is a member of `struct statvfs'. */
/* #undef HAVE_STRUCT_STATVFS_F_IOSIZE */

/* Define to 1 if `st_birthtime' is a member of `struct stat'. */
/* #undef HAVE_STRUCT_STAT_ST_BIRTHTIME */

/* Define to 1 if `st_birthtimespec.tv_nsec' is a member of `struct stat'. */
/* #undef HAVE_STRUCT_STAT_ST_BIRTHTIMESPEC_TV_NSEC */

/* Define to 1 if `st_blksize' is a member of `struct stat'. */
/* #undef HAVE_STRUCT_STAT_ST_BLKSIZE */

/* Define to 1 if `st_flags' is a member of `struct stat'. */
/* #undef HAVE_STRUCT_STAT_ST_FLAGS */

/* Define to 1 if `st_mtimespec.tv_nsec' is a member of `struct stat'. */
/* #undef HAVE_STRUCT_STAT_ST_MTIMESPEC_TV_NSEC */

/* Define to 1 if `st_mtime_n' is a member of `struct stat'. */
/* #undef HAVE_STRUCT_STAT_ST_MTIME_N */

/* Define to 1 if `st_mtime_usec' is a member of `struct stat'. */
/* #undef HAVE_STRUCT_STAT_ST_MTIME_USEC */

/* Define to 1 if `st_mtim.tv_nsec' is a member of `struct stat'. */
/* #undef HAVE_STRUCT_STAT_ST_MTIM_TV_NSEC */

/* Define to 1 if `st_umtime' is a member of `struct stat'. */
/* #undef HAVE_STRUCT_STAT_ST_UMTIME */

/* Define to 1 if `tm_gmtoff' is a member of `struct tm'. */
/* #undef HAVE_STRUCT_TM_TM_GMTOFF */

/* Define to 1 if `__tm_gmtoff' is a member of `struct tm'. */
/* #undef HAVE_STRUCT_TM___TM_GMTOFF */

/* Define to 1 if you have `struct vfsconf'. */
/* #undef HAVE_STRUCT_VFSCONF */

/* Define to 1 if you have `struct xvfsconf'. */
/* #undef HAVE_STRUCT_XVFSCONF */

/* Define to 1 if you have the `symlink' function. */
#define HAVE_SYMLINK 1

/* Define to 1 if you have the `sysconf' function. */
#define HAVE_SYSCONF 1

/* Define to 1 if you have the <sys/acl.h> header file. */
#if defined(HAVE_LIBACL) && __has_include(<sys/acl.h>)
#define HAVE_SYS_ACL_H 1
#endif

/* Define to 1 if you have the <sys/cdefs.h> header file. */
#if __has_include(<sys/cdefs.h>)
#define HAVE_SYS_CDEFS_H 1
#endif

/* Define to 1 if you have the <sys/dir.h> header file, and it defines `DIR'.
   */
#if __has_include(<sys/dir.h>)
#define HAVE_SYS_DIR_H 1
#endif

/* Define to 1 if you have the <sys/ea.h> header file. */
#if __has_include(<sys/ea.h>)
#define HAVE_SYS_EA_H 1
#endif

/* Define to 1 if you have the <sys/extattr.h> header file. */
#if __has_include(<sys/extattr.h>)
#define HAVE_SYS_EXTATTR_H 1
#endif

/* Define to 1 if you have the <sys/ioctl.h> header file. */
#if __has_include(<sys/ioctl.h>)
#define HAVE_SYS_IOCTL_H 1
#endif

/* Define to 1 if you have the <sys/mkdev.h> header file. */
#if __has_include(<sys/mkdev.h>)
#define HAVE_SYS_MKDEV_H 1
#endif

/* Define to 1 if you have the <sys/mount.h> header file. */
#if __has_include(<sys/mount.h>)
#define HAVE_SYS_MOUNT_H 1
#endif

/* Define to 1 if you have the <sys/ndir.h> header file, and it defines `DIR'.
   */
#if __has_include(<sys/ndir.h>)
#define HAVE_SYS_NDIR_H 1
#endif

/* Define to 1 if you have the <sys/param.h> header file. */
#if __has_include(<sys/param.h>)
#define HAVE_SYS_PARAM_H 1
#endif

/* Define to 1 if you have the <sys/poll.h> header file. */
#if __has_include(<sys/poll.h>)
#define HAVE_SYS_POLL_H 1
#endif

/* Define to 1 if you have the <sys/queue.h> header file. */
#if __has_include(<sys/queue.h>)
#define HAVE_SYS_QUEUE_H 1
#endif

/* Define to 1 if you have the <sys/richacl.h> header file. */
#if __has_include(<sys/richacl.h>)
#define HAVE_SYS_RICHACL_H 1
#endif

/* Define to 1 if you have the <sys/select.h> header file. */
#if __has_include(<sys/select.h>)
#define HAVE_SYS_SELECT_H 1
#endif

/* Define to 1 if you have the <sys/statfs.h> header file. */
#if __has_include(<sys/statfs.h>)
#define HAVE_SYS_STATFS_H 1
#endif

/* Define to 1 if you have the <sys/statvfs.h> header file. */
#if __has_include(<sys/statvfs.h>)
#define HAVE_SYS_STATVFS_H 1
#endif

/* Define to 1 if you have the <sys/stat.h> header file. */
#if __has_include(<sys/stat.h>)
#define HAVE_SYS_STAT_H 1
#endif


/* Define to 1 if you have the <sys/sysmacros.h> header file. */
#if __has_include(<sys/sysmacros.h>)
#define HAVE_SYS_SYSMACROS_H 1
#endif

/* Define to 1 if you have the <sys/time.h> header file. */
#if __has_include(<sys/time.h>)
#define HAVE_SYS_TIME_H 1
#endif

/* Define to 1 if you have the <sys/types.h> header file. */
#if __has_include(<sys/types.h>)
#define HAVE_SYS_TYPES_H 1
#endif

/* Define to 1 if you have the <sys/utime.h> header file. */
#if __has_include(<sys/utime.h>)
#define HAVE_SYS_UTIME_H 1
#endif

/* Define to 1 if you have the <sys/utsname.h> header file. */
#if __has_include(<sys/utsname.h>)
#define HAVE_SYS_UTSNAME_H 1
#endif

/* Define to 1 if you have the <sys/vfs.h> header file. */
#if __has_include(<sys/vfs.h>)
#define HAVE_SYS_VFS_H 1
#endif

/* Define to 1 if you have <sys/wait.h> that is POSIX.1 compatible. */
#if __has_include(<sys/wait.h>)
#define HAVE_SYS_WAIT_H 1
#endif

/* Define to 1 if you have the <sys/xattr.h> header file. */
#if __has_include(<sys/xattr.h>)
#define HAVE_SYS_XATTR_H 1
#endif

/* Define to 1 if you have the `timegm' function. */
#define HAVE_TIMEGM 1

/* Define to 1 if you have the <time.h> header file. */
#if __has_include(<time.h>)
#define HAVE_TIME_H 1
#endif

/* Define to 1 if you have the `tzset' function. */
#define HAVE_TZSET 1

/* Define to 1 if you have the <unistd.h> header file. */
#if __has_include(<unistd.h>)
#define HAVE_UNISTD_H 1
#endif

/* Define to 1 if you have the `unlinkat' function. */
#define HAVE_UNLINKAT 1

/* Define to 1 if you have the `unsetenv' function. */
#define HAVE_UNSETENV 1

/* Define to 1 if the system has the type `unsigned long long'. */
/* #undef HAVE_UNSIGNED_LONG_LONG */

/* Define to 1 if the system has the type `unsigned long long int'. */
/* #undef HAVE_UNSIGNED_LONG_LONG_INT */

/* Define to 1 if you have the `utime' function. */
#define HAVE_UTIME 1

/* Define to 1 if you have the `utimensat' function. */
#define HAVE_UTIMENSAT 1

/* Define to 1 if you have the `utimes' function. */
#define HAVE_UTIMES 1

/* Define to 1 if you have the <utime.h> header file. */
#if __has_include(<utime.h>)
#define HAVE_UTIME_H 1
#endif

/* Define to 1 if you have the `vfork' function. */
#define HAVE_VFORK 1

/* Define to 1 if you have the `vprintf' function. */
#define HAVE_VPRINTF 1

/* Define to 1 if you have the <wchar.h> header file. */
#if __has_include(<wchar.h>)
#define HAVE_WCHAR_H 1
#endif

/* Define to 1 if the system has the type `wchar_t'. */
#define HAVE_WCHAR_T 1

/* Define to 1 if you have the `wcrtomb' function. */
#define HAVE_WCRTOMB 1

/* Define to 1 if you have the `wcscmp' function. */
#define HAVE_WCSCMP 1

/* Define to 1 if you have the `wcscpy' function. */
#define HAVE_WCSCPY 1

/* Define to 1 if you have the `wcslen' function. */
#define HAVE_WCSLEN 1

/* Define to 1 if you have the `wctomb' function. */
#define HAVE_WCTOMB 1

/* Define to 1 if you have the <wctype.h> header file. */
#if __has_include(<wctype.h>)
#define HAVE_WCTYPE_H 1
#endif

/* Define to 1 if you have the <wincrypt.h> header file. */
#if __has_include(<wincrypt.h>)
#define HAVE_WINCRYPT_H 1
#endif

/* Define to 1 if you have the <windows.h> header file. */
#if __has_include(<windows.h>)
#define HAVE_WINDOWS_H 1
#endif

/* Define to 1 if you have the <winioctl.h> header file. */
#if __has_include(<winioctl.h>)
#define HAVE_WINIOCTL_H 1
#endif

/* Define to 1 if you have _CrtSetReportMode in <crtdbg.h>  */
/* #undef HAVE__CrtSetReportMode */

/* Define to 1 if you have the `wmemcmp' function. */
#define HAVE_WMEMCMP 1

/* Define to 1 if you have the `wmemcpy' function. */
#define HAVE_WMEMCPY 1

/* Define to 1 if you have the `wmemmove' function. */
#define HAVE_WMEMMOVE 1

/* Define to 1 if you have a working EXT2_IOC_GETFLAGS */
/* #undef HAVE_WORKING_EXT2_IOC_GETFLAGS */

/* Define to 1 if you have a working FS_IOC_GETFLAGS */
#ifdef __linux__
#define HAVE_WORKING_FS_IOC_GETFLAGS 1
#endif

/* Define to 1 if you have the <zlib.h> header file. */
#if defined(HAVE_LIBZ) && __has_include(<zlib.h>)
#define HAVE_ZLIB_H 1
#endif

/* Define to 1 if you have the <zstd.h> header file. */
#if defined(HAVE_LIBZSTD) && __has_include(<zstd.h>)
#define HAVE_ZSTD_H 1
#endif

/* Define to 1 if you have the `ctime_s' function. */
/* #undef HAVE_CTIME_S */

/* Define to 1 if you have the `_fseeki64' function. */
/* #undef HAVE__FSEEKI64 */

/* Define to 1 if you have the `_get_timezone' function. */
/* #undef HAVE__GET_TIMEZONE */

/* Define to 1 if you have the `gmtime_s' function. */
/* #undef HAVE_GMTIME_S */

/* Define to 1 if you have the `localtime_s' function. */
/* #undef HAVE_LOCALTIME_S */

/* Define to 1 if you have the `_mkgmtime' function. */
/* #undef HAVE__MKGMTIME */

/* Define as const if the declaration of iconv() needs const. */
#define ICONV_CONST 

/* Version number of libarchive as a single integer */
#define LIBARCHIVE_VERSION_NUMBER "3007004"

/* Version number of libarchive */
#define LIBARCHIVE_VERSION_STRING "3.7.4"

/* Define to 1 if `lstat' dereferences a symlink specified with a trailing
   slash. */
/* #undef LSTAT_FOLLOWS_SLASHED_SYMLINK */

/* Define to 1 if `major', `minor', and `makedev' are declared in <mkdev.h>.
   */
/* #undef MAJOR_IN_MKDEV */

/* Define to 1 if `major', `minor', and `makedev' are declared in
   <sysmacros.h>. */
#ifdef __linux__
#define MAJOR_IN_SYSMACROS 1
#endif

/* Define to 1 if your C compiler doesn't accept -c and -o together. */
/* #undef NO_MINUS_C_MINUS_O */

/* The size of `wchar_t', as computed by sizeof. */
#define SIZEOF_WCHAR_T sizeof(wchar_t)

/* Define to 1 if strerror_r returns char *. */
/* #undef STRERROR_R_CHAR_P */

/* Define to 1 if you can safely include both <sys/time.h> and <time.h>. */
/* #undef TIME_WITH_SYS_TIME */

/* Version number of package */
#define VERSION "3.7.4"

/* Number of bits in a file offset, on hosts where this is settable. */
/* #undef _FILE_OFFSET_BITS */

/* Define to 1 to make fseeko visible on some hosts (e.g. glibc 2.2). */
/* #undef _LARGEFILE_SOURCE */

/* Define for large files, on AIX-style hosts. */
/* #undef _LARGE_FILES */

/* Define to control Windows SDK version */
#ifndef NTDDI_VERSION
/* #undef NTDDI_VERSION */
#endif // NTDDI_VERSION

#ifndef _WIN32_WINNT
/* #undef _WIN32_WINNT */
#endif // _WIN32_WINNT

#ifndef WINVER
/* #undef WINVER */
#endif // WINVER

#endif /* __clang__ */
