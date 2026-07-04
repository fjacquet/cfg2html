
# cfg2html - macOS (Darwin) specific functions

function identify_macos_version {
    MACOS_VERSION="$(sw_vers -productName) $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
}
