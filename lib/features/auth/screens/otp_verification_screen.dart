import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_providers.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  String _otp = '';
  bool _isLoading = false;
  bool _isResending = false;
  int _remainingSeconds = 60;
  Timer? _timer;
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _initSmsAutoFill();
    // Auto-focus on OTP input when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _initSmsAutoFill() async {
    // Listen for incoming SMS with specific pattern
    try {
      final signature = await _getAppSignature();
      //('App signature: $signature');
    } catch (e) {
      //('Error getting app signature: $e');
    }
  }

  Future<String> _getAppSignature() async {
    // This would typically get your app's SMS signature
    // For now, we'll use a placeholder
    return 'Your-App-Signature';
  }

  void _startResendTimer() {
    setState(() {
      _remainingSeconds = 60;
    });
    
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (_otp.length == 6) {
      setState(() {
        _isLoading = true;
      });

      try {
        final authService = ref.read(authServiceProvider);
        await authService.verifyPhoneOtpAndSignIn(
          phoneNumber: widget.phoneNumber,
          otp: _otp,
        );

        if (mounted) {
          // Invalidate auth providers to trigger updates
          ref.invalidate(isAuthenticatedProvider);
          ref.invalidate(currentUserProvider);
          ref.invalidate(isOnboardingCompletedProvider);

          // Wait a moment for providers to update
          await Future.delayed(const Duration(milliseconds: 100));

          if (mounted) {
            // Navigate to splash screen which will handle the routing based on auth state
            context.go(AppConstants.splashRoute);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
    }
  }

  Future<void> _resendOtp() async {
    if (_remainingSeconds == 0 && !_isResending) {
      setState(() {
        _isResending = true;
      });

      try {
        final authService = ref.read(authServiceProvider);
        await authService.signInWithPhone(widget.phoneNumber);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP resent successfully')),
          );
          // Clear the OTP field and restart timer
          _otpController.clear();
          setState(() {
            _otp = '';
          });
          _startResendTimer();
          // Re-initialize SMS auto-fill for new OTP
          _initSmsAutoFill();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to resend OTP: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isResending = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                        MediaQuery.of(context).viewInsets.bottom - 
                        MediaQuery.of(context).viewPadding.top - 48,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  
                  // OTP Illustration with decorative elements
                  if (MediaQuery.of(context).viewInsets.bottom == 0) ...[
                    SizedBox(
                      height: 200,
                      width: 200,
                     
                      child: Image.asset(
                        'assets/images/otp_hand.png',
                        height: 120,
                        width: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ] else ...[
                    const SizedBox(height: 20),
                  ],
                  
                  // Timer Display
                  Text(
                    '00:${_remainingSeconds.toString().padLeft(2, '0')} seconds',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryColor,
                      fontFamily: 'Okra',
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // OTP Input Fields
                  Pinput(
                    controller: _otpController,
                    focusNode: _focusNode,
                    length: 6,
                    defaultPinTheme: PinTheme(
                      width: 50,
                      height: 50,
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                    ),
                    focusedPinTheme: PinTheme(
                      width: 50,
                      height: 50,
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryColor, width: 2),
                      ),
                    ),
                    submittedPinTheme: PinTheme(
                      width: 50,
                      height: 50,
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryColor),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _otp = value;
                      });
                    },
                    onCompleted: (value) {
                      setState(() {
                        _otp = value;
                      });
                      _verifyOtp();
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    keyboardType: TextInputType.number,
                    hapticFeedbackType: HapticFeedbackType.lightImpact,
                    cursor: Container(
                      height: 20,
                      width: 2,
                      color: AppTheme.primaryColor,
                    ),
                    showCursor: true,
                    pinAnimationType: PinAnimationType.fade,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Resend Text
                  GestureDetector(
                    onTap: _resendOtp,
                    child: Text(
                      _remainingSeconds > 0 ? 'Resend OTP' : 'Resend OTP',
                      style: TextStyle(
                        fontSize: 14,
                        color: _remainingSeconds > 0
                            ? Colors.grey[600]
                            : AppTheme.primaryColor,
                        fontFamily: 'Okra',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  if (_isResending)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  
                  const Spacer(),
                  
                  // Verify Button
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 16 : 32,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading || _otp.length != 6 ? null : _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Verify & Proceed',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Okra',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward, size: 20),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 