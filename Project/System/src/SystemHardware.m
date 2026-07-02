//
//  SystemHardware.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import <stdlib.h>
#import <string.h>
#import <sys/sysctl.h>

#import "SystemHardware.h"

// Sentinel stored in m_HardwareType before detection runs.
static const int kHardwareUndetected = 15;
// Value used when the model is not in the table.
static const int kHardwareUnknown = 14;

// Known hw.machine identifiers, in the order that defines the hardware type.
// Ghidra: DAT_001306ec (14 entries).
static const char *const kSystemHardwareModels[14] = {
    "iPhone1,1", "iPhone1,2", "iPhone2,1", "iPhone3,1", "iPhone3,2",
    "iPod1,1", "iPod2,1", "iPod3,1", "iPod4,1",
    "iPad1,1", "iPad2,1", "iPad2,2", "iPad2,3", "i386",
};

@implementation SystemHardware {
    int m_HardwareType;
    NSString *m_HardwareName;
}

- (instancetype)init {
    if ((self = [super init])) {
        m_HardwareType = kHardwareUndetected;
    }
    return self;
}

// @ 0x127f4
- (void)initHardware {
    if (m_HardwareType != kHardwareUndetected) {
        return;
    }
    size_t size = 0;
    sysctlbyname("hw.machine", nullptr, &size, nullptr, 0);
    char *machine = (char *)malloc(size);
    sysctlbyname("hw.machine", machine, &size, nullptr, 0);

    m_HardwareName = [[NSString alloc] initWithCString:machine encoding:NSUTF8StringEncoding];

    for (int i = 0; i < 14; i++) {
        if (kSystemHardwareModels[i] && strcmp(kSystemHardwareModels[i], machine) == 0) {
            m_HardwareType = i;
            free(machine);
            return;
        }
    }
    free(machine);
    m_HardwareType = kHardwareUnknown;
}

// @ 0x128e8
- (int)getHardwareType {
    if (m_HardwareType == kHardwareUndetected) {
        [self initHardware];
    }
    return m_HardwareType;
}

// @ 0x1291c
- (NSString *)getHardwareName {
    if (m_HardwareType == kHardwareUndetected) {
        [self initHardware];
    }
    return m_HardwareName;
}

@end
