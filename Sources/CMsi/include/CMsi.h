#pragma once

typedef unsigned short MsiChar; // WCHAR

// MSIINSTALLCONTEXT
#define MSI_CONTEXT_NONE 0
#define MSI_CONTEXT_USERMANAGED 1
#define MSI_CONTEXT_USERUNMANAGED 2
#define MSI_CONTEXT_MACHINE 4
#define MSI_CONTEXT_ALL 7

// INSTALLSTATE
#define MSI_INSTALLSTATE_MOREDATA (-3)
#define MSI_INSTALLSTATE_LOCAL 3

unsigned int __stdcall MsiEnumProductsExW(
    const MsiChar *szProductCode, const MsiChar *szUserSid,
    unsigned long dwContext, unsigned long dwIndex,
    MsiChar *szInstalledProductCode, int *pdwInstalledContext,
    MsiChar *szSid, unsigned long *pcchSid);

unsigned int __stdcall MsiGetProductInfoExW(
    const MsiChar *szProductCode, const MsiChar *szUserSid, int dwContext,
    const MsiChar *szProperty, MsiChar *szValue, unsigned long *pcchValue);

unsigned int __stdcall MsiEnumComponentsExW(
    const MsiChar *szUserSid, unsigned long dwContext, unsigned long dwIndex,
    MsiChar *szInstalledComponentCode, int *pdwInstalledContext,
    MsiChar *szSid, unsigned long *pcchSid);

unsigned int __stdcall MsiEnumClientsExW(
    const MsiChar *szComponent, const MsiChar *szUserSid,
    unsigned long dwContext, unsigned long dwProductIndex,
    MsiChar *szProductBuf, int *pdwInstalledContext,
    MsiChar *szSid, unsigned long *pcchSid);

int __stdcall MsiGetComponentPathExW(
    const MsiChar *szProductCode, const MsiChar *szComponentCode,
    const MsiChar *szUserSid, int dwContext,
    MsiChar *lpOutPathBuffer, unsigned long *pcchOutPathBuffer);
