//
//  PasswordInputViewController.m
//  Wallet
//
//  All rights reserved.
//

#import "PasswordInputViewController.h"

#import "Language.h"
#import "WalletMgr.h"
#import "WindowManager.h"
#import "UIViewController+Alert.h"
#import "VColor.h"
#import "VStoryboard.h"
#import "AlertViewController.h"

@interface PasswordInputViewController ()

@property (nonatomic, strong) void(^resultBlock)(BOOL);

@property (weak, nonatomic) IBOutlet UILabel *pageTitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *pageSubtitleLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *vsysLogoTop;

@property (weak, nonatomic) IBOutlet UITextField *pwdTextField;
@property (weak, nonatomic) IBOutlet UIButton *enterBtn;
@property (nonatomic, strong) PasswordInputModel *model;

@end

@implementation PasswordInputViewController

- (instancetype)initWithModel:(PasswordInputModel *)model result:(void(^ __nullable)(BOOL success))result {
    self = [VStoryboard.Wallet instantiateViewControllerWithIdentifier:@"PasswordInputViewController"];
    self.resultBlock = result;
    self.model = model;
    self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initView];
}

- (void)initView {
    
    self.pageTitleLabel.text = self.model.title;
    self.pageSubtitleLabel.text = self.model.titleDetail;
    
    self.pwdTextField.placeholder = VLocalize(@"input_password");
}

- (void)closeBtnClick {
    [self.view endEditing:YES];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardHide:) name:UIKeyboardWillHideNotification object:nil];
    [self.pwdTextField becomeFirstResponder];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

- (IBAction)pwdTextFieldEditingChanged {
    _enterBtn.enabled = self.pwdTextField.text.length > 0;
    if(_enterBtn.enabled){
        self.enterBtn.tintColor = VColor.orangeColor;
    }
}

- (IBAction)submit {
    [self.view endEditing:YES];
    NSError *error = [WalletMgr.shareInstance loadWallet:_pwdTextField.text];
    if (!error) {
        if (_resultBlock) {
            _resultBlock(YES);
        } else {
            [WindowManager changeToRootViewController:VStoryboard.Main.instantiateInitialViewController];
        }
    } else {
        __weak typeof(self) weakSelf = self;
        if (_resultBlock) {
            _resultBlock(NO);
            [self alertWithTitle:VLocalize(@"incorrect_password_tip_title") confirmText:VLocalize(@"re_input") handler:^{
                [weakSelf.pwdTextField becomeFirstResponder];
            }];
        } else {
            AlertViewController *pwdErrorAlert = [[AlertViewController alloc] initWithTitle:VLocalize(@"incorrect_password_tip_title") secondTitle:@"" contentView:^(UIStackView * _Nonnull view) {
                
            } cancelTitle:VLocalize(@"settings_logout_wallet") confirmTitle:VLocalize(@"re_input") cancel:^{
                AlertViewController *vc = [[AlertViewController alloc] initWithTitle:VLocalize(@"logout_tip_title") secondTitle:VLocalize(@"logout_tip_detail") contentView:nil cancelTitle:VLocalize(@"cancel") confirmTitle:VLocalize(@"logout_confirm") cancel:^{
                    [weakSelf.pwdTextField becomeFirstResponder];
                } confirm:^{
                    [[WalletMgr shareInstance] logoutWithoutDeleteWallet];
                    [WindowManager changeToRootViewController:VStoryboard.Generate.instantiateInitialViewController];
                }];
                [weakSelf presentViewController:vc animated:YES completion:nil];
            } confirm:^{
                [weakSelf.pwdTextField becomeFirstResponder];
            }];
            [self presentViewController:pwdErrorAlert animated:YES completion:nil];
        }
    }
}

#pragma mark - keyboard
- (void)keyboardShow:(NSNotification *)notification {
    CGFloat keyboardMinY = CGRectGetMinY([notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue]);
    CGFloat inputViewMaxY = CGRectGetMaxY([self.inputView convertRect:self.inputView.bounds toView:UIApplication.sharedApplication.keyWindow]);
    // 100: distance between logo and top when keyboard hidden
    // 52: max distance between logo and top when keyboard show
    CGFloat offset = MAX((100 - 52), (inputViewMaxY + 20 - keyboardMinY));
    
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewKeyframeAnimationOptions option = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] intValue];
    __weak typeof(self) weakSelf = self;
    [UIView animateKeyframesWithDuration:duration delay:0 options:option animations:^{
        weakSelf.vsysLogoTop.constant = 100 - offset;
        [weakSelf.view layoutIfNeeded];
    } completion:nil];
}

- (void)keyboardHide:(NSNotification *)notification {
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewKeyframeAnimationOptions option = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] intValue];
    __weak typeof(self) weakSelf = self;
    [UIView animateKeyframesWithDuration:duration delay:0 options:option animations:^{
        weakSelf.vsysLogoTop.constant = 100;
        [weakSelf.view layoutIfNeeded];
    } completion:nil];
}

@end
