# Upstream Fixes TODO

This document tracks issues that need to be fixed in Antragsgruen upstream to enable **true** environment-variable-only deployment without requiring any `config.json` file, and to fix bugs in the generic_sso OIDC plugin.

## Current Status (v4.17-volt)

The v4.17-volt tag adds environment variable support, but `config.json` is still required to exist (even if minimal). This defeats the purpose of 12-factor app deployment.

**Workaround**: The docker-entrypoint.sh automatically creates a minimal config.json with just `siteSubdomain` and `plugins` settings.

---

## Environment Configuration Issues

### 1. **CRITICAL: index.php requires config.json to exist**

**File**: `web/index.php`
**Line**: ~20-30 (config.json existence check)

**Problem**:
```php
if (!file_exists($configFile) && !file_exists($installFile)) {
    die('Antragsgrün is not configured yet. Please create the config/INSTALLING file...');
}
```

This check happens BEFORE the web.php code that handles environment variables. Even though `config/web.php` can gracefully handle missing config.json (by using `$config = '{}'`), the application never reaches that code.

**Solution Needed**:
Remove or update this check to allow missing config.json when environment variables are set. Suggested approach:
```php
// Allow missing config.json if environment variables are configured
$hasEnvConfig = !empty($_SERVER['RANDOM_SEED']) && !empty($_SERVER['DB_HOST']);
if (!file_exists($configFile) && !file_exists($installFile) && !$hasEnvConfig) {
    die('Antragsgrün is not configured yet...');
}
```

**Impact**: HIGH - This is the main blocker for true env-only deployment

---

### 2. **CRITICAL: No SITE_SUBDOMAIN environment variable for single-site mode**

**File**: `models/settings/AntragsgruenApp.php` (EnvironmentConfigLoader)
**Documentation**: `docs/environment-variables.md`

**Problem**:
In single-site mode, the application needs to know which site subdomain to use. Currently, this MUST be in config.json:
```json
{
  "multisiteMode": false,
  "siteSubdomain": "std"
}
```

There's no environment variable equivalent for `siteSubdomain`.

**Solution Needed**:
Add a `SITE_SUBDOMAIN` environment variable that works when `MULTISITE_MODE=false`:

```php
// In EnvironmentConfigLoader::parseConfig()
if (isset($_SERVER['SITE_SUBDOMAIN'])) {
    $config['siteSubdomain'] = $_SERVER['SITE_SUBDOMAIN'];
}
```

**Default behavior**: If not set in single-site mode, default to "std" or the first site in the database.

**Impact**: HIGH - Required for single-site deployments without config.json

---

### 3. **MEDIUM: Root URL fails in single-site mode with env-only config**

**File**: `controllers/Base.php`
**Line**: 603

**Problem**:
Accessing the root URL (/) in single-site mode throws an error:
```
Error: Attempt to read property "urlPath" on null in /var/www/html/controllers/Base.php:603
```

The consultation object is null when accessing root. Accessing the consultation directly (e.g., `/main`) works fine.

**Solution Needed**:
When in single-site mode and consultation is null at root URL, either:
1. Automatically redirect to the first/default consultation
2. Show a better landing page
3. Load the default consultation automatically

**Impact**: MEDIUM - Root URL should work, but users can access via consultation path

---

### 4. **LOW: Documentation unclear about config.json requirement**

**File**: `docs/environment-variables.md`

**Problem**:
The documentation states:
> "Environment variables are used as fallback only. Config.json values take precedence when present."

This doesn't clearly explain:
- Whether config.json is optional or required
- What minimal config.json is needed if any
- How to do a pure environment-variable deployment

**Solution Needed**:
Add a section like:
```markdown
## Pure Environment Variable Deployment

To deploy using only environment variables without config.json:
1. Set RANDOM_SEED, DB_HOST, DB_NAME, DB_USER, DB_PASSWORD (required)
2. Set SITE_SUBDOMAIN for single-site mode
3. Set other optional variables as needed
4. No config.json file is needed - the application will create one automatically or load from environment

Note: In v4.17-volt, a minimal config.json is still required due to legacy checks. This will be removed in a future version.
```

**Impact**: LOW - Documentation clarity, not a functional issue

---

### 5. **LOW: Inconsistent environment variable naming**

**File**: `models/settings/EnvironmentConfigLoader.php`

**Problem**:
Some settings have multiple env var names for the same purpose:
- `TABLE_PREFIX` and `DB_TABLE_PREFIX` both work
- This could cause confusion

**Solution Needed**:
Document which is the canonical name and deprecate aliases, or clearly document all aliases in the environment variables documentation.

**Impact**: LOW - Works but could be cleaner

---

## OIDC / Generic SSO Plugin Issues

### 6. **CRITICAL: `league/oauth2-client` not in composer require**

**File**: `composer.json`

**Problem**:
The `generic_sso` plugin uses `League\OAuth2\Client\Provider\GenericProvider` in `OidcProvider.php`, but `league/oauth2-client` is only listed in the `suggest` section of `composer.json`, not in `require`. A standard `composer install --no-dev` will not install it, so enabling the plugin causes:
```
Error: Class "League\OAuth2\Client\Provider\GenericProvider" not found
  in plugins/generic_sso/OidcProvider.php:34
```

**Solution Needed**:
Move `league/oauth2-client` from `suggest` to `require` (or at minimum `require` it conditionally when the plugin is enabled). Since the plugin ships with the codebase, its dependencies should be installable:
```json
{
  "require": {
    "league/oauth2-client": "^2.7"
  }
}
```

**Workaround**: Dockerfile runs `composer require league/oauth2-client` after the main install.

**Impact**: HIGH - Plugin is completely broken without this dependency

---

### 7. **HIGH: ExitException caught during OIDC redirect in LoginController**

**File**: `plugins/generic_sso/controllers/LoginController.php`
**Method**: `performLoginAndRedirect()`

**Problem**:
The method wraps the SSO login flow in a `catch (\Exception $e)` block. During the OIDC authorization redirect, the `SsoLogin::performLoginAndReturnUser()` method calls `\Yii::$app->end()` which throws a `\yii\base\ExitException` (extending `\Exception`) to cleanly terminate the request after sending the 302 redirect. The generic catch inadvertently catches this, treating a successful redirect as an error and showing a 500 error page instead.

**Solution Needed**:
Add an explicit catch for `ExitException` before the generic catch:
```php
try {
    $loginProvider = Module::getDedicatedLoginProvider();
    $loginProvider->performLoginAndReturnUser();
    // ...
} catch (\yii\base\ExitException $e) {
    throw $e;
} catch (\Exception $e) {
    \Yii::error('SSO Login Error: ' . $e->getMessage());
    // ...
}
```

**Workaround**: Dockerfile `sed` patch adds the `ExitException` catch clause.

**Impact**: HIGH - SSO login always fails without this fix

---

### 8. **HIGH: `OidcProvider` constructor expects `urlResourceOwnerDetails` but `generic_sso.json` config uses `urlUserInfo`**

**File**: `plugins/generic_sso/OidcProvider.php`
**Line**: 29

**Problem**:
The `OidcProvider` constructor passes `$config['urlResourceOwnerDetails']` to `GenericProvider`, but when generating config from environment variables or manual configuration, the natural key name is `urlUserInfo` (matching the OIDC spec's "userinfo_endpoint"). The `discover()` static method returns both keys, but anyone creating a `generic_sso.json` config file would naturally only include `urlUserInfo`, causing:
```
Undefined array key "urlResourceOwnerDetails"
```

The `league/oauth2-client` `GenericProvider` requires the key `urlResourceOwnerDetails` (its own naming convention), creating a naming mismatch between the OIDC standard terminology and the library's API.

**Solution Needed**:
Accept either key with a fallback in the constructor:
```php
'urlResourceOwnerDetails' => $config['urlResourceOwnerDetails'] ?? $config['urlUserInfo'] ?? '',
```

**Workaround**: Entrypoint generates both `urlUserInfo` and `urlResourceOwnerDetails` in the config file.

**Impact**: HIGH - SSO login fails with a 500 error without the workaround

---

### 9. **MEDIUM: `currentConsultationId` not set causes SSO callback crash**

**File**: `controllers/Base.php`
**Line**: 603

**Problem**:
When the `site` table has `currentConsultationId = NULL` (common on fresh installs where the site was created without setting it), any URL that resolves without an explicit `consultationPath` parameter crashes:
```
Attempt to read property "urlPath" on null in controllers/Base.php:603
```

This specifically affects the SSO callback URL (`/sso-callback`) which is registered at the domain root level (via `Module::getAllUrlRoutes()` using `$dom . 'sso-callback'`) and has no consultation path segment. The existing null-consultation handling at line 599 only checks for `UserController`, not plugin controllers.

The `loadConsultation()` method assumes `$this->site->currentConsultation` is always non-null when `$consultationId` is empty, which is incorrect.

**Solution Needed**:
Add a null check before accessing the property:
```php
if ($consultationId === '') {
    $consultationId = $this->site->currentConsultation
        ? $this->site->currentConsultation->urlPath
        : '';
}
```

And/or extend the `UserController` check at line 599 to also handle plugin controllers that extend `Base`.

**Workaround**: Entrypoint ensures `currentConsultationId` is set on fresh installs and auto-fixes existing sites. Dockerfile also patches `Base.php` as a safety net.

**Impact**: MEDIUM - Affects any controller route registered at the domain root without a consultation path prefix

---

### 10. **MEDIUM: SSO plugin does not link existing local accounts by email**

**File**: `plugins/generic_sso/SsoLogin.php`
**Method**: `getOrCreateUser()`

**Problem**:
When a user who already has a local account (e.g. `auth = email:jane@example.com`) logs in via SSO for the first time, the plugin only looks up users by the `auth` field (`generic-sso:<preferred_username>`). Since the existing local account has a different `auth` value, no match is found and a **new duplicate account** is created with the same email. The user's existing motions, amendments, and permissions remain on the old account.

If the database has a `UNIQUE` constraint on the `email` column, the `$user->save()` call will fail with an exception instead.

**Solution Needed**:
Add an optional email-based fallback when no auth match is found:
```php
$user = User::findOne(['auth' => $auth]);

if (!$user && !empty($userData['email'])) {
    $user = User::findOne(['email' => $userData['email']]);
    if ($user) {
        \Yii::info('SSO: Linking existing account ' . $userData['email'] . ' to auth ' . $auth, 'generic_sso');
        $user->auth = $auth;
    }
}

if (!$user) {
    $user = new User();
```

This should ideally be opt-in (e.g. via a config flag like `linkByEmail`) since it is only safe when the identity provider guarantees verified email addresses. If the IdP allows unverified/self-asserted emails, an attacker could claim someone else's email and hijack their account.

**Workaround**: Dockerfile PHP patch injects email fallback, gated by `OIDC_LINK_BY_EMAIL=true` env var (default: disabled).

**Impact**: MEDIUM - Causes duplicate accounts (or save errors) when migrating from local auth to SSO

---

## Priority Order for Fixes

1. **Fix #6** (composer require league/oauth2-client) - Plugin is completely non-functional
2. **Fix #7** (ExitException in LoginController) - SSO login always fails
3. **Fix #8** (urlResourceOwnerDetails naming) - SSO login fails on config mismatch
4. **Fix #1** (index.php check) - Without this, config.json must exist
5. **Fix #2** (SITE_SUBDOMAIN env var) - Required for single-site env-only deployment
6. **Fix #9** (currentConsultation null check) - Crash on root-level plugin routes
7. **Fix #10** (SSO email-based account linking) - Duplicate accounts on migration
8. **Fix #3** (Root URL handling) - Better UX but workaround exists
9. **Fix #4** (Documentation) - Helps users understand capabilities
10. **Fix #5** (Naming consistency) - Nice to have

---

## Testing Checklist

After upstream fixes, verify:

**Environment configuration:**
- [ ] Application starts with NO config.json file present
- [ ] Single-site mode works with SITE_SUBDOMAIN environment variable
- [ ] Multi-site mode works with MULTISITE_MODE=true
- [ ] Root URL (/) works correctly in both modes
- [ ] All database operations work with DB_* environment variables
- [ ] Redis integration works with REDIS_* environment variables
- [ ] Mail sending works with MAILER_DSN environment variable
- [ ] Application domain and protocol work with APP_DOMAIN and APP_PROTOCOL

**OIDC / SSO:**
- [ ] `composer install --no-dev` installs `league/oauth2-client`
- [ ] SSO login initiates redirect to OIDC provider (no ExitException catch)
- [ ] SSO callback completes without crash (currentConsultation null-safe)
- [ ] `generic_sso.json` with only `urlUserInfo` (no `urlResourceOwnerDetails`) works
- [ ] User is created/logged in after successful OIDC flow
- [ ] PKCE (S256) works correctly with Logto / other OIDC providers
- [ ] Single logout redirects to provider's end_session_endpoint
- [ ] Existing local account is linked on first SSO login when `linkByEmail` is enabled
- [ ] No account linking occurs when `linkByEmail` is disabled (default)

---

## How to Use This Document

When ready to fix upstream:

1. Share this document with the Antragsgruen maintainers or create GitHub issues
2. Reference specific issue numbers in pull requests
3. For LLM-assisted fixes:
   - Provide this document as context
   - Point to specific file/line numbers mentioned above
   - Request fixes in priority order
   - Test each fix independently before combining

---

## Related Resources

- **Original MR**: https://github.com/CatoTH/antragsgruen/pull/1108
- **Environment Variables Docs**: https://github.com/CatoTH/antragsgruen/blob/v4.17-volt/docs/environment-variables.md
- **Tag**: v4.17-volt
- **Current workaround**: See `php-fpm/docker-entrypoint.sh` in this repository

---

**Last Updated**: 2026-02-16
**Status**: Workarounds implemented in motion-tools-container (Dockerfile patches + entrypoint), upstream fixes pending
