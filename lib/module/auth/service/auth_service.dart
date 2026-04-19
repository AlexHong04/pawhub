import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/biometric_session_service.dart';
import '../../../core/utils/current_user_store.dart';
import '../../../core/utils/generatorId.dart';
import 'package:pawhub/module/Profile/service/profile_service.dart';
import '../model/auth_model.dart';

class AuthService {
	// Shared Supabase client used by all auth operations.
	static final supabase = Supabase.instance.client;
	static String? lastError;
	static const String _oauthRedirectScheme = 'com.pawhub.pawhub';
	static const String _oauthRedirectHost = 'login-callback';

	static String? get _oauthRedirectTo => kIsWeb ? null : '$_oauthRedirectScheme://$_oauthRedirectHost';

	static Future<AuthModel?> login(
		String email,
		String password, {
		bool persistLocal = true,
		bool syncDatabase = true,
	}) async {
		try {
			lastError = null;
			// Sign in against auth.users first.
			final response = await supabase.auth.signInWithPassword(
				email: email,
				password: password,
			);

			if (response.session != null && response.user != null) {
				final authModel = await _resolveOrCreateProfileForAuthUser(
					response.user!,
					fallbackEmail: response.user!.email ?? email,
				);

				if (authModel != null) {
					if (syncDatabase) {
						await _syncLoginToDatabase(response.user!.id, email: response.user!.email);
					}
					if (persistLocal) {
						await CurrentUserStore.save(authModel);
						await BiometricSessionService.saveCurrentSession();
					}
					return authModel;
				}

				// If profile sync fails, fallback to local cache for offline continuity.
				try {
					return await CurrentUserStore.read();
				} catch (cacheError) {
					print('Failed to read local cache after login: $cacheError');
				}
			}

			return null;
		} catch (e) {
			print('login error: $e');
			return null;
		}
	}

	static Future<AuthModel?> loginWithGoogle({
		bool persistLocal = true,
		bool syncDatabase = true,
	}) async {
		lastError = null;

		try {
			final launched = await supabase.auth.signInWithOAuth(
				OAuthProvider.google,
				redirectTo: _oauthRedirectTo,
				authScreenLaunchMode: LaunchMode.externalApplication,
			);

			if (!launched) {
				lastError = 'Unable to open Google sign-in screen.';
				return null;
			}

			final authUser = await _waitForAuthenticatedUser();
			if (authUser == null) {
				lastError =
						'Google sign-in was cancelled or timed out. Please try again.';
				return null;
			}

			final authModel = await _resolveOrCreateProfileForAuthUser(
				authUser,
				fallbackEmail: authUser.email,
				fallbackName: _extractDisplayName(authUser),
			);

			if (authModel == null) {
				return null;
			}

			if (authModel.role == 'Admin') {
				lastError =
						'Google login is only available for User accounts. Please use email login for staff.';
				await supabase.auth.signOut();
				return null;
			}

			if (syncDatabase) {
				await _syncLoginToDatabase(authUser.id, email: authUser.email);
			}
			if (persistLocal) {
				await CurrentUserStore.save(authModel);
				await BiometricSessionService.saveCurrentSession();
			}

			return authModel;
		} on AuthException catch (e) {
			lastError = e.message;
			print('loginWithGoogle auth error: ${e.message}');
			return null;
		} catch (e) {
			lastError = e.toString();
			print('loginWithGoogle error: $e');
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
		final normalizedEmail = email.trim().toLowerCase();

		try {
			if (normalizedEmail.isEmpty) {
				lastError = 'Email is required.';
				return null;
			}

			final exists = await _isEmailAlreadyRegistered(normalizedEmail);
			if (exists) {
				lastError = _duplicateEmailMessage;
				return null;
			}

			// create the user in auth.users.
			final response = await supabase.auth.signUp(
				email: normalizedEmail,
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
			await supabase
					.from('User')
					.update({
						'email': normalizedEmail,
						'updated_at': DateTime.now().toIso8601String(),
					})
					.eq('auth_id', authUserId);

			existingUser['email'] = normalizedEmail;
			final authModel = AuthModel.fromJson(existingUser);
			await CurrentUserStore.save(authModel);
			await BiometricSessionService.saveCurrentSession();
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
						'last_seen': DateTime.now().toIso8601String(),
						'is_banned': false,
						'is_volunteer': false,
						'avatar_url': null,
						'email': normalizedEmail,
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
			userData['email'] = normalizedEmail;
			final authModel = AuthModel.fromJson(userData);
			await CurrentUserStore.save(authModel);
			await BiometricSessionService.saveCurrentSession();
			return authModel;
		} else {
			lastError = 'server error, please try again。';
			return null;
		}

		} on AuthException catch (e, stackTrace) {
			lastError = _isDuplicateEmailError(e.message) ? _duplicateEmailMessage : e.message;
			// Auth-layer errors such as duplicate email or signup restrictions.
			print('register auth error: ${e.message}');
			print('register auth stackTrace: $stackTrace');
			return null;
		} on PostgrestException catch (e, stackTrace) {
			lastError = _isDuplicateEmailError(e.message) ? _duplicateEmailMessage : e.message;
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

	static const String _duplicateEmailMessage =
			'This email is already registered. Please use another email or login.';

	static bool _isDuplicateEmailError(String? message) {
		final text = (message ?? '').toLowerCase();
		return text.contains('already registered') ||
				text.contains('already been registered') ||
				text.contains('duplicate') ||
				text.contains('unique') ||
				text.contains('email_exists') ||
				text.contains('user already registered');
	}

	static Future<bool> _isEmailAlreadyRegistered(String normalizedEmail) async {
		try {
			final existing = await supabase
					.from('User')
					.select('auth_id')
					.ilike('email', normalizedEmail)
					.maybeSingle();
			return existing != null;
		} on PostgrestException catch (e) {
			print('register pre-check warning: ${e.message}');
			return false;
		} catch (e) {
			print('register pre-check warning: $e');
			return false;
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

	static Future<AuthModel?> resolveCurrentUserFromActiveSession({
		bool persistLocal = true,
	}) async {
		final authUser = supabase.auth.currentUser;
		if (authUser == null) return null;

		final authModel = await _resolveOrCreateProfileForAuthUser(
			authUser,
			fallbackEmail: authUser.email,
			fallbackName: _extractDisplayName(authUser),
		);

		if (authModel != null && persistLocal) {
			await CurrentUserStore.save(authModel);
		}

		return authModel;
	}

	static Future<void> lockApp() async {
		// Soft lock: keep Supabase session and biometric token, clear only cached profile.
		await CurrentUserStore.clear();
	}

	static Future<void> logout() async {
		// End the current Supabase session and clear local cached user.
		try {
			final userId = supabase.auth.currentUser?.id;
			if (userId != null) {
				final updated = await ProfileService.updateOnlineStatus(userId, 'Offline');
				if (!updated) {
					print('logout: failed to set Offline for auth_id=$userId');
				}
			}
			await supabase.auth.signOut();
		} finally {
			await CurrentUserStore.clear();
			await BiometricSessionService.clear();
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
				await BiometricSessionService.clear();
				onSignedOut();
			}
		});
	}

	static Future<void> _syncLoginToDatabase(String authId, {String? email}) async {
		try {
			final updates = <String, dynamic>{};
			if (email != null && email.trim().isNotEmpty) {
				updates['email'] = email.trim();
			}

			final updated = await ProfileService.updateOnlineStatus(authId, 'Online');
			if (!updated) {
				print('sync login status warning: failed to set Online for auth_id=$authId');
			}

			if (updates.isNotEmpty) {
				await supabase.from('User').update(updates).eq('auth_id', authId);
			}
		} catch (e) {
			// Keep login successful even if this non-critical sync fails.
			print('sync login status error: $e');
		}
	}

	static Future<User?> _waitForAuthenticatedUser({
		Duration timeout = const Duration(seconds: 90),
	}) async {
		final current = supabase.auth.currentUser;
		if (current != null) return current;

		final completer = Completer<User?>();
		late final StreamSubscription<AuthState> subscription;

		subscription = supabase.auth.onAuthStateChange.listen((data) {
			final user = data.session?.user ?? supabase.auth.currentUser;
			if (user != null && !completer.isCompleted) {
				completer.complete(user);
			}
		});

		try {
			return await completer.future.timeout(timeout);
		} on TimeoutException {
			return supabase.auth.currentUser;
		} finally {
			await subscription.cancel();
		}
	}

	static String _extractDisplayName(User user) {
		final metadata = user.userMetadata ?? const <String, dynamic>{};
		final possibleNames = <String?>[
			metadata['full_name']?.toString(),
			metadata['name']?.toString(),
			metadata['given_name']?.toString(),
			user.email?.split('@').first,
		];

		for (final candidate in possibleNames) {
			if (candidate != null && candidate.trim().isNotEmpty) {
				return candidate.trim();
			}
		}

		return 'User';
	}

	static Future<AuthModel?> _resolveOrCreateProfileForAuthUser(
		User authUser, {
		String? fallbackEmail,
		String? fallbackName,
	}) async {
		try {
			Map<String, dynamic>? userData = await supabase
					.from('User')
					.select()
					.eq('auth_id', authUser.id)
					.maybeSingle();

			if (userData == null) {
				userData = await _createUserProfileForAuthUser(
					authUser,
					email: (fallbackEmail ?? authUser.email ?? '').trim(),
					name: (fallbackName ?? _extractDisplayName(authUser)).trim(),
				);
			}

			if (userData == null) {
				lastError = 'Unable to create profile for this account.';
				return null;
			}

			if ((userData['is_banned'] ?? false) == true) {
				lastError = 'Your account has been banned. Please contact support.';
				await supabase.auth.signOut();
				return null;
			}

			final existingEmail = (userData['email'] ?? '').toString().trim();
			final resolvedEmail = existingEmail.isNotEmpty
					? existingEmail
					: (fallbackEmail ?? authUser.email ?? '').trim();

			if (resolvedEmail.isNotEmpty && existingEmail != resolvedEmail) {
				await supabase
						.from('User')
						.update({
							'email': resolvedEmail,
							'updated_at': DateTime.now().toIso8601String(),
						})
						.eq('auth_id', authUser.id);
				userData['email'] = resolvedEmail;
			} else {
				userData['email'] = resolvedEmail;
			}

			return AuthModel.fromJson(userData);
		} on PostgrestException catch (e) {
			lastError = e.message;
			print('resolve profile error: ${e.message}');
			return null;
		} catch (e) {
			lastError = e.toString();
			print('resolve profile error: $e');
			return null;
		}
	}

	static Future<Map<String, dynamic>?> _createUserProfileForAuthUser(
		User authUser, {
		required String email,
		required String name,
	}) async {
		const maxRetries = 3;

		for (int i = 0; i < maxRetries; i++) {
			try {
				final newUserId = await GeneratorId.generateId(
					tableName: 'User',
					idColumnName: 'user_id',
					prefix: 'U',
					numberLength: 5,
				);

				final now = DateTime.now().toIso8601String();
				final created = await supabase
						.from('User')
						.insert({
							'user_id': newUserId,
							'name': name.isEmpty ? 'User' : name,
							'gender': '',
							'contact': '',
							'address': '',
							'role': 'User',
							'online_status': 'Online',
							'last_seen': now,
							'updated_at': now,
							'is_banned': false,
							'is_volunteer': false,
							'avatar_url': null,
							'email': email,
							'auth_id': authUser.id,
						})
						.select()
						.single();

				return created;
			} on PostgrestException catch (e) {
				final isDuplicate = e.code == '23505' ||
						e.message.toLowerCase().contains('duplicate') ||
						e.message.toLowerCase().contains('unique');

				if (isDuplicate && i < maxRetries - 1) {
					continue;
				}
				rethrow;
			}
		}

		return null;
	}
}
