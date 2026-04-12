import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/generatorId.dart';
import '../model/auth_model.dart';

class AuthService {
	// Shared Supabase client used by all auth operations.
	static final supabase = Supabase.instance.client;
	static String? lastError;

	static Future<AuthModel?> login(String email, String password) async {
		try {
			// Sign in against auth.users first.
			final response = await supabase.auth.signInWithPassword(
				email: email,
				password: password,
			);

			if (response.session != null && response.user != null) {
				// Load the app profile row linked by auth_id.
				final userData = await supabase
						.from('User')
						.select()
						.eq('auth_id', response.user!.id)
						.single();

				return AuthModel.fromJson(userData);
			}

			return null;
		} catch (e) {
			print('login error: $e');
			return null;
		}
	}

	static Future<AuthModel?> register(
			String name,
			String email,
			String password,
			String gender,
			) async {
		lastError = null;

		try {
			// create the user in auth.users.
			final response = await supabase.auth.signUp(
				email: email,
				password: password,
			);

			final authUserId = response.user?.id;
			if (authUserId == null) {
				lastError = 'Sign up did not return a user id. Try login if account already exists.';
				return null;
			}

			// check whether the profile already exists for this auth user.
			final existingUser = await supabase
					.from('User')
					.select()
					.eq('auth_id', authUserId)
					.maybeSingle();

			if (existingUser != null) {
				return AuthModel.fromJson(existingUser);
			}

			// create the public.User profile row linked by auth_id.
			int maxRetries = 3;
			Map<String, dynamic>? userData;

			for (int i = 0; i < maxRetries; i++) {
				try {
					final newUserId = await GeneratorId.generateId(
						tableName: 'User',
						idColumnName: 'user_id',
						prefix: 'U',
						numberLength: 5,
					);

					userData = await supabase
							.from('User')
							.insert({
						'user_id': newUserId,
						'name': name,
						'gender': gender,
						'contact': '',
						'address': '',
						'role': 'User',
						'online_status': 'Online',
						'is_volunteer': false,
						'avatar_url': null,
						'auth_id': authUserId,
					})
							.select()
							.single();
					break;
				} on PostgrestException catch (e) {
					// Duplicate Key / Unique Constraint Violation
					// PostgreSQL  unique violation normal 23505
					if (e.code == '23505' || e.message.toLowerCase().contains('duplicate') || e.message.toLowerCase().contains('unique')) {
						print(' Duplicate Key, in  ${i + 1} please try again...');

						if (i == maxRetries - 1) {
							throw e;
						}
					} else {
						throw e;
					}
				}
			}

			if (userData != null) {
				return AuthModel.fromJson(userData);
			} else {
				lastError = 'server error, please try again。';
				return null;
			}

		} on AuthException catch (e, stackTrace) {
			lastError = e.message;
			// Auth-layer errors such as duplicate email or signup restrictions.
			print('register auth error: ${e.message}');
			print('register auth stackTrace: $stackTrace');
			return null;
		} on PostgrestException catch (e, stackTrace) {
			lastError = e.message;
			print('register database error: ${e.message}');
			print('register database stackTrace: $stackTrace');
			return null;
		} catch (e, stackTrace) {
			lastError = e.toString();
			// Fallback for any unexpected runtime error.
			print('register error: $e');
			print('register stackTrace: $stackTrace');
			return null;
		}
	}

	static Future<bool> sendOtp(String email) async {
		try {
			// Send a recovery/login OTP without creating a new account.
			await supabase.auth.resetPasswordForEmail(email);
			return true;
		} catch (e) {
			print('sendOtp error: $e');
			return false;
		}
	}

	static Future<bool> verifyOtp(String email, String otp) async {
		lastError = null;
		try {
			// Verify the recovery OTP.
			final response = await supabase.auth.verifyOTP(
				email: email,
				token: otp,
				type: OtpType.recovery,
			);
			// Some environments attach session to currentSession instead of response.
			final hasSession = response.session != null || supabase.auth.currentSession != null;

			if (!hasSession) {
				lastError ='OTP verified but no recovery session was created. Check Supabase recovery email template and auth settings.';
			}

			return hasSession;
		} on AuthException catch (e) {
			lastError = e.message;
			print('verifyOtp auth error: ${e.message}');
			return false;

		} catch (e) {
			lastError = e.toString();
			print('verifyOtp general error: $e');
			return false;
		}
	}

	static Future<bool> updatePassword(String newPassword) async {
		try {
			// Update the currently signed-in user's password.
			await supabase.auth.updateUser(UserAttributes(password: newPassword));
			return true;
		} catch (e) {
			print('updatePassword error: $e');
			return false;
		}
	}

	static Future<void> logout() async {
		// End the current Supabase session.
		await supabase.auth.signOut();
	}

	static bool isLoggedIn() {
		// Simple session check for UI guards.
		return supabase.auth.currentSession != null;
	}

	static void listenToAuthChanges(Function onSignedOut) {
		// Trigger a callback whenever the user signs out.
		supabase.auth.onAuthStateChange.listen((data) {
			if (data.event == AuthChangeEvent.signedOut) {
				onSignedOut();
			}
		});
	}
}
