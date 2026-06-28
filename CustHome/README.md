# CustHome

CustHome is a standalone extraction of the Home Screen editing menu work from Solarium15+.

This first build only carries over the current Home Screen plus-button context menu implementation exactly as it exists today, with no recreated behavior and no additional customize-surface features yet.

## Building

```sh
env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
    SWIFT_MODULE_CACHE_PATH=/tmp/swift-module-cache \
    make clean package
```
