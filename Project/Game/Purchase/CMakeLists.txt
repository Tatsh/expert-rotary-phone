# CMakeLists.txt — Project/Game/Purchase
#
# Adds this directory's translation units (and headers, for Xcode) to the single app target
# defined in the root CMakeLists, and puts the directory on the include path. Bare filenames.

target_sources(popnrhythmin PRIVATE
    PurchaseManager.m
    PurchaseTransactionCache.m
    PurchaseManager.h
    PurchaseTransactionCache.h
)

target_include_directories(popnrhythmin PRIVATE .)
