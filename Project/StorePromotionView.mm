//
//  StorePromotionView.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StorePromotionView.h"

// Engine glue: scene manager singleton + boot-time iPad-display flag (DAT_00187b84).
extern "C" {
void *NESceneManager_shared(void);
extern char g_IsPadDisplay;
}

@implementation StorePromotionView

@synthesize delegate = m_Delegate;

// @ 0x79900
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self SetupView];
        m_ImageDownloader = [[NSMutableArray alloc] initWithCapacity:0];
    }
    return self;
}

// @ 0x79c2c — a centered spinner, a front + next image view (next starts hidden via
// alpha 0), a whole-view tap gesture, and on iPad a rounded, bordered, clipped frame.
- (void)SetupView {
    m_Indicator =
        [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    m_Indicator.center = CGPointMake(CGRectGetWidth(self.bounds) / 2.0f,
                                     CGRectGetHeight(self.bounds) / 2.0f);
    [m_Indicator startAnimating];
    [self addSubview:m_Indicator];

    // Front/next image views are owned by the view hierarchy; the ivars are
    // unretained aliases (matching the binary — autorelease + addSubview, no retain).
    m_FrontImageView = [[[UIImageView alloc] initWithFrame:self.bounds] autorelease];
    [self addSubview:m_FrontImageView];
    m_FrontImageView.hidden = YES;

    m_NextImageView = [[[UIImageView alloc] initWithFrame:self.bounds] autorelease];
    [self addSubview:m_NextImageView];
    m_NextImageView.alpha = 0.0f;

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(handleTapPromotionView:)];
    [self addGestureRecognizer:tap];
    [tap release];

    NESceneManager_shared();
    if (g_IsPadDisplay) {
        self.layer.cornerRadius = 8.0f;
        self.layer.borderColor = [UIColor colorWithWhite:0.561f alpha:1.0f].CGColor;
        self.layer.borderWidth = 1.5f;
        self.clipsToBounds = YES;
    }
}

// @ 0x79f28
- (void)setImageViewSize:(CGSize)size {
    m_FrontImageView.frame = CGRectMake(0, 0, size.width, size.height);
    m_NextImageView.frame = CGRectMake(0, 0, size.width, size.height);
}

// @ 0x7a008 — kick off a download per promo entry (once).
- (void)setImageURLs:(NSArray *)promotionData {
    if (m_PromotionDataArray != nil || promotionData == nil) {
        return;
    }
    m_PromotionDataArray = [[NSMutableArray alloc] initWithArray:promotionData];
    m_Index = -1;

    NSUInteger i = 0;
    for (NSDictionary *entry in m_PromotionDataArray) {
        ImageDownloader *downloader = [[ImageDownloader alloc] init];
        downloader.imageURL = entry[@"ImageURL"];
        downloader.indexPathInTableView = [NSIndexPath indexPathWithIndex:i];
        downloader.delegate = self;
        [m_ImageDownloader addObject:downloader];
        [downloader startDownload];
        [downloader release];
        i++;
    }
}

// @ 0x7a230 — stash a loaded image into its promo slot, drop the downloader.
- (void)imageDownloader:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    UIImage *image = [downloader getImage];
    NSUInteger index = [indexPath indexAtPosition:0];
    [self setImage:image Index:(int)index];
    [m_ImageDownloader removeObject:downloader];
}

// @ 0x7a4b4 — record the image; if this is the first, show it and start rotating.
- (void)setImage:(UIImage *)image Index:(int)index {
    NSDictionary *entry = m_PromotionDataArray[index];
    NSDictionary *updated = [NSDictionary dictionaryWithObjectsAndKeys:
                             entry[@"ID"], @"ID",
                             entry[@"ImageURL"], @"ImageURL",
                             image, @"image", nil];
    [m_PromotionDataArray replaceObjectAtIndex:index withObject:updated];

    if (m_Index < 0) {
        m_Index = index;
        m_FrontImageView.hidden = NO;
        m_FrontImageView.image = m_PromotionDataArray[m_Index][@"image"];
    }
    m_Indicator.hidden = YES;
    [self startAnimation];
}

// @ 0x7a2c4
- (int)getImageCount {
    return (int)m_PromotionDataArray.count;
}

// @ 0x7a2e4 — advance to the next promo that has a loaded image, cross-fading it in.
- (void)setNext {
    int count = [self getImageCount];
    if (count <= 0) {
        return;
    }
    int candidate = m_Index;
    do {
        candidate++;
        if (candidate >= [self getImageCount]) {
            candidate = 0;
        }
        if (candidate < 0) {
            candidate = 0;
        }
        UIImage *image = m_PromotionDataArray[candidate][@"image"];
        if (image != nil) {
            m_Index = candidate;
            m_NextImageView.image = image;
            [UIView beginAnimations:@"Store_Promotion_Next" context:NULL];
            [UIView setAnimationDelegate:self];
            [UIView setAnimationDidStopSelector:@selector(nextShowEnd)];
            [UIView setAnimationDuration:0.75];
            m_NextImageView.alpha = 1.0f;
            [UIView commitAnimations];
            return;
        }
    } while (candidate != m_Index);
}

// @ 0x7a454 — the fade finished: promote next -> front, reset next to invisible.
- (void)nextShowEnd {
    m_FrontImageView.image = m_NextImageView.image;
    m_NextImageView.alpha = 0.0f;
}

// @ 0x7a628 — (re)arm the 2.5s rotation timer if there is a current image.
- (void)startAnimation {
    [self stopAnimation];
    if (m_Index >= 0) {
        m_Timer = [NSTimer scheduledTimerWithTimeInterval:2.5
                                                   target:self
                                                 selector:@selector(setNext)
                                                 userInfo:nil
                                                  repeats:YES];
    }
}

// @ 0x7a6ac
- (void)stopAnimation {
    if (m_Timer != nil) {
        [m_Timer invalidate];
        m_Timer = nil;
    }
}

// @ 0x79f84 — the current promo's pack id (or -1 when nothing is shown).
- (int)getPackID {
    int count = [self getImageCount];
    if (m_Index >= 0 && m_Index < count) {
        id idValue = m_PromotionDataArray[m_Index][@"ID"];
        if (idValue != nil) {
            return [idValue intValue];
        }
    }
    return -1;
}

// @ 0x7a6dc
- (void)handleTapPromotionView:(UITapGestureRecognizer *)recognizer {
    if (m_Delegate == nil) {
        return;
    }
    [m_Delegate storePromotionViewTaped:self PackID:[self getPackID]];
}

// @ 0x79af8 — drop all in-flight downloads and stop rotating.
- (void)cancel {
    for (ImageDownloader *downloader in m_ImageDownloader) {
        downloader.delegate = nil;
        [downloader cancelDownload];
    }
    [m_ImageDownloader release];
    m_ImageDownloader = nil;
    [self stopAnimation];
}

// @ 0x79994
- (void)dealloc {
    [m_Indicator release];
    for (ImageDownloader *downloader in m_ImageDownloader) {
        downloader.delegate = nil;
        [downloader cancelDownload];
    }
    [m_ImageDownloader release];
    [m_PromotionDataArray release];
    [super dealloc];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
