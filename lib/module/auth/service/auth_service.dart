import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/current_user_store.dart';
import '../../../core/utils/generatorId.dart';
import '../model/auth_model.dart';

class AuthService {
	// Shared Supabase client used by all auth operations.
	static final supabase = Supabase.instance.client;
	static String? lastError;

	static Future<AuthModel?> login(
		String email,
		String password, {
		bool persistLocal = true,
		bool syncDatabase = true,
	}) async {
		try {
			// Sign in against auth.users first.
			final response = await supabase.auth.signInWithPassword(
				email: email,
				password: password,
			);

			if (response.session != null && response.user != null) {
				AuthModel? authModel;

				// Try to load profile from Supabase (primary source)
				try {
					final userData = await supabase
							.from('User')
							.select()
							.eq('auth_id', response.user!.id)
							.single();

					// The User table may not store email, so keep auth email in the model.
					userData['email'] = response.user!.email ?? email;
					authModel = AuthModel.fromJson(userData);
				} catch (supabseError) {
					print('Failed to fetch profile from Supabase, falling back to local cache: $supabseError');

					// If Supabase profile fetch fails, fallback to local cache
					try {
						authModel = await CurrentUserStore.read();
					} catch (cacheError) {
						print('Also failed to read local cache: $cacheError');
					}
				}

				if (authModel != null) {
					if (syncDatabase) {
						await _syncLoginToDatabase(response.user!.id);
					}
					if (persistLocal) {
						await CurrentUserStore.save(authModel);
					}
					return authModel;
				}
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
			Map<String, dynamic>? existingUser;
			try {
				existingUser = await supabase
						.from('User')
						.select()
						.eq('auth_id', authUserId)
						.maybeSingle();
			} catch (e) {
				print('Failed to check existing user from Supabase: $e');
				// Continue anyway - existing user might be null
			}

		if (existingUser != null) {
			existingUser['email'] = email;
			final authModel = AuthModel.fromJson(existingUser);
			return authModel;
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
			userData['email'] = email;
			final authModel = AuthModel.fromJson(userData);
			return authModel;
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

	static Future<AuthModel?> getStoredCurrentUser() async {
		return CurrentUserStore.read();
	}

	static Future<void> logout() async {
		// End the current Supabase session and clear local cached user.
		try {
			await supabase.auth.signOut();
		} finally {
			await CurrentUserStore.clear();
		}
	}

	static bool isLoggedIn() {
		// Simple session check for UI guards.
		return supabase.auth.currentSession != null;
	}

	static void listenToAuthChanges(Function onSignedOut) {
		// Trigger a callback whenever the user signs out.
		supabase.auth.onAuthStateChange.listen((data) async {
			if (data.event == AuthChangeEvent.signedOut) {
				await CurrentUserStore.clear();
				onSignedOut();
			}
		});
	}

	static Future<void> _syncLoginToDatabase(String authId) async {
		try {
			await supabase.from('User').update({
				'online_status': 'Online',
				'updated_at': DateTime.now().toIso8601String(),
			}).eq('auth_id', authId);
		} catch (e) {
			// Keep login successful even if this non-critical sync fails.
			print('sync login status error: $e');
		}
	}
}
