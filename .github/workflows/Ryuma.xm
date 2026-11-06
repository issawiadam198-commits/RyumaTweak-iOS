
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <dlfcn.h>

@interface RyumaLoginView : UIView
@property(nonatomic,strong) UITextField *keyField;
@property(nonatomic,strong) UIButton *loginButton;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,assign) BOOL checking;
@end

static NSString *RyumaSHA256(NSString *path) {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return @"";

    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);

    NSMutableString *result = [NSMutableString string];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++)
        [result appendFormat:@"%02x", digest[i]];

    return result;
}

static NSString *RyumaGetDylibPath(void) {
    Dl_info info;
    if (dladdr((const void *)&RyumaGetDylibPath, &info) && info.dli_fname)
        return [NSString stringWithUTF8String:info.dli_fname];
    return @"";
}

@implementation RyumaLoginView

- (instancetype)init {
    self = [super initWithFrame:UIScreen.mainScreen.bounds];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.03 alpha:0.98];

        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 210, self.bounds.size.width-40, 55)];
        title.text = @"Ryuma";
        title.textColor = UIColor.whiteColor;
        title.font = [UIFont boldSystemFontOfSize:34];
        title.textAlignment = NSTextAlignmentCenter;
        [self addSubview:title];

        self.keyField = [[UITextField alloc] initWithFrame:CGRectMake(35, 285, self.bounds.size.width-70, 50)];
        self.keyField.placeholder = @"Enter key";
        self.keyField.textColor = UIColor.whiteColor;
        self.keyField.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
        self.keyField.layer.cornerRadius = 10;
        self.keyField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,12,1)];
        self.keyField.leftViewMode = UITextFieldViewModeAlways;
        self.keyField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.keyField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        [self addSubview:self.keyField];

        self.loginButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.loginButton.frame = CGRectMake(35, 355, self.bounds.size.width-70, 50);
        [self.loginButton setTitle:@"Login" forState:UIControlStateNormal];
        [self.loginButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        self.loginButton.backgroundColor = [UIColor colorWithRed:0.15 green:0.35 blue:0.85 alpha:1];
        self.loginButton.layer.cornerRadius = 10;
        [self.loginButton addTarget:self action:@selector(checkKey) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.loginButton];

        self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 420, self.bounds.size.width-40, 50)];
        self.statusLabel.textColor = UIColor.whiteColor;
        self.statusLabel.textAlignment = NSTextAlignmentCenter;
        self.statusLabel.numberOfLines = 2;
        [self addSubview:self.statusLabel];
    }
    return self;
}

- (void)checkKey {
    if (self.checking) return;

    NSString *key = [self.keyField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (key.length == 0) {
        self.statusLabel.text = @"Please enter your key";
        return;
    }

    NSString *hash = RyumaSHA256(RyumaGetDylibPath());
    if (hash.length == 0) {
        self.statusLabel.text = @"Unable to verify file";
        return;
    }

    self.checking = YES;
    self.loginButton.enabled = NO;
    [self.loginButton setTitle:@"Checking..." forState:UIControlStateNormal];
    self.statusLabel.text = @"Connecting to server...";

    NSURL *url = [NSURL URLWithString:@"https://ryuma-verify.ieuhehhehehehhrh.workers.dev"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 12;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSDictionary *body = @{@"key":key, @"hash":hash};
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.checking = NO;
            self.loginButton.enabled = YES;
            [self.loginButton setTitle:@"Login" forState:UIControlStateNormal];

            if (error || !data) {
                self.statusLabel.text = @"Connection failed. Try again.";
                return;
            }

            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            if (http.statusCode < 200 || http.statusCode >= 300) {
                self.statusLabel.text = @"Server error. Try again.";
                return;
            }

            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([json[@"valid"] boolValue]) {
                [self removeFromSuperview];
            } else {
                self.statusLabel.text = @"Invalid key or file verification failed";
            }
        });
    }] resume];
}
@end

static void RyumaShowLogin(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = nil;

        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
                    if (candidate.isKeyWindow) {
                        window = candidate;
                        break;
                    }
                }
            }
        }

        if (!window) return;

        RyumaLoginView *view = [[RyumaLoginView alloc] init];
        view.tag = 987654;
        [window addSubview:view];
    });
}

__attribute__((constructor))
static void RyumaInit(void) {
    RyumaShowLogin();
}
